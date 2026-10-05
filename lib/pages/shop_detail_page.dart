import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'coffee_preferences_page.dart';
import '../models/coffee_preferences.dart';
import '../utils/user_profile_service.dart';
import '../utils/recommendations.dart';
import '../widgets/cafe_vibe.dart';
import '../widgets/fitted_image.dart';
import '../widgets/shop_gallery.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/menu_item.dart';
import '../models/review.dart';
import '../widgets/top_banner.dart';
import '../widgets/favorite_heart_button.dart';
import '../widgets/shop_photo.dart';
import '../widgets/menu_item_image.dart';
import '../widgets/online_action_button.dart';
import '../widgets/open_status.dart';
import '../models/operating_hours.dart';
import '../utils/online_links.dart';
import '../utils/shop_activity_service.dart';
import '../utils/review_service.dart';
import '../utils/menu_service.dart';
import '../utils/visited_shops_service.dart';
import 'add_review_page.dart';
import 'save_to_collection_sheet.dart';
import '../utils/collections_service.dart';
import '../models/shop_collection.dart';
import 'best_sellers_page.dart';
import 'coffee_detail_page.dart';
import 'directions_page.dart';
import '../widgets/coffee_badges.dart';
import '../widgets/coffee_review_widgets.dart' show OwnerResponseBox;
import '../utils/page_transitions.dart';

class ShopDetailPage extends StatefulWidget {
  final CoffeeShop shop;

  const ShopDetailPage({super.key, required this.shop});

  @override
  State<ShopDetailPage> createState() => _ShopDetailPageState();
}

class _ShopDetailPageState extends State<ShopDetailPage> {
  // This shop's reviews, kept live from shops/{id}/reviews.
  List<Review> _reviews = [];
  StreamSubscription<List<Review>>? _reviewsSubscription;
  // This shop's coffee menu, kept live from shops/{id}/menu.
  List<MenuItem> _menuItems = [];
  StreamSubscription<List<MenuItem>>? _menuSubscription;
  final Set<String> _likedItems = {}; // ids of coffees this customer hearted
  final Set<String> _likeChecked = {}; // ids whose heart state was loaded
  final Set<String> _likeBusy = {};
  // The café's own record, kept live so owner edits (description, gallery,
  // name, hours…) show without reopening the page.
  CoffeeShop? _liveShop;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _shopSubscription;

  CoffeeShop get _shop => _liveShop ?? widget.shop;
  // The customer's Coffee Preferences, kept live for the match pill.
  CoffeePreferences? _prefs;
  StreamSubscription<Map<String, dynamic>>? _prefsSubscription;

  bool get _isOwnShop => widget.shop.ownerId != null && widget.shop.ownerId == FirebaseAuth.instance.currentUser?.uid;

  /// Follows the signed-in customer's own Coffee Preferences, so the match
  /// always uses the latest ones (not for the café's own owner — there's no
  /// match to show them).
  void _watchPreferences() {
    if (FirebaseAuth.instance.currentUser == null || _isOwnShop) return;
    _prefsSubscription = UserProfileService.profileStream().listen(
      (profile) {
        if (mounted) setState(() => _prefs = CoffeePreferences.fromMap(profile['coffeePreferences'] as Map<String, dynamic>?));
      },
      onError: (Object e) => debugPrint('Coffee preferences unavailable: $e'),
    );
  }

  void _openPreferences() {
    Navigator.push(context, slideUpRoute(const CoffeePreferencesPage()));
  }

  @override
  void initState() {
    super.initState();
    _watchPreferences();
    _shopSubscription = FirebaseFirestore.instance.collection('shops').doc(widget.shop.id).snapshots().listen(
      (doc) {
        if (mounted && doc.exists) setState(() => _liveShop = CoffeeShop.fromFirestore(doc));
      },
      onError: (Object error) => debugPrint('Shop stream error: $error'),
    );
    _menuSubscription = MenuService.menuStream(widget.shop.id).listen(
      (items) {
        if (!mounted) return;
        setState(() => _menuItems = items);
        _loadLikes(items);
      },
      onError: (Object error) => debugPrint('Menu stream error: $error'),
    );
    _reviewsSubscription = ReviewService.reviewsStream(widget.shop.id).listen(
      (reviews) {
        if (mounted) setState(() => _reviews = reviews);
      },
      onError: (Object error) => debugPrint('Reviews stream error: $error'),
    );

    // Track a unique profile view — skip counting the shop's own owner
    // browsing their own listing.
    final shop = widget.shop;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (shop.ownerId != null && shop.ownerId != currentUid) {
      ShopActivityService.recordView(shop.id);
    }
    // Add to the viewer's Visited Cafés history — celebrating a
    // brand-new discovery (Daily Discovery + streak).
    if (currentUid != null && shop.ownerId != currentUid) {
      _recordVisit(shop);
    }
  }

  Future<void> _recordVisit(CoffeeShop shop) async {
    final isNewDiscovery = await VisitedShopsService.recordVisit(shop);
    if (!isNewDiscovery || !mounted) return;
    final journey = await VisitedShopsService.journeyStream().first;
    if (!mounted) return;
    final streak = journey.currentStreak;
    final streakText = streak > 1 ? ' • $streak-day streak 🔥' : '';
    showTopBanner(
      context,
      'New café discovered! ☕ Daily Discovery done$streakText',
      isSuccess: true,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _reviewsSubscription?.cancel();
    _menuSubscription?.cancel();
    _shopSubscription?.cancel();
    _prefsSubscription?.cancel();
    super.dispose();
  }

  double get _averageRating {
    if (_reviews.isEmpty) return _shop.rating;
    final sum = _reviews.fold<double>(0, (acc, r) => acc + r.rating);
    return sum / _reviews.length;
  }

  /// Loads which newly seen coffees this customer has already hearted.
  Future<void> _loadLikes(List<MenuItem> items) async {
    final unchecked = items.where((i) => !_likeChecked.contains(i.id)).toList();
    if (unchecked.isEmpty || _isOwnShop) return;
    _likeChecked.addAll(unchecked.map((i) => i.id));
    try {
      final liked = await MenuService.likedItemIds(widget.shop.id, unchecked);
      if (mounted) setState(() => _likedItems.addAll(liked));
    } catch (e) {
      _likeChecked.removeAll(unchecked.map((i) => i.id));
      debugPrint('Loading menu hearts failed: $e');
    }
  }

  /// Hearts / un-hearts a coffee — saved, one heart per customer.
  Future<void> _toggleLike(MenuItem item) async {
    if (_isOwnShop) {
      showTopBanner(context, "You can't heart your own coffee.", isSuccess: false);
      return;
    }
    if (!_likeBusy.add(item.id)) return;
    final wasLiked = _likedItems.contains(item.id);
    setState(() => wasLiked ? _likedItems.remove(item.id) : _likedItems.add(item.id));
    try {
      final nowLiked = await MenuService.toggleLike(item);
      if (mounted) setState(() => nowLiked ? _likedItems.add(item.id) : _likedItems.remove(item.id));
    } catch (e) {
      debugPrint('Menu heart failed: $e');
      if (!mounted) return;
      setState(() => wasLiked ? _likedItems.add(item.id) : _likedItems.remove(item.id));
      showTopBanner(context, "Couldn't save your heart. Please try again.", isSuccess: false);
    } finally {
      _likeBusy.remove(item.id);
    }
  }

  /// In-app directions on OpenStreetMap to this café's own coordinates —
  /// never an external maps app.
  void _openDirections() {
    Navigator.push(context, slideUpRoute(DirectionsPage(shop: _shop)));
  }

  Future<void> _openCall() async {
    final phone = _shop.phoneNumber;
    if (phone == null || phone.trim().isEmpty) {
      showTopBanner(context, 'No phone number available for this shop.', isSuccess: false);
      return;
    }
    await launchUrl(Uri.parse('tel:$phone'));
  }

  /// Opens one of the café's website / social links in the browser or app.
  Future<void> _openOnlineLink(OnlineLink link) async {
    final opened = await launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showTopBanner(context, "Couldn't open ${link.platform.label}. Please try again.", isSuccess: false);
    }
  }

  void _openShare() {
    // TODO: wire up the `share_plus` package for a real native share sheet.
    showTopBanner(context, 'Sharing is coming soon!', isSuccess: true);
  }

  Future<void> _openAddReview() async {
    // Posting again for the same shop edits the user's earlier review.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    Review? existing;
    for (final review in _reviews) {
      if (review.userId == uid) existing = review;
    }
    final posted = await Navigator.of(context).push<bool>(
      slideUpRoute(AddReviewPage(shop: _shop, existing: existing)),
    );
    if (posted == true && mounted) {
      showTopBanner(context, existing == null ? 'Review posted!' : 'Review updated!', isSuccess: true);
    }
  }

  /// The café's header photo is a fixed 16:9 box across the screen.
  static double _headerPhotoHeight(BuildContext context) => MediaQuery.sizeOf(context).width / ImageRatios.banner;

  /// Header = 16:9 photo + café info (its text grows with the phone's font
  /// size). Mall cafés show two extra lines (mall + floor/unit), plus one
  /// more for the landmark.
  static double _headerHeight(BuildContext context, CoffeeShop shop) {
    final info = !shop.isInMall
        ? 260.0
        : (shop.mallFloorAndUnit != null && (shop.mallLandmark?.trim().isNotEmpty ?? false) ? 322.0 : 304.0);
    final scaler = MediaQuery.textScalerOf(context);
    final tags = CafeVibeTags.tagsFor(shop).isEmpty ? 0.0 : 10 + scaler.scale(CafeVibeTags.rowHeight);
    return _headerPhotoHeight(context) + scaler.scale(info) + tags;
  }

  @override
  Widget build(BuildContext context) {
    final shop = _shop;
    final prefs = _prefs;
    final match = prefs == null ? null : vibeMatchFor(prefs, shop);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                // The header (photo, info, tabs) stays pinned on phones in
                // portrait; on short screens (landscape) it would cover the
                // whole screen, so it scrolls away with the content instead.
                pinned: _headerHeight(context, shop) < MediaQuery.sizeOf(context).height * 0.7,
                floating: false,
                backgroundColor: Colors.white,
                elevation: 0,
                // Keep the header white while the tab content scrolls under it
                // (Material 3 would otherwise tint it beige).
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                automaticallyImplyLeading: false,
                expandedHeight: 0,
                toolbarHeight: 0,
                bottom: PreferredSize(
                  // Header = 16:9 photo + café info. Mall cafés show two extra
                  // lines (mall + floor/landmark), plus one for the landmark.
                  preferredSize: Size.fromHeight(_headerHeight(context, shop)),
                  child: _ShopHeader(
                    photoHeight: _headerPhotoHeight(context),
                    shop: shop,
                    averageRating: _averageRating,
                    onBack: () => Navigator.pop(context),
                    onCall: _openCall,
                    onDirections: _openDirections,
                    onOpenLink: _openOnlineLink,
                    onShare: _openShare,
                    onSaveToCollection: () => showSaveToCollectionSheet(context, shop),
                    vibeMatch: match,
                    onVibeMatchTap: match == null
                        ? null
                        : () => showVibeMatchSheet(context, match: match, shopName: shop.name, onEditPreferences: _openPreferences),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _OverviewTab(
                shop: shop,
                menuItems: _menuItems,
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
                canLike: !_isOwnShop,
              ),
              _ReviewsTab(reviews: _reviews, shopName: shop.name, shopLogoUrl: shop.logoUrl, onAddReview: _openAddReview),
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
  final double photoHeight; // 16:9 box
  final double averageRating;
  final VoidCallback onBack;
  final VoidCallback onCall;
  final VoidCallback onDirections;
  final ValueChanged<OnlineLink> onOpenLink;
  final VoidCallback onShare;
  final VoidCallback onSaveToCollection;
  final VibeMatch? vibeMatch; // null = nothing to show
  final VoidCallback? onVibeMatchTap;

  const _ShopHeader({
    this.vibeMatch,
    this.onVibeMatchTap,
    required this.photoHeight,
    required this.shop,
    required this.averageRating,
    required this.onBack,
    required this.onCall,
    required this.onDirections,
    required this.onOpenLink,
    required this.onShare,
    required this.onSaveToCollection,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ShopBanner(shop: shop, width: double.infinity, height: photoHeight),
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
            // Save to a collection — filled when it's already in one.
            Positioned(
              top: 12,
              right: 56,
              child: StreamBuilder<List<ShopCollection>>(
                stream: CollectionsService.collectionsStream(),
                builder: (context, snapshot) {
                  final inACollection = (snapshot.data ?? const <ShopCollection>[])
                      .any((c) => c.shopIds.contains(shop.id));
                  return _RoundIconButton(
                    icon: inACollection ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    onTap: onSaveToCollection,
                    whiteBg: true,
                  );
                },
              ),
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
                  if (vibeMatch != null && onVibeMatchTap != null) ...[
                    const SizedBox(width: 8),
                    VibeMatchPill(match: vibeMatch!, onTap: onVibeMatchTap!),
                  ],
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
              // Open Now / Closed Now from the owner's schedule (Manila time).
              OpenStatusLine(hours: shop.hours),
              if (shop.isInMall) ...[
                const SizedBox(height: 8),
                // Pin icon with the mall line and floor/landmark aligned beside it.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.location_on_rounded, size: 16, color: AppColors.primaryBrown),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inside ${shop.mallName!.trim()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                          ),
                          // "2nd Floor · Unit 204", then the landmark below it.
                          for (final line in [shop.mallFloorAndUnit, shop.mallLandmark?.trim()])
                            if (line != null && line.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                line,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                              ),
                            ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              // The café's own vibe (from its Café Features).
              if (CafeVibeTags.tagsFor(shop).isNotEmpty) ...[
                const SizedBox(height: 10),
                CafeVibeTags(shop: shop),
              ],
              const SizedBox(height: 16),
              // Equal-width columns, so 3 or 4 buttons are always evenly spaced.
              Row(
                children: [
                  for (final button in [
                    _IconActionButton(icon: Icons.call_rounded, label: 'Call', onTap: onCall),
                    _IconActionButton(icon: Icons.directions_rounded, label: 'Directions', onTap: onDirections),
                    // Only when the owner added a website or social link.
                    if (OnlineLinks.forShop(shop).isNotEmpty)
                      OnlineActionButton(links: OnlineLinks.forShop(shop), onOpen: onOpenLink),
                    _IconActionButton(icon: Icons.share_rounded, label: 'Share', onTap: onShare),
                  ])
                    Expanded(child: Center(child: button)),
                ],
              ),
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFEDEAE6))),
          ),
          // Fixed tabs: all five fit the width, aligned with the content
          // and never cut off at the edge.
          child: const TabBar(
            labelColor: AppColors.primaryBrown,
            unselectedLabelColor: AppColors.textGrey,
            indicatorColor: AppColors.primaryBrown,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent, // the container already draws the line
            labelPadding: EdgeInsets.symmetric(horizontal: 4),
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
  final List<MenuItem> menuItems;
  final List<Review> reviews;
  final double averageRating;
  final VoidCallback onSeeAllReviews;
  final VoidCallback onAddReview;

  const _OverviewTab({
    required this.shop,
    required this.menuItems,
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
        // The owner's own description — hidden when they haven't written one
        // (never placeholder or made-up text).
        if (shop.description.trim().isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6EC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primaryBrown),
                    SizedBox(width: 6),
                    Text('Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  shop.description.trim(),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textDark, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
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
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: menuItems.length.clamp(0, 4),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) => ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MenuItemImage(item: menuItems[index], shop: shop, fallbackIndex: index, width: 96, height: 72),
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
          ...reviews.take(2).map((r) => _ReviewCard(review: r, shopName: shop.name, shopLogoUrl: shop.logoUrl)),
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

  final String shopName; // the café's current name, for its response
  final String? shopLogoUrl; // and its logo

  const _ReviewCard({required this.review, required this.shopName, this.shopLogoUrl});

  /// Full-screen, pinch-to-zoom view of a review's photo.
  void _showReviewPhoto(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: InteractiveViewer(child: Center(child: Image.network(url))),
      ),
    );
  }

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
          if (review.hasPhoto) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showReviewPhoto(context, review.photoUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: FittedImage.network(
                  review.photoUrl!,
                  width: 60,
                  height: 60,
                  fallback: Container(
                    width: 60,
                    height: 60,
                    color: AppColors.primaryBrown.withOpacity(0.15),
                    child: const Icon(Icons.image_outlined, color: AppColors.primaryBrown, size: 20),
                  ),
                ),
              ),
            ),
          ],
          if (review.ownerHearted) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.favorite_rounded, size: 14, color: Color(0xFFE04B4B)),
                SizedBox(width: 5),
                Text('The café appreciated this review', style: TextStyle(fontSize: 11.5, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          if (review.hasOwnerReply) ...[
            const SizedBox(height: 10),
            OwnerResponseBox(text: review.ownerReply!, shopName: shopName, shopLogoUrl: shopLogoUrl),
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

class _MenuTab extends StatefulWidget {
  final CoffeeShop shop;
  final List<MenuItem> menuItems;
  final Set<String> likedItems;
  final Future<void> Function(MenuItem item) onToggleLike;
  final bool canLike; // false on the owner's own café

  const _MenuTab({
    required this.shop,
    required this.menuItems,
    required this.likedItems,
    required this.onToggleLike,
    required this.canLike,
  });

  @override
  State<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<_MenuTab> {
  String? _category; // category chip; null = All

  void _openCoffee(MenuItem item) {
    Navigator.push(
      context,
      slideUpRoute(CoffeeDetailPage(
        shop: widget.shop,
        item: item,
        isLiked: () => widget.likedItems.contains(item.id),
        onToggleLike: widget.canLike ? () => widget.onToggleLike(item) : null,
        canReview: widget.canLike, // owners don't review their own coffee
      )),
    );
  }

  Widget _card(MenuItem item, {required bool isTopPick}) {
    return _MenuItemCard(
      shop: widget.shop,
      item: item,
      photoIndex: widget.menuItems.indexOf(item),
      isLiked: widget.likedItems.contains(item.id),
      isTopPick: isTopPick,
      onToggleLike: () => widget.onToggleLike(item),
      onTap: () => _openCoffee(item),
    );
  }

  /// Height of a menu card's text below its 4:3 photo.
  static const double _cardTextHeight = 70;

  Widget _grid(List<MenuItem> items, List<MenuItem> topLiked) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 14) / 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 16,
            mainAxisExtent: cardWidth / ImageRatios.coffee + MediaQuery.textScalerOf(context).scale(_cardTextHeight),
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _card(items[index], isTopPick: topLiked.contains(items[index])),
        );
      },
    );
  }

  Widget _row(List<MenuItem> items, List<MenuItem> topLiked) {
    return SizedBox(
      height: 140 / ImageRatios.coffee + MediaQuery.textScalerOf(context).scale(_cardTextHeight),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) => SizedBox(width: 140, child: _card(items[index], isTopPick: topLiked.contains(items[index]))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = widget.menuItems;
    if (menuItems.isEmpty) {
      return const Center(child: Text('Menu not available yet.', style: TextStyle(color: AppColors.textGrey)));
    }

    // "Popular" = the most-hearted coffees (real customer hearts — Kafelo
    // doesn't track sales), recomputed live as people heart things.
    final bestSellers = List.of(menuItems)..sort((a, b) => b.likes.compareTo(a.likes));
    final topLiked = bestSellers.take(3).where((item) => item.likes > 0).toList();
    // The owner's picks for the top of the menu.
    final featured = [for (final (_, items) in CoffeeCategory.group(menuItems)) ...items.where((i) => i.featured)];
    final categories = CoffeeCategory.used(menuItems);
    final category = categories.contains(_category) ? _category : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        CoffeeCategoryChips(
          categories: categories,
          selected: category,
          onSelected: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: 20),
        if (category == null) ...[
          if (featured.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 17, color: Color(0xFF3E5641)),
                SizedBox(width: 6),
                Text('Featured', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              ],
            ),
            const SizedBox(height: 12),
            _row(featured, topLiked),
            const SizedBox(height: 28),
          ],
          if (topLiked.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text('❤️', style: TextStyle(fontSize: 15)),
                    SizedBox(width: 6),
                    Text('Popular Coffee', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      slideUpRoute(BestSellersPage(shop: widget.shop, menuItems: menuItems)),
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
            _row(topLiked, topLiked),
            const SizedBox(height: 28),
          ],
          // The full menu, organized by coffee category.
          for (final (name, items) in CoffeeCategory.group(menuItems)) ...[
            CoffeeSectionTitle(name, count: items.length),
            const SizedBox(height: 12),
            _grid(items, topLiked),
            const SizedBox(height: 24),
          ],
        ] else
          _grid(CoffeeCategory.group(menuItems).firstWhere((g) => g.$1 == category).$2, topLiked),
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
  final VoidCallback onTap;

  const _MenuItemCard({
    required this.shop,
    required this.item,
    required this.photoIndex,
    required this.isLiked,
    required this.isTopPick,
    required this.onToggleLike,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Up to two labels: owner's Best Seller / Featured / New, plus Popular
    // for the most-hearted coffees.
    final badges = [
      ...coffeeBadges(item, includeUnavailable: false),
      if (isTopPick) CoffeeBadgeKind.popular,
    ]..sort((a, b) => a.index.compareTo(b.index));
    final shown = [
      if (badges.contains(CoffeeBadgeKind.bestSeller)) CoffeeBadgeKind.bestSeller,
      if (badges.contains(CoffeeBadgeKind.popular)) CoffeeBadgeKind.popular,
      ...badges.where((b) => b != CoffeeBadgeKind.bestSeller && b != CoffeeBadgeKind.popular),
    ].take(2);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: ImageRatios.coffee,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Opacity(
                      opacity: item.available ? 1 : 0.45,
                      child: MenuItemImage(item: item, shop: shop, fallbackIndex: photoIndex + 20, width: double.infinity, height: double.infinity),
                    ),
                  ),
                ),
                if (!item.available)
                  const Positioned(left: 8, bottom: 8, child: CoffeeBadge(CoffeeBadgeKind.unavailable)),
                if (shown.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 48,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final badge in shown) ...[
                          CoffeeBadge(badge),
                          const SizedBox(height: 4),
                        ],
                      ],
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
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: item.available ? AppColors.textDark : AppColors.textGrey),
          ),
          Text(
            item.available ? item.category : '${item.category} · Unavailable',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: item.available ? AppColors.textGrey : const Color(0xFFD64545), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text(
                MenuItem.formatPrice(item.price),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryBrown),
              ),
              const Spacer(),
              Icon(Icons.favorite_rounded, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 2),
              Text('${item.likes}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------ REVIEWS TAB -------------------------------

class _ReviewsTab extends StatelessWidget {
  final List<Review> reviews;
  final VoidCallback onAddReview;

  final String shopName;
  final String? shopLogoUrl;

  const _ReviewsTab({required this.reviews, required this.shopName, this.shopLogoUrl, required this.onAddReview});

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
                    itemBuilder: (context, index) => _ReviewCard(review: reviews[index], shopName: shopName, shopLogoUrl: shopLogoUrl),
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
    // The café's gallery: the owner's other uploaded photos, in their saved
    // order — not the banner (that's the header photo).
    final photos = ShopBanner.galleryFor(shop);
    if (photos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library_outlined, size: 48, color: AppColors.textGrey.withOpacity(0.5)),
              const SizedBox(height: 12),
              const Text(
                'No photos available yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
      );
    }

    void open(int index) => openPhotoViewer(context, photos, initialIndex: index);

    // The first photo wide (16:9), the rest two to a row (4:3).
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: AspectRatio(
              aspectRatio: ImageRatios.banner,
              child: GalleryTile(url: photos.first, onTap: () => open(0)),
            ),
          ),
        ),
        if (photos.length > 1)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 4 / 3,
              ),
              itemCount: photos.length - 1,
              itemBuilder: (context, i) => GalleryTile(url: photos[i + 1], onTap: () => open(i + 1)),
            ),
          ),
      ],
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
        // The owner's description, only when they've written one.
        if (shop.description.trim().isNotEmpty) ...[
          const Text('About', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(shop.description.trim(), style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.5)),
          const SizedBox(height: 20),
        ],
        _InfoRow(icon: Icons.location_on_outlined, text: shop.locationLabel),
        if (shop.mallFloorAndUnit != null)
          _InfoRow(icon: Icons.layers_outlined, text: shop.mallFloorAndUnit!),
        if (shop.isInMall && (shop.mallLandmark?.trim().isNotEmpty ?? false))
          _InfoRow(icon: Icons.signpost_outlined, text: shop.mallLandmark!.trim()),
        _HoursRow(hours: shop.hours),
        _InfoRow(icon: Icons.category_outlined, text: shop.categoryLabel),
      ],
    );
  }
}

/// The weekly schedule in the About tab — one line per day, today in
/// bold — or "Hours unavailable" / the temporary-closure status.
class _HoursRow extends StatelessWidget {
  final OperatingHours hours;

  const _HoursRow({required this.hours});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toUtc().add(OperatingHours.manilaOffset).weekday;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primaryBrown),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OpenStatusLine(hours: hours, fontSize: 13),
                if (hours.hasHours) ...[
                  const SizedBox(height: 8),
                  for (var d = 1; d <= 7; d++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 44,
                            child: Text(
                              OperatingHours.shortDayNames[d]!,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textDark,
                                fontWeight: d == today ? FontWeight.w800 : FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            hours.describeDay(d),
                            style: TextStyle(
                              fontSize: 13,
                              color: hours.days.containsKey(d) ? AppColors.textDark : AppColors.textGrey,
                              fontWeight: d == today ? FontWeight.w800 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
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