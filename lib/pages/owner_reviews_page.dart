import 'package:flutter/material.dart';
import '../widgets/fitted_image.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/review.dart';
import '../utils/owner_shop_service.dart';
import '../utils/coffee_review_service.dart';
import '../utils/review_insights.dart';
import '../utils/review_service.dart';
import '../widgets/coffee_review_widgets.dart' show ShopReplyLogo, ownerReplyLabel;
import '../widgets/owner_page_widgets.dart';
import '../widgets/review_reply_sheet.dart';
import '../widgets/top_banner.dart';

/// Owner "Reviews" tab, with two kinds of review kept separate:
/// * Café Reviews — rating summary, What Customers Love, and every review
///   of the café with the owner's appreciation heart and reply;
/// * Coffee Reviews — reviews of the café's individual coffees, each
///   labelled with its coffee, with the owner's reply.
class OwnerReviewsPage extends StatefulWidget {
  const OwnerReviewsPage({super.key});

  @override
  State<OwnerReviewsPage> createState() => _OwnerReviewsPageState();
}

class _OwnerReviewsPageState extends State<OwnerReviewsPage> {
  final Stream<CoffeeShop?> _shopStream = OwnerShopService.myShopStream();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ownerPageBackground,
      child: SafeArea(
        child: StreamBuilder<CoffeeShop?>(
          stream: _shopStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primaryBrown));
            }
            final shop = snapshot.data;
            if (shop == null) {
              return const Center(child: Text("We couldn't find your shop.", style: TextStyle(color: AppColors.textGrey)));
            }
            return _ReviewsBody(key: ValueKey(shop.id), shop: shop);
          },
        ),
      ),
    );
  }
}

class _ReviewsBody extends StatefulWidget {
  final CoffeeShop shop;

  const _ReviewsBody({super.key, required this.shop});

  @override
  State<_ReviewsBody> createState() => _ReviewsBodyState();
}

/// Which reviews the owner is looking at.
enum _ReviewKind { cafe, coffee }

class _ReviewsBodyState extends State<_ReviewsBody> {
  late final Stream<List<Review>> _reviewsStream = ReviewService.reviewsStream(widget.shop.id);
  late final Stream<List<Review>> _coffeeReviewsStream = CoffeeReviewService.shopCoffeeReviewsStream(widget.shop.id);
  _ReviewKind _kind = _ReviewKind.cafe;
  ReviewSort _sort = ReviewSort.recent;
  final Set<String> _heartBusy = {};

  String get _shopId => widget.shop.id;
  bool get _coffee => _kind == _ReviewKind.coffee;

  Future<void> _toggleHeart(Review review) async {
    setState(() => _heartBusy.add(review.id));
    try {
      await ReviewService.setOwnerHeart(shopId: _shopId, reviewId: review.id, hearted: !review.ownerHearted);
    } catch (e) {
      debugPrint('Review heart failed: $e');
      if (mounted) showTopBanner(context, "Couldn't update. Please try again.", isSuccess: false);
    } finally {
      if (mounted) setState(() => _heartBusy.remove(review.id));
    }
  }

  Future<void> _reply(Review review) async {
    final saved = await showReviewReplySheet(
      context,
      shopId: _shopId,
      review: review,
      save: review.coffeeId == null
          ? null
          : (text) => CoffeeReviewService.replyToReview(
                shopId: _shopId,
                reviewId: review.id,
                reply: text,
                firstReply: !review.hasOwnerReply,
              ),
    );
    if (saved && mounted) showTopBanner(context, 'Response saved!', isSuccess: true);
  }

  Future<void> _deleteReply(Review review) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete Response?',
      message: 'Your response will be removed from this review.',
    );
    if (!confirmed || !mounted) return;
    try {
      if (review.coffeeId == null) {
        await ReviewService.deleteReply(shopId: _shopId, reviewId: review.id);
      } else {
        await CoffeeReviewService.deleteReply(shopId: _shopId, reviewId: review.id);
      }
      if (mounted) showTopBanner(context, 'Response deleted.', isSuccess: true);
    } catch (e) {
      debugPrint('Deleting reply failed: $e');
      if (mounted) showTopBanner(context, "Couldn't delete your response. Please try again.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Review>>(
      // Each stream keeps its own StreamBuilder state via the key.
      key: ValueKey(_kind),
      stream: _coffee ? _coffeeReviewsStream : _reviewsStream,
      builder: (context, snapshot) {
        final reviews = snapshot.data;
        final needsReply = reviews?.where((r) => !r.hasOwnerReply).length ?? 0;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            OwnerPageHeader(
              title: 'Reviews',
              subtitle: reviews == null || reviews.isEmpty
                  ? 'See and respond to customer feedback'
                  : needsReply == 0
                      ? 'All ${_coffee ? 'coffee ' : ''}reviews have a response'
                      : '$needsReply ${_coffee ? 'coffee ' : ''}${needsReply == 1 ? 'review needs' : 'reviews need'} a reply',
            ),
            const SizedBox(height: 16),
            OwnerSegmentedFilter<_ReviewKind>(
              values: _ReviewKind.values,
              selected: _kind,
              labelOf: (k) => k == _ReviewKind.cafe ? 'Café Reviews' : 'Coffee Reviews',
              onSelected: (k) => setState(() => _kind = k),
            ),
            const SizedBox(height: 20),
            if (snapshot.hasError)
              const OwnerEmptyState(
                icon: Icons.cloud_off_rounded,
                title: "Couldn't load reviews",
                message: 'Please check your connection and try again.',
              )
            else if (reviews == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: AppColors.primaryBrown)),
              )
            else if (reviews.isEmpty)
              OwnerEmptyState(
                icon: _coffee ? Icons.local_cafe_rounded : Icons.rate_review_rounded,
                title: _coffee ? 'No coffee reviews yet' : 'No reviews yet',
                message: _coffee
                    ? 'Reviews of your individual coffees will appear here once customers try them.'
                    : 'Customer reviews will appear here once customers share their coffee experience.',
              )
            else
              ..._reviewList(reviews),
          ],
        );
      },
    );
  }

  List<Widget> _reviewList(List<Review> reviews) {
    final shown = ReviewInsights.sorted(reviews, _sort);
    final loves = _coffee ? const <CustomerLove>[] : ReviewInsights.customersLove(reviews);
    return [
      _SummaryCard(summary: ReviewInsights.summarize(reviews)),
      if (loves.isNotEmpty) ...[
        const SizedBox(height: 16),
        _LovesCard(loves: loves),
      ],
      const SizedBox(height: 20),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final sort in ReviewSort.values) ...[
              _SortChip(label: sort.label, selected: sort == _sort, onTap: () => setState(() => _sort = sort)),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (shown.isEmpty)
        const OwnerEmptyState(
          icon: Icons.photo_outlined,
          title: 'No reviews with photos yet',
          message: 'Reviews where customers attached a photo will appear here.',
        )
      else
        for (final review in shown)
          _OwnerReviewCard(
            review: review,
            heartBusy: _heartBusy.contains(review.id),
            // The appreciation heart is for café reviews.
            onHeart: review.coffeeId == null ? () => _toggleHeart(review) : null,
            onReply: () => _reply(review),
            onDeleteReply: () => _deleteReply(review),
            shopName: widget.shop.name,
            shopLogoUrl: widget.shop.logoUrl,
          ),
    ];
  }
}

class _Stars extends StatelessWidget {
  final double rating;
  final double size;

  const _Stars({required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star_rounded
                : rating >= i - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_border_rounded,
            size: size,
            color: const Color(0xFFF5A623),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final RatingSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final percentages = summary.percentages;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Column(
              children: [
                Text(
                  summary.average.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: AppColors.textDark, height: 1.1),
                ),
                const SizedBox(height: 4),
                _Stars(rating: summary.average),
                const SizedBox(height: 6),
                Text(
                  'Based on ${summary.total} ${summary.total == 1 ? 'review' : 'reviews'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                for (var stars = 5; stars >= 1; stars--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          child: Text('$stars', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        ),
                        const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF5A623)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: summary.share(stars),
                              minHeight: 7,
                              backgroundColor: AppColors.inputFill,
                              color: AppColors.primaryBrown,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 34,
                          child: Text(
                            '${percentages[stars]}%',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LovesCard extends StatelessWidget {
  final List<CustomerLove> loves;

  const _LovesCard({required this.loves});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What Customers Love', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 2),
          const Text('From your 4★ and 5★ reviews', style: TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final love in loves)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(color: ownerPageBackground, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(love.icon, size: 15, color: AppColors.primaryBrown),
                      const SizedBox(width: 6),
                      Text(love.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      const SizedBox(width: 5),
                      Text('· ${love.mentions}', style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBrown : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textGrey),
        ),
      ),
    );
  }
}

class _OwnerReviewCard extends StatelessWidget {
  final Review review;
  final bool heartBusy;
  final VoidCallback? onHeart; // null = no appreciation heart (coffee reviews)
  final VoidCallback onReply;
  final VoidCallback onDeleteReply;
  final String shopName; // replies are shown as the café, as customers see them
  final String? shopLogoUrl;

  const _OwnerReviewCard({
    required this.review,
    required this.heartBusy,
    required this.onHeart,
    required this.onReply,
    required this.onDeleteReply,
    required this.shopName,
    this.shopLogoUrl,
  });

  void _showPhoto(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: InteractiveViewer(child: Center(child: Image.network(review.photoUrl!))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = review.userPhotoUrl?.isNotEmpty ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (review.coffeeName != null) ...[
            // Which coffee this review is about.
            Row(
              children: [
                const Icon(Icons.local_cafe_rounded, size: 15, color: AppColors.primaryBrown),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    review.coffeeName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.primaryBrown),
                  ),
                ),
                const Text('Coffee Review', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryBrown.withOpacity(0.15),
                backgroundImage: hasAvatar ? NetworkImage(review.userPhotoUrl!) : null,
                child: hasAvatar
                    ? null
                    : Text(
                        review.userName.isNotEmpty ? review.userName[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.primaryBrown, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Stars(rating: review.rating, size: 13),
                        Text(formatShortDate(review.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                      ],
                    ),
                  ],
                ),
              ),
              if (!review.hasOwnerReply)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Needs Reply', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFD98A00))),
                ),
            ],
          ),
          if (review.hasText) ...[
            const SizedBox(height: 10),
            Text(review.text, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.45)),
          ],
          if (review.hasPhoto) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _showPhoto(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FittedImage.network(
                  review.photoUrl!,
                  width: 120,
                  height: 120,
                  fallback: Container(
                    width: 120,
                    height: 120,
                    color: AppColors.primaryBrown.withOpacity(0.12),
                    child: const Icon(Icons.image_outlined, color: AppColors.primaryBrown),
                  ),
                ),
              ),
            ),
          ],
          if (review.hasOwnerReply) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
              decoration: BoxDecoration(
                color: ownerPageBackground,
                borderRadius: BorderRadius.circular(12),
                border: const Border(left: BorderSide(color: AppColors.primaryBrown, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShopReplyLogo(logoUrl: shopLogoUrl),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          ownerReplyLabel(shopName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryBrown),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(review.ownerReply!, style: const TextStyle(fontSize: 12.5, color: AppColors.textDark, height: 1.4)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onReply,
                        style: TextButton.styleFrom(foregroundColor: AppColors.primaryBrown, visualDensity: VisualDensity.compact),
                        child: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      TextButton(
                        onPressed: onDeleteReply,
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFFD64545), visualDensity: VisualDensity.compact),
                        child: const Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onHeart != null) _HeartButton(hearted: review.ownerHearted, busy: heartBusy, onTap: onHeart!) else const SizedBox.shrink(),
              if (!review.hasOwnerReply)
                OutlinedButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply_rounded, size: 16),
                  label: const Text('Reply'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBrown,
                    side: BorderSide(color: AppColors.primaryBrown.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The owner's private appreciation heart — not a public like count.
class _HeartButton extends StatelessWidget {
  final bool hearted;
  final bool busy;
  final VoidCallback onTap;

  const _HeartButton({required this.hearted, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE04B4B);
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: hearted ? red.withOpacity(0.1) : ownerPageBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(hearted ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 16, color: hearted ? red : AppColors.textGrey),
            const SizedBox(width: 6),
            Text(
              hearted ? 'You appreciated this' : 'Appreciate',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: hearted ? red : AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }
}
