import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../models/coffee_preferences.dart';
import '../models/coffee_shop.dart';
import '../models/operating_hours.dart';
import '../widgets/best_seller_tile.dart';
import '../widgets/coffee_search_bar.dart';
import '../widgets/shop_photo.dart';
import '../widgets/shop_mini_card.dart';
import '../utils/distance_utils.dart';
import '../utils/location_service.dart';
import '../utils/menu_service.dart';
import '../utils/page_transitions.dart';
import '../utils/cafe_search.dart';
import '../utils/map_area_focus.dart';
import '../utils/recommendations.dart';
import '../utils/user_profile_service.dart';
import 'all_best_sellers_page.dart';
import 'coffee_preferences_page.dart';
import 'shop_detail_page.dart';
import 'shop_list_page.dart';

/// Browse-style Explore tab — search (live autocomplete over real cafés:
/// names, locations/malls, coffee types, atmosphere, features), then
/// "Recommended for You" (cafés ranked
/// by how well they match the user's Coffee Preferences), a horizontal
/// "Popular Coffee Shops" carousel, and "Best Sellers" — café-marked Best
/// Sellers first, then the most-hearted coffees across every café. Complements the map tab (location-first) with
/// a listing-first way to discover shops.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  // Search: suggestions show while typing; picking one (or pressing
  // search) swaps the sections below for the matching cafés.
  String _query = '';
  bool _showSuggestions = false;
  SearchSuggestion? _pickedSuggestion;
  String? _submittedQuery;

  bool get _isSearching => _pickedSuggestion != null || _submittedQuery != null;

  // Fallback (Butuan City) used only until real GPS is available, or if
  // the user has denied location permission.
  static const _fallbackLocation = LatLng(8.9475, 125.5406);
  LatLng _userLocation = _fallbackLocation;

  // Real shops owners have created, kept live via a Firestore listener.
  List<CoffeeShop> _shops = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _shopsSubscription;

  // The signed-in user's Coffee Preferences, kept live so "Recommended
  // for You" updates as soon as they're changed and saved.
  CoffeePreferences _prefs = const CoffeePreferences();
  StreamSubscription<Map<String, dynamic>>? _prefsSubscription;

  @override
  void initState() {
    super.initState();
    _shopsSubscription = FirebaseFirestore.instance.collection('shops').snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        setState(() => _shops = snapshot.docs.map(CoffeeShop.fromFirestore).toList());
        _loadBestSellersIfCafesChanged();
      },
      onError: (Object error) => debugPrint('Explore shops stream error: $error'),
    );
    _prefsSubscription = UserProfileService.profileStream().listen(
      (profile) {
        if (!mounted) return;
        setState(() => _prefs = CoffeePreferences.fromMap(profile['coffeePreferences'] as Map<String, dynamic>?));
      },
      onError: (Object error) => debugPrint('Explore preferences stream error: $error'),
    );
    _loadCurrentLocation();
    WidgetsBinding.instance.addObserver(this);
  }

  bool _hasLocation = false;
  bool _locating = false;

  Future<void> _loadCurrentLocation() async {
    if (_locating) return;
    _locating = true;
    final result = await getCurrentLocation();
    _locating = false;
    if (!mounted || !result.isSuccess) return;
    setState(() {
      _userLocation = result.position!;
      _hasLocation = true;
    });
  }

  /// Back in Kafelo after turning on Location → try again automatically.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_hasLocation) _loadCurrentLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocus.dispose();
    _shopsSubscription?.cancel();
    _prefsSubscription?.cancel();
    super.dispose();
  }

  static const double _popularMinRating = 4.0;

  /// Cafés rated 4.0 or higher, best rated first.
  List<CoffeeShop> get _popularShops {
    final shops = _shops.where((s) => s.rating >= _popularMinRating).toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return shops;
  }

  static const _distance = Distance();

  /// Every café, nearest first.
  List<CoffeeShop> get _allShops {
    double meters(CoffeeShop s) => _distance.as(LengthUnit.Meter, _userLocation, LatLng(s.latitude, s.longitude));
    return List.of(_shops)..sort((a, b) => meters(a).compareTo(meters(b)));
  }

  void _openShopList({required String title, required List<CoffeeShop> shops, required String emptyText}) {
    Navigator.of(context).push(
      slideFadeRoute(ShopListPage(title: title, shops: shops, userLocation: _userLocation, emptyText: emptyText)),
    );
  }

  // Best Sellers from the cafés' real menus (each café's `menu`
  // subcollection), ranked by MenuService.rankBestSellers.
  static const _bestSellersPreview = 6;
  List<CafeCoffee> _bestSellers = [];
  bool _bestSellersLoaded = false;
  String _bestSellersCafeKey = '';
  int _bestSellersLoad = 0; // only the newest load may update the list

  /// Reloads Best Sellers when cafés are added or removed (not on every
  /// rating/favorite change to a café document).
  void _loadBestSellersIfCafesChanged() {
    final key = (_shops.map((s) => s.id).toList()..sort()).join(',');
    if (key == _bestSellersCafeKey) return;
    _bestSellersCafeKey = key;
    _loadBestSellers();
  }

  Future<void> _loadBestSellers() async {
    final load = ++_bestSellersLoad;
    final ranked = MenuService.rankBestSellers(await MenuService.cafeMenus(_shops));
    if (!mounted || load != _bestSellersLoad) return;
    setState(() {
      _bestSellers = ranked;
      _bestSellersLoaded = true;
    });
  }

  Future<void> _openCoffee(CafeCoffee coffee) async {
    try {
      await openCafeCoffee(context, coffee.shop, coffee.item);
    } catch (e) {
      debugPrint('Explore: could not open coffee: $e');
    }
    _loadBestSellers(); // hearts may have changed
  }

  Future<void> _openAllBestSellers() async {
    await Navigator.of(context).push(slideFadeRoute(AllBestSellersPage(shops: _shops)));
    _loadBestSellers();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _query = value;
      _showSuggestions = value.trim().isNotEmpty;
      // Typing again starts a new search.
      _pickedSuggestion = null;
      _submittedQuery = null;
    });
  }

  void _onSearchSubmitted(String value) {
    final query = value.trim();
    _searchFocus.unfocus();
    setState(() {
      _showSuggestions = false;
      _pickedSuggestion = null;
      _submittedQuery = query.isEmpty ? null : query;
    });
  }

  void _pickSuggestion(SearchSuggestion suggestion) {
    _searchController.value = TextEditingValue(
      text: suggestion.label,
      selection: TextSelection.collapsed(offset: suggestion.label.length),
    );
    _searchFocus.unfocus();
    setState(() {
      _query = suggestion.label;
      _showSuggestions = false;
      _pickedSuggestion = suggestion;
      _submittedQuery = null;
    });
    // A place opens on the Map, zoomed to its cafés (the list stays here too).
    if (suggestion.isPlace) {
      MapAreaFocus.show(MapArea(label: suggestion.label, kind: suggestion.kind, shops: suggestion.shops));
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _query = '';
      _showSuggestions = false;
      _pickedSuggestion = null;
      _submittedQuery = null;
    });
  }

  /// Cafés for the current search, from the live café list (so results
  /// stay current if cafés change while they're shown).
  List<CoffeeShop> get _searchResults {
    final picked = _pickedSuggestion;
    if (picked != null) return CafeSearch.resultsForSuggestion(picked, _shops);
    return CafeSearch.search(_submittedQuery ?? '', _shops);
  }

  List<Widget> _searchResultsSection() {
    final results = _searchResults;
    final term = _pickedSuggestion?.label ?? _submittedQuery ?? '';
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              'Results for “$term”',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
          ),
          GestureDetector(
            onTap: _clearSearch,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Text('Clear', style: TextStyle(fontSize: 12, color: AppColors.primaryBrown, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      Text(
        results.length == 1 ? '1 café found' : '${results.length} cafés found',
        style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
      ),
      const SizedBox(height: 12),
      if (results.isEmpty)
        _EmptyNote('No cafés found for “$term”. Try another name, place, or coffee.')
      else
        for (final shop in results) ...[
          ShopListCard(
            shop: shop,
            distanceLabel: formatDistance(_userLocation, LatLng(shop.latitude, shop.longitude)),
            onTap: () => _openShop(shop),
          ),
          const SizedBox(height: 12),
        ],
    ];
  }

  void _openShop(CoffeeShop shop) {
    Navigator.of(context).push(slideUpRoute(ShopDetailPage(shop: shop)));
  }

  /// Cafés ranked by how many of the user's Coffee Preferences they match
  /// (empty when no preferences are set — see recommendCafes).
  List<Recommendation> get _recommendations => recommendCafes(
        _prefs,
        _shops,
        distanceMeters: (s) => _distance.as(LengthUnit.Meter, _userLocation, LatLng(s.latitude, s.longitude)),
      );

  /// "Recommended for You": personalized carousel when the user has Coffee
  /// Preferences; otherwise a prompt to set them (no generic picks
  /// dressed up as personal ones).
  List<Widget> _recommendedSection() {
    const title = 'Recommended for You';
    if (!_prefs.hasAny) {
      return [
        const Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 12),
        _EmptyNote(
          'Set your coffee preferences to get personalized recommendations.',
          actionLabel: 'Set Preferences',
          onAction: () => Navigator.of(context).push(slideFadeRoute(const CoffeePreferencesPage())),
        ),
      ];
    }
    final recommendations = _recommendations;
    final percentById = {for (final r in recommendations) r.shop.id: r.percent};
    return _shopCarouselSection(
      title: title,
      shops: [for (final r in recommendations) r.shop],
      emptyText: 'No cafés match your Coffee Preferences yet.',
      matchPercentFor: (shop) => percentById[shop.id],
    );
  }

  /// Section header with a working "View all", then a horizontal card
  /// carousel of [shops] (or a muted note when there are none).
  /// [matchPercentFor] adds the ✨ match % pill on each card's photo.
  List<Widget> _shopCarouselSection({
    required String title,
    required List<CoffeeShop> shops,
    required String emptyText,
    int? Function(CoffeeShop shop)? matchPercentFor,
  }) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
          GestureDetector(
            onTap: () => _openShopList(title: title, shops: shops, emptyText: emptyText),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              // Bigger tap target without changing how it looks.
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Text('View all', style: TextStyle(fontSize: 12, color: AppColors.primaryBrown, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (shops.isEmpty)
        _EmptyNote(emptyText)
      else
        SizedBox(
          height: ShopMiniCard.heightFor(150, MediaQuery.textScalerOf(context)),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shops.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final shop = shops[index];
              final distance = formatDistance(_userLocation, LatLng(shop.latitude, shop.longitude));
              return ShopMiniCard(
                shop: shop,
                distanceLabel: distance,
                matchPercent: matchPercentFor?.call(shop),
                onTap: () => _openShop(shop),
              );
            },
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFAF8F5),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            const Text(
              'Explore',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
            const SizedBox(height: 14),
            CoffeeSearchBar(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
              onClear: _clearSearch,
            ),
            if (_showSuggestions) ...[
              const SizedBox(height: 8),
              _SearchSuggestionsCard(
                query: _query.trim(),
                suggestions: CafeSearch.suggestions(_query, _shops),
                userLocation: _hasLocation ? _userLocation : null,
                onSelected: _pickSuggestion,
                onSeeAll: () => _onSearchSubmitted(_query),
              ),
            ],
            const SizedBox(height: 26),
            if (_isSearching)
              ..._searchResultsSection()
            else ...[
            ..._recommendedSection(),
            const SizedBox(height: 28),
            ..._shopCarouselSection(
              title: 'Popular Coffee Shops',
              shops: _popularShops,
              emptyText: 'No coffee shops rated 4.0 or higher yet.',
            ),
            const SizedBox(height: 28),
            ..._shopCarouselSection(
              title: 'All Cafés',
              shops: _allShops,
              emptyText: 'No coffee shops yet.',
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Best Sellers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
                ),
                GestureDetector(
                  onTap: _openAllBestSellers,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    // Bigger tap target without changing how it looks.
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Text('View all', style: TextStyle(fontSize: 12, color: AppColors.primaryBrown, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_bestSellersLoaded)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryBrown),
                  ),
                ),
              )
            else if (_bestSellers.isEmpty)
              const _EmptyNote('No best sellers yet.')
            else
              ..._bestSellers.take(_bestSellersPreview).map((coffee) => BestSellerTile(
                    item: coffee.item,
                    shop: coffee.shop,
                    onTap: () => _openCoffee(coffee),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

/// Muted one-line note shown when a section has nothing to list.
class _EmptyNote extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyNote(this.text, {this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
            if (actionLabel != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onAction,
                child: Text(
                  actionLabel!,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryBrown),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Autocomplete dropdown under the Explore search bar: cafés (with their
/// photo), then locations/malls, coffee types, atmospheres and features —
/// each with how many cafés it leads to. Same card look as the map's
/// search suggestions.
class _SearchSuggestionsCard extends StatelessWidget {
  final String query;
  final List<SearchSuggestion> suggestions;
  final LatLng? userLocation; // null when location is off
  final ValueChanged<SearchSuggestion> onSelected;
  final VoidCallback onSeeAll;

  const _SearchSuggestionsCard({
    required this.query,
    required this.suggestions,
    required this.userLocation,
    required this.onSelected,
    required this.onSeeAll,
  });

  static const Map<SuggestionKind, (IconData, String)> _kindInfo = {
    SuggestionKind.location: (Icons.location_on_rounded, 'Area'),
    SuggestionKind.mall: (Icons.local_mall_rounded, 'Mall'),
    SuggestionKind.landmark: (Icons.near_me_rounded, 'Landmark'),
    SuggestionKind.coffeeType: (Icons.local_cafe_rounded, 'Coffee'),
    SuggestionKind.atmosphere: (Icons.weekend_rounded, 'Atmosphere'),
    SuggestionKind.feature: (Icons.check_circle_outline_rounded, 'Feature'),
  };

  static const _distance = Distance();

  /// A place's icon from what it is: school, airport, hotel, church, mall…
  static IconData _placeIcon(SearchSuggestion suggestion) {
    if (suggestion.kind == SuggestionKind.mall) return Icons.local_mall_rounded;
    final name = suggestion.label.toLowerCase();
    bool has(List<String> words) => words.any((w) => RegExp('\\b$w').hasMatch(name));
    if (has(['university', 'college', 'school', 'fsuu', 'csu', 'phinma', 'sjit', 'anhs', 'pecit', 'tesda', 'campus'])) {
      return Icons.school_rounded;
    }
    if (has(['airport'])) return Icons.flight_rounded;
    if (has(['hotel'])) return Icons.hotel_rounded;
    if (has(['church', 'chapel'])) return Icons.church_rounded;
    if (has(['sm city', 'robinsons', 'mall', 'gaisano', 'square', 'food court', 'food hub'])) return Icons.storefront_rounded;
    if (has(['gym', 'fitness'])) return Icons.fitness_center_rounded;
    return suggestion.kind == SuggestionKind.landmark ? Icons.near_me_rounded : Icons.location_on_rounded;
  }

  /// "3 cafés · 2 open now · 1.1 km away" — what helps decide where to go.
  String _placeDetails(SearchSuggestion suggestion) {
    final count = suggestion.cafeCount == 1 ? '1 café' : '${suggestion.cafeCount} cafés';
    final parts = [count];
    final now = DateTime.now();
    final open = suggestion.shops.where((s) => s.hours.statusAt(now).state == OpenState.open).length;
    if (open > 0) parts.add('$open open now');
    final from = userLocation;
    if (from != null) {
      final located = suggestion.shops.where((s) => s.hasLocation).toList();
      if (located.isNotEmpty) {
        double meters(CoffeeShop s) => _distance.as(LengthUnit.Meter, from, LatLng(s.latitude, s.longitude));
        located.sort((a, b) => meters(a).compareTo(meters(b)));
        final label = formatDistance(from, LatLng(located.first.latitude, located.first.longitude));
        if (label.isNotEmpty) parts.add(label);
      }
    }
    return parts.join(' · ');
  }

  /// [text] with the letters the user typed in bold ("Ba" → **Ba**yanihan).
  Widget _highlighted(String text) {
    const base = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark);
    final range = CafeSearch.matchRange(text, CafeSearch.normalize(query));
    return Text.rich(
      range == null
          ? TextSpan(text: text, style: base.copyWith(fontWeight: FontWeight.w700))
          : TextSpan(style: base, children: [
              TextSpan(text: text.substring(0, range.$1)),
              TextSpan(text: text.substring(range.$1, range.$2), style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: text.substring(range.$2)),
            ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (suggestions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search_off_rounded, color: AppColors.textGrey, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No cafés match “$query”',
                        style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (var i = 0; i < suggestions.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 70, color: Color(0xFFF0EDEA)),
                _row(suggestions[i]),
              ],
            if (suggestions.isNotEmpty) ...[
              const Divider(height: 1, color: Color(0xFFF0EDEA)),
              InkWell(
                onTap: onSeeAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: AppColors.primaryBrown),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'See all results for “$query”',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryBrown),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(SearchSuggestion suggestion) {
    final shop = suggestion.shop;
    final info = _kindInfo[suggestion.kind];
    final count = suggestion.cafeCount == 1 ? '1 café' : '${suggestion.cafeCount} cafés';
    final subtitle = shop != null
        ? (shop.locationLabel.isEmpty ? shop.categoryLabel : shop.locationLabel)
        : suggestion.isPlace
            ? _placeDetails(suggestion)
            : '${info?.$2 ?? ''} · $count';
    final icon = suggestion.isPlace ? _placeIcon(suggestion) : (info?.$1 ?? Icons.search_rounded);

    return InkWell(
      onTap: () => onSelected(suggestion),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: shop != null
                  ? ShopLogoImage(shop: shop, width: 52, height: 39)
                  : Container(
                      width: 52,
                      height: 39,
                      color: AppColors.primaryBrown.withValues(alpha: 0.12),
                      child: Icon(icon, color: AppColors.primaryBrown, size: 22),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _highlighted(suggestion.label),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
            if (shop != null && shop.rating > 0) ...[
              const SizedBox(width: 8),
              const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A623)),
              Text(shop.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
    );
  }
}
