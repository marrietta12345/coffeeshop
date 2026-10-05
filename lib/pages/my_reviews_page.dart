import 'package:flutter/material.dart';
import '../models/coffee_shop.dart';
import '../models/review.dart';
import '../theme/app_colors.dart';
import '../utils/menu_service.dart';
import '../utils/my_reviews_service.dart';
import '../utils/page_transitions.dart';
import '../utils/shop_lookup.dart';
import '../widgets/coffee_review_widgets.dart';
import '../widgets/fitted_image.dart';
import '../widgets/owner_page_widgets.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/shop_gallery.dart';
import '../widgets/shop_photo.dart';
import '../widgets/top_banner.dart';
import 'coffee_detail_page.dart';
import 'shop_detail_page.dart';

enum _ReviewKind { cafe, coffee }

/// Profile → My Reviews: every café and coffee review the customer has
/// written, newest first, with the café's response under it. Tapping a
/// review opens that café (or coffee), where it can be edited.
class MyReviewsPage extends StatefulWidget {
  const MyReviewsPage({super.key});

  @override
  State<MyReviewsPage> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends State<MyReviewsPage> {
  Stream<List<Review>> _cafeReviews = MyReviewsService.cafeReviews();
  Stream<List<Review>> _coffeeReviews = MyReviewsService.coffeeReviews();
  int _attempt = 0; // bumps on Try Again so the list listens afresh
  final Map<String, Future<CoffeeShop?>> _shops = {}; // shopId → café (looked up once)
  _ReviewKind _kind = _ReviewKind.cafe;
  bool _opening = false;

  void _retry() => setState(() {
        _cafeReviews = MyReviewsService.cafeReviews();
        _coffeeReviews = MyReviewsService.coffeeReviews();
        _attempt++;
      });

  Future<CoffeeShop?> _shop(String shopId) => _shops.putIfAbsent(shopId, () => resolveShop(shopId));

  Future<void> _open(Review review) async {
    if (_opening) return;
    _opening = true;
    try {
      final shop = await _shop(review.shopId);
      if (!mounted) return;
      if (shop == null) {
        showTopBanner(context, 'This café is no longer on Kafelo.', isSuccess: false);
        return;
      }
      if (review.coffeeId == null) {
        await Navigator.push(context, slideUpRoute(ShopDetailPage(shop: shop)));
        return;
      }
      final coffee = await MyReviewsService.coffee(shop.id, review.coffeeId!);
      if (!mounted) return;
      if (coffee == null) {
        showTopBanner(context, 'This coffee is no longer on the menu.', isSuccess: false);
        return;
      }
      final liked = await MenuService.likedItemIds(shop.id, [coffee]);
      if (!mounted) return;
      await Navigator.push(
        context,
        slideUpRoute(CoffeeDetailPage(
          shop: shop,
          item: coffee,
          isLiked: () => liked.contains(coffee.id),
          onToggleLike: () async {
            final nowLiked = await MenuService.toggleLike(coffee);
            nowLiked ? liked.add(coffee.id) : liked.remove(coffee.id);
          },
        )),
      );
    } catch (e) {
      debugPrint('My Reviews: could not open review: $e');
      if (mounted) showTopBanner(context, "Couldn't open this review. Please try again.", isSuccess: false);
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final coffee = _kind == _ReviewKind.coffee;
    return SettingsPageScaffold(
      title: 'My Reviews',
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.all(2),
            child: OwnerSegmentedFilter<_ReviewKind>(
              values: _ReviewKind.values,
              selected: _kind,
              labelOf: (k) => k == _ReviewKind.cafe ? 'Café Reviews' : 'Coffee Reviews',
              onSelected: (k) => setState(() => _kind = k),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Review>>(
              key: ValueKey('$_kind-$_attempt'),
              stream: coffee ? _coffeeReviews : _cafeReviews,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('My Reviews: could not load ${_kind.name} reviews: ${snapshot.error}');
                  return SettingsEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load your reviews",
                    subtitle: 'Check your connection and try again.',
                    action: OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Try Again'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBrown,
                        side: const BorderSide(color: AppColors.primaryBrown),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  );
                }
                final reviews = snapshot.data;
                if (reviews == null) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryBrown));
                }
                if (reviews.isEmpty) {
                  return SettingsEmptyState(
                    icon: Icons.rate_review_outlined,
                    title: coffee ? 'No coffee reviews yet' : 'No café reviews yet',
                    subtitle: coffee
                        ? 'Tried a coffee you loved? Rate it from its page on the café menu.'
                        : 'Visited a café? Share your experience from its page.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: reviews.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return FutureBuilder<CoffeeShop?>(
                      future: _shop(review.shopId),
                      builder: (context, shop) => MyReviewCard(
                        review: review,
                        shop: shop.data,
                        loadingShop: shop.connectionState != ConnectionState.done,
                        onTap: () => _open(review),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the customer's reviews: café (logo + name), the coffee for a
/// coffee review, stars and date, text, photo, and the café's response.
class MyReviewCard extends StatelessWidget {
  final Review review;
  final CoffeeShop? shop; // null while loading, or if the café was removed
  final bool loadingShop;
  final VoidCallback onTap;

  const MyReviewCard({super.key, required this.review, required this.shop, this.loadingShop = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cafeName = shop?.name ?? (loadingShop ? '' : 'Café no longer available');
    final coffeeName = review.coffeeName?.trim() ?? '';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEFEAE5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: shop == null
                        ? Container(
                            width: 40,
                            height: 40,
                            color: AppColors.primaryBrown.withValues(alpha: 0.12),
                            child: const Icon(Icons.local_cafe_rounded, size: 20, color: AppColors.primaryBrown),
                          )
                        : ShopCoverImage(shop: shop!, width: 40, height: 40),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coffeeName.isNotEmpty ? coffeeName : cafeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark),
                        ),
                        if (coffeeName.isNotEmpty && cafeName.isNotEmpty)
                          Text(
                            cafeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ReviewStars(rating: review.rating),
                  const SizedBox(width: 8),
                  Text(review.timeAgo, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                  if (review.ownerHearted) ...[
                    const Spacer(),
                    const Icon(Icons.favorite_rounded, size: 14, color: Color(0xFFE04B4B)),
                    const SizedBox(width: 3),
                    const Text('Loved by the café', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  ],
                ],
              ),
              if (review.hasText) ...[
                const SizedBox(height: 8),
                Text(review.text, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.4)),
              ],
              if (review.hasPhoto) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => openPhotoViewer(context, [review.photoUrl!]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: FittedImage.network(review.photoUrl!, width: 96, height: 72),
                  ),
                ),
              ],
              if (review.hasOwnerReply) ...[
                const SizedBox(height: 10),
                OwnerResponseBox(text: review.ownerReply!.trim(), shopName: shop?.name, shopLogoUrl: shop?.logoUrl),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
