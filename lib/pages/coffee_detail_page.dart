import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/fitted_image.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/menu_item.dart';
import '../models/review.dart';
import '../utils/coffee_review_service.dart';
import '../utils/page_transitions.dart';
import '../widgets/coffee_badges.dart';
import '../widgets/coffee_review_widgets.dart';
import '../widgets/menu_item_image.dart';
import '../widgets/top_banner.dart';
import 'coffee_review_form_page.dart';
import 'coffee_reviews_page.dart';

/// Full-page view of one coffee on a café's menu: large photo, name,
/// category, price, description, availability and its badges (Best
/// Seller / Featured / New), then its rating and a few recent Coffee
/// Reviews. Customers can heart and review it here too.
class CoffeeDetailPage extends StatefulWidget {
  final CoffeeShop shop;
  final MenuItem item;
  final bool Function() isLiked; // read live from the café page
  final Future<void> Function()? onToggleLike; // null = can't heart (own café)
  final bool canReview; // false on the owner's own café

  const CoffeeDetailPage({
    super.key,
    required this.shop,
    required this.item,
    required this.isLiked,
    this.onToggleLike,
    this.canReview = true,
  });

  @override
  State<CoffeeDetailPage> createState() => _CoffeeDetailPageState();
}

class _CoffeeDetailPageState extends State<CoffeeDetailPage> {
  late final bool _likedAtOpen = widget.isLiked();
  // Shared by the rating line and the reviews section (two listeners).
  late final Stream<List<Review>> _reviews =
      CoffeeReviewService.coffeeReviewsStream(widget.item.shopId, widget.item.id)
          .asBroadcastStream(onCancel: (subscription) => subscription.cancel()); // stop listening once the page closes

  MenuItem get _item => widget.item;

  /// How many reviews show here before "View All Reviews".
  static const int _previewCount = 3;

  String? get _myReviewId {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? null : CoffeeReviewService.reviewId(_item.id, uid);
  }

  Future<void> _openReviewForm(Review? mine) async {
    final result = await Navigator.push<CoffeeReviewResult>(
      context,
      slideUpRoute(CoffeeReviewFormPage(coffee: _item, existing: mine)),
    );
    if (!mounted || result == null) return;
    showTopBanner(context, result == CoffeeReviewResult.deleted ? 'Review deleted.' : 'Thanks for your review!', isSuccess: true);
  }

  void _openAllReviews() {
    Navigator.push(context, slideUpRoute(CoffeeReviewsPage(coffee: _item, canReview: widget.canReview, shopName: widget.shop.name, shopLogoUrl: widget.shop.logoUrl)));
  }

  Future<void> _toggleLike() async {
    final toggle = widget.onToggleLike;
    if (toggle == null) return;
    final pending = toggle();
    setState(() {}); // the café page flips the heart right away
    await pending;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final liked = widget.isLiked();
    // Heart count as saved, adjusted for a heart given/removed here.
    final likes = _item.likes + (liked == _likedAtOpen ? 0 : (liked ? 1 : -1));
    final badges = coffeeBadges(_item, includeUnavailable: false);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                // Same 4:3 box as the menu; the whole photo is shown.
                child: AspectRatio(
                  aspectRatio: ImageRatios.coffee,
                  child: Opacity(
                    opacity: _item.available ? 1 : 0.5,
                    child: MenuItemImage(item: _item, shop: widget.shop, fallbackIndex: 0, width: double.infinity, height: double.infinity),
                  ),
                ),
              ),
              Positioned(
                top: topPadding + 8,
                left: 12,
                child: _RoundButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
              ),
              if (widget.onToggleLike != null)
                Positioned(
                  top: topPadding + 8,
                  right: 12,
                  child: _RoundButton(
                    icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: liked ? const Color(0xFFE04B4B) : AppColors.textDark,
                    onTap: _toggleLike,
                  ),
                ),
              if (badges.isNotEmpty || !_item.available)
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final badge in badges) CoffeeBadge(badge),
                      if (!_item.available) const CoffeeBadge(CoffeeBadgeKind.unavailable),
                    ],
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.primaryBrown.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        _item.category,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primaryBrown),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.shop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _item.name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark, height: 1.2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.primaryBrown, borderRadius: BorderRadius.circular(14)),
                      child: Text(
                        MenuItem.formatPrice(_item.price),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 4,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _item.available ? const Color(0xFF2E9E5B) : const Color(0xFFD64545),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _item.available ? 'Available' : 'Currently unavailable',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _item.available ? const Color(0xFF2E9E5B) : const Color(0xFFD64545),
                      ),
                    ),
                    if (likes > 0) ...[
                      const SizedBox(width: 14),
                      const Icon(Icons.favorite_rounded, size: 14, color: Color(0xFFE04B4B)),
                      const SizedBox(width: 4),
                      Text(
                        '$likes ${likes == 1 ? 'heart' : 'hearts'}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                StreamBuilder<List<Review>>(
                  stream: _reviews,
                  builder: (context, snap) => CoffeeRatingLine(reviews: snap.data ?? const []),
                ),
                const SizedBox(height: 22),
                const Text('About this coffee', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 8),
                Text(
                  _item.description.trim().isEmpty ? 'No description yet.' : _item.description.trim(),
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.55,
                    color: _item.description.trim().isEmpty ? AppColors.textGrey : AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 28),
                _reviewsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on _CoffeeDetailPageState {
  /// Compact Coffee Reviews: the newest few, Write/Edit, View All.
  Widget _reviewsSection() {
    return StreamBuilder<List<Review>>(
      stream: _reviews,
      builder: (context, snapshot) {
        final reviews = snapshot.data;
        Review? mine;
        for (final r in reviews ?? const <Review>[]) {
          if (r.id == _myReviewId) mine = r;
        }
        final writeButton = widget.canReview
            ? TextButton.icon(
                onPressed: () => _openReviewForm(mine),
                icon: Icon(mine != null ? Icons.edit_outlined : Icons.rate_review_outlined, size: 16),
                label: Text(mine != null ? 'Edit Review' : 'Write a Review'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryBrown,
                  textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              )
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Coffee Reviews', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                ),
                if (writeButton != null && (reviews?.isNotEmpty ?? false)) writeButton,
              ],
            ),
            if (snapshot.hasError)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text("Couldn't load reviews.", style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
              )
            else if (reviews == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(color: AppColors.primaryBrown, strokeWidth: 2.5)),
              )
            else if (reviews.isEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: const Color(0xFFFAF8F5), borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    const Text('No reviews yet', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                    const SizedBox(height: 4),
                    const Text(
                      'Be the first to share your thoughts about this coffee.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                    ),
                    if (writeButton != null) ...[const SizedBox(height: 6), writeButton],
                  ],
                ),
              )
            else ...[
              for (var i = 0; i < reviews.length && i < _CoffeeDetailPageState._previewCount; i++) ...[
                if (i > 0) const Divider(height: 1, color: Color(0xFFF0ECE8)),
                CoffeeReviewTile(
                  review: reviews[i],
                  isMine: reviews[i].id == _myReviewId,
                  shopName: widget.shop.name,
                  shopLogoUrl: widget.shop.logoUrl,
                ),
              ],
              const Divider(height: 1, color: Color(0xFFF0ECE8)),
              Center(
                child: TextButton(
                  onPressed: _openAllReviews,
                  style: TextButton.styleFrom(foregroundColor: AppColors.primaryBrown),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View All Reviews', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.onTap, this.color = AppColors.textDark});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 21, color: color)),
      ),
    );
  }
}
