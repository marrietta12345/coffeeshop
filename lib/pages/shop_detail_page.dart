import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/menu_item.dart';
import '../models/review.dart';
import '../widgets/top_banner.dart';
import '../widgets/favorite_heart_button.dart';
import '../widgets/shop_photo.dart';
import '../widgets/menu_item_image.dart';
import '../utils/shop_stats_service.dart';
import 'add_review_page.dart';
import 'best_sellers_page.dart';
import '../utils/page_transitions.dart';

class ShopDetailPage extends StatefulWidget {
  final CoffeeShop shop;

  const ShopDetailPage({super.key, required this.shop});

  @override
  State<ShopDetailPage> createState() => _ShopDetailPageState();
}

class _ShopDetailPageState extends State<ShopDetailPage> {
  late List<Review> _reviews;
  late List<MenuItem> _menuItems;
  final Set<String> _likedItems = {}; // item names liked this session

  @override
  void initState() {
    super.initState();
    _reviews = List.of(widget.shop.reviews);
    _menuItems = List.of(widget.shop.menu);

    // Track a real profile view — skip counting the shop's own owner
    // browsing their own listing.
    final shop = widget.shop;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (shop.ownerId != null && shop.ownerId != currentUid) {
      ShopStatsService.recordView(shop.id);
    }
  }

  double get _averageRating {
    if (_reviews.isEmpty) return widget.shop.rating;
    final sum = _reviews.fold<double>(0, (acc, r) => acc + r.rating);
    return sum / _reviews.length;
  }

  void _toggleLike(MenuItem item) {
    setState(() {
      if (_likedItems.contains(item.name)) {
        _likedItems.remove(item.name);
        item.likes--;
      } else {
        _likedItems.add(item.name);
        item.likes++;
      }
    });
  }

  Future<void> _openDirections() async {
    final shop = widget.shop;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${shop.latitude},${shop.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openCall() async {
    final phone = widget.shop.phoneNumber;
    if (phone == null || phone.trim().isEmpty) {
      showTopBanner(context, 'No phone number available for this shop.', isSuccess: false);
      return;
    }
    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _openWebsite() async {
    final website = widget.shop.website;
    if (website == null || website.trim().isEmpty) {
      showTopBanner(context, 'This shop hasn\'t added a website yet.', isSuccess: false);
      return;
    }
    var url = website.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _openShare() {
    // TODO: wire up the `share_plus` package for a real native share sheet.
    showTopBanner(context, 'Sharing is coming soon!', isSuccess: true);
  }

  Future<void> _openAddReview() async {
    final result = await Navigator.of(context).push<(double, String)?>(
      slideUpRoute(AddReviewPage(shop: widget.shop)),
    );
    if (result == null) return;
    final (rating, text) = result;
    setState(() {
      _reviews.insert(
        0,
        Review(
          userName: 'You',
          rating: rating,
          timeAgo: 'Just now',
          text: text,
        ),
      );
    });
  }

  void _openSuggestEdit() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Suggest an edit'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'e.g. correct hours, wrong address...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBrown),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thanks! Your suggestion was submitted.')),
              );
              // TODO: send this to a Firestore "suggested_edits" collection
              // for moderation instead of just showing a confirmation.
            },
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                pinned: true,
                floating: false,
                backgroundColor: Colors.white,
                elevation: 0,
                automaticallyImplyLeading: false,
                expandedHeight: 0,
                toolbarHeight: 0,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(460),
                  child: _ShopHeader(
                    shop: shop,
                    averageRating: _averageRating,
                    onBack: () => Navigator.pop(context),
                    onCall: _openCall,
                    onDirections: _openDirections,
                    onWebsite: _openWebsite,
                    onShare: _openShare,
                    onEdit: _openSuggestEdit,
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _OverviewTab(
                shop: shop,
                reviews: _reviews,
                averageRating: _averageRating,
                onSeeAllReviews: () => DefaultTabController.of(context).animateTo(2),
                onAddReview: _openAddReview,
              ),
              _MenuTab(
                shop: shop,
                menuItems: _menuItems,
                likedItems: _likedItems,
                onToggleLike: _toggleLike,
              ),
              _ReviewsTab(reviews: _reviews, onAddReview: _openAddReview),
              _PhotoTab(shop: shop),
              _AboutTab(shop: shop),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cover photo with overlaid back/favorite buttons, a logo avatar
/// overlapping the bottom edge, name/rating/distance/hours, the
/// Call/Directions/Website/Share icon row, and the tab bar underneath.
class _ShopHeader extends StatelessWidget {
  final CoffeeShop shop;
  final double averageRating;
  final VoidCallback onBack;
  final VoidCallback onCall;
  final VoidCallback onDirections;
  final VoidCallback onWebsite;
  final VoidCallback onShare;
  final VoidCallback onEdit;

  const _ShopHeader({
    required this.shop,
    required this.averageRating,
    required this.onBack,
    required this.onCall,
    required this.onDirections,
    required this.onWebsite,
    required this.onShare,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ShopPhoto(shop: shop, index: 0, width: double.infinity, height: 200),
            Positioned(
              top: 12,
              left: 12,
              child: _RoundIconButton(icon: Icons.arrow_back_rounded, onTap: onBack, whiteBg: true),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: FavoriteHeartButton(shop: shop, size: 36),
            ),
            Positioned(
              bottom: -28,
              left: 16,
              child: Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryBrown.withOpacity(0.1)),
                  clipBehavior: Clip.antiAlias,
                  child: (shop.logoUrl != null && shop.logoUrl!.isNotEmpty)
                      ? Image.network(
                          shop.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Padding(padding: const EdgeInsets.all(10), child: Image.asset('lib/images/kafelo_logo.png')),
                        )
                      : Padding(padding: const EdgeInsets.all(10), child: Image.asset('lib/images/kafelo_logo.png')),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      shop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
                    ),
                  ),
                  InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.edit_outlined, size: 18, color: AppColors.textGrey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 17),
                  Text(
                    ' ${averageRating.toStringAsFixed(1)}  •  ${shop.categoryLabel}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${shop.isOpenNow ? "Open" : "Closed"} • ${shop.openTime} Close ${shop.closeTime}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: shop.isOpenNow ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _IconActionButton(icon: Icons.call_rounded, label: 'Call', onTap: onCall),
                  _IconActionButton(icon: Icons.directions_rounded, label: 'Directions', onTap: onDirections),
                  _IconActionButton(icon: Icons.public_rounded, label: 'Website', onTap: onWebsite),
                  _IconActionButton(icon: Icons.share_rounded, label: 'Share', onTap: onShare),
                ],
              ),
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFEDEAE6))),
          ),
          child: const TabBar(
            isScrollable: true,
            labelColor: AppColors.primaryBrown,
            unselectedLabelColor: AppColors.textGrey,
            indicatorColor: AppColors.primaryBrown,
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Menu'),
              Tab(text: 'Reviews'),
              Tab(text: 'Photo'),
              Tab(text: 'About'),
            ],
          ),
        ),
      ],
    );
  }
}

/// A small icon-over-label button for the Call/Directions/Website/Share
/// row — light circular background, matching the reference design.
class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _IconActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.inputFill),
            child: Icon(icon, size: 20, color: AppColors.primaryBrown),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool whiteBg;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.whiteBg = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: whiteBg ? Colors.white : AppColors.inputFill,
          boxShadow: whiteBg
              ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Icon(icon, size: 20, color: AppColors.textDark),
      ),
    );
  }
}

// ----------------------------- OVERVIEW TAB -----------------------------

class _OverviewTab extends StatelessWidget {
  final CoffeeShop shop;
  final List<Review> reviews;
  final double averageRating;
  final VoidCallback onSeeAllReviews;
  final VoidCallback onAddReview;

  const _OverviewTab({
    required this.shop,
    required this.reviews,
    required this.averageRating,
    required this.onSeeAllReviews,
    required this.onAddReview,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6EC),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primaryBrown),
                  SizedBox(width: 6),
                  Text('Know before you go', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'The shop is clean, accessible, and surrounded by local businesses, '
                'making it a convenient stop for visitors. It sits along a busy, '
                'well-maintained street with easy access on foot or by motorbike.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textGrey, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Menu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            GestureDetector(
              onTap: () => DefaultTabController.of(context).animateTo(1),
              child: const Row(
                children: [
                  Text('See the menu', style: TextStyle(fontSize: 12, color: AppColors.primaryBrown, fontWeight: FontWeight.w700)),
                  Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primaryBrown),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shop.menu.length.clamp(0, 4),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) => Container(
              width: 90,
              decoration: BoxDecoration(
                color: AppColors.primaryBrown.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Icon(Icons.local_cafe_rounded, color: AppColors.primaryBrown, size: 26)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: onAddReview,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFEDEAE6)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                Icon(Icons.rate_review_outlined, color: AppColors.primaryBrown, size: 20),
                SizedBox(width: 10),
                Text('Add a post — Rate and review', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Spacer(),
                Icon(Icons.chevron_right_rounded, color: AppColors.textGrey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Review summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _ReviewSummary(reviews: reviews, averageRating: averageRating),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Reviews', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            GestureDetector(
              onTap: onSeeAllReviews,
              child: const Row(
                children: [
                  Text('See all', style: TextStyle(fontSize: 12, color: AppColors.primaryBrown, fontWeight: FontWeight.w700)),
                  Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primaryBrown),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No reviews yet — be the first!', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
          )
        else
          ...reviews.take(2).map((r) => _ReviewCard(review: r)),
      ],
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  final List<Review> reviews;
  final double averageRating;

  const _ReviewSummary({required this.reviews, required this.averageRating});

  Map<int, int> get _breakdown {
    final map = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in reviews) {
      final bucket = r.rating.round().clamp(1, 5);
      map[bucket] = (map[bucket] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final breakdown = _breakdown;
    final total = reviews.length.clamp(1, 999999);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          children: [
            Text(
              averageRating.toStringAsFixed(1),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            Row(
              children: List.generate(5, (i) {
                final filled = i < averageRating.round();
                return Icon(
                  filled ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 14,
                  color: const Color(0xFFF5A623),
                );
              }),
            ),
            const SizedBox(height: 2),
            Text('${reviews.length} reviews', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            children: List.generate(5, (i) {
              final star = 5 - i;
              final count = breakdown[star] ?? 0;
              final ratio = count / total;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text('$star', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFEDEAE6),
                          valueColor: const AlwaysStoppedAnimation(Color(0xFFF5A623)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryBrown.withOpacity(0.15),
                child: Text(
                  review.userName.isNotEmpty ? review.userName[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primaryBrown, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(review.timeAgo, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  final filled = i < review.rating.round();
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 13,
                    color: const Color(0xFFF5A623),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(review.text, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.4)),
          if (review.photoCount > 0) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.photoCount,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) => Container(
                  width: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBrown.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.image_outlined, color: AppColors.primaryBrown, size: 20),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.favorite_border_rounded, size: 16, color: AppColors.textGrey),
              const SizedBox(width: 4),
              Text('${review.likes}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------- MENU TAB --------------------------------

class _MenuTab extends StatelessWidget {
  final CoffeeShop shop;
  final List<MenuItem> menuItems;
  final Set<String> likedItems;
  final void Function(MenuItem item) onToggleLike;

  const _MenuTab({
    required this.shop,
    required this.menuItems,
    required this.likedItems,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    if (menuItems.isEmpty) {
      return const Center(child: Text('Menu not available yet.', style: TextStyle(color: AppColors.textGrey)));
    }

    // "Best sellers" = the most-hearted items, recomputed live as people like things.
    final bestSellers = List.of(menuItems)..sort((a, b) => b.likes.compareTo(a.likes));
    final topLiked = bestSellers.take(3).where((item) => item.likes > 0).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (topLiked.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Text('❤️', style: TextStyle(fontSize: 15)),
                  SizedBox(width: 6),
                  Text('Best Sellers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    slideUpRoute(BestSellersPage(shop: shop, menuItems: menuItems)),
                  );
                },
                child: const Text(
                  'See all',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryBrown),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: topLiked.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final item = topLiked[index];
                final originalIndex = menuItems.indexOf(item);
                return SizedBox(
                  width: 140,
                  child: _MenuItemCard(
                    shop: shop,
                    item: item,
                    photoIndex: originalIndex,
                    isLiked: likedItems.contains(item.name),
                    isTopPick: true,
                    onToggleLike: () => onToggleLike(item),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
        ],
        const Text('Full Menu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 16,
            childAspectRatio: 0.72,
          ),
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            final item = menuItems[index];
            return _MenuItemCard(
              shop: shop,
              item: item,
              photoIndex: index,
              isLiked: likedItems.contains(item.name),
              isTopPick: topLiked.contains(item),
              onToggleLike: () => onToggleLike(item),
            );
          },
        ),
      ],
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final CoffeeShop shop;
  final MenuItem item;
  final int photoIndex;
  final bool isLiked;
  final bool isTopPick;
  final VoidCallback onToggleLike;

  const _MenuItemCard({
    required this.shop,
    required this.item,
    required this.photoIndex,
    required this.isLiked,
    required this.isTopPick,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: MenuItemImage(item: item, shop: shop, fallbackIndex: photoIndex + 20, width: double.infinity, height: double.infinity),
                ),
              ),
              if (isTopPick)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE04B4B),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Text(
                      'BEST SELLER',
                      style: TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onToggleLike,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: Icon(
                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 18,
                      color: isLiked ? const Color(0xFFE04B4B) : AppColors.textGrey,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textDark),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            if (item.originalPrice != null) ...[
              Text(
                '₱${item.originalPrice!.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textGrey,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              '₱${item.price.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: item.originalPrice != null ? const Color(0xFFE04B4B) : AppColors.textDark,
              ),
            ),
            const Spacer(),
            Icon(Icons.favorite_rounded, size: 12, color: Colors.grey.shade400),
            const SizedBox(width: 2),
            Text('${item.likes}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

// ------------------------------ REVIEWS TAB -------------------------------

class _ReviewsTab extends StatelessWidget {
  final List<Review> reviews;
  final VoidCallback onAddReview;

  const _ReviewsTab({required this.reviews, required this.onAddReview});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBrown,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onAddReview,
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text('Write a review', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: reviews.isEmpty
                ? const Center(child: Text('No reviews yet — be the first!', style: TextStyle(color: AppColors.textGrey)))
                : ListView.builder(
                    itemCount: reviews.length,
                    itemBuilder: (context, index) => _ReviewCard(review: reviews[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------- PHOTO TAB --------------------------------

class _PhotoTab extends StatelessWidget {
  final CoffeeShop shop;

  const _PhotoTab({required this.shop});

  @override
  Widget build(BuildContext context) {
    if (shop.effectivePhotoCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library_outlined, size: 48, color: AppColors.textGrey.withOpacity(0.5)),
              const SizedBox(height: 12),
              const Text(
                'No photos yet',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              const Text(
                'This shop hasn\'t added any photos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: shop.effectivePhotoCount,
      itemBuilder: (context, index) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ShopPhoto(shop: shop, index: index, width: double.infinity, height: double.infinity),
      ),
    );
  }
}

// -------------------------------- ABOUT TAB --------------------------------

class _AboutTab extends StatelessWidget {
  final CoffeeShop shop;

  const _AboutTab({required this.shop});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('About', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(shop.description, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.5)),
        const SizedBox(height: 20),
        _InfoRow(icon: Icons.location_on_outlined, text: shop.address),
        _InfoRow(icon: Icons.access_time_rounded, text: 'Open ${shop.openTime} – Close ${shop.closeTime}'),
        _InfoRow(icon: Icons.category_outlined, text: shop.categoryLabel),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryBrown),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textDark))),
        ],
      ),
    );
  }
}