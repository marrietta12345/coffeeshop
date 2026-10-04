import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../widgets/coffee_search_bar.dart';
import '../widgets/shop_mini_card.dart';
import '../utils/distance_utils.dart';
import '../utils/location_service.dart';
import '../utils/page_transitions.dart';
import '../widgets/top_banner.dart';
import '../widgets/favorite_heart_button.dart';
import '../widgets/shop_photo.dart';
import '../widgets/open_status.dart';
import 'shop_detail_page.dart';

/// Map content. Plain widget (no Scaffold) — MainNavPage supplies
/// the Scaffold and bottom nav so tab switching never loses this screen.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _mapController = MapController();

  // Search autocomplete — suggestions show while typing and hide once a
  // café is picked, the map is tapped, or the search is cleared.
  String _query = '';
  bool _showSuggestions = false;
  static const _maxSuggestions = 6;

  // The café picked from search (or a tapped pin) gets an enlarged,
  // pulsing pin so it stands out from the rest.
  String? _highlightedShopId;
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  AnimationController? _cameraAnimation;

  // Real shops owners have created, kept live via a Firestore listener —
  // new shops appear on the map automatically, no refresh needed.
  List<CoffeeShop> _liveShops = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _shopsSubscription;

  // Fallback center (Butuan City) used only until real GPS is available,
  // or if the user denies location permission entirely.
  static const _fallbackCenter = LatLng(8.9475, 125.5406);

  LatLng _userLocation = _fallbackCenter;
  bool _hasRealLocation = false;
  bool _isLocating = true;

  @override
  void initState() {
    super.initState();
    _shopsSubscription = FirebaseFirestore.instance.collection('shops').snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _liveShops = snapshot.docs.map((doc) => CoffeeShop.fromFirestore(doc)).toList();
        });
      },
      onError: (Object error) {
        debugPrint('Live shops stream error: $error');
      },
    );
    _loadCurrentLocation(showErrors: false);
  }

  Future<void> _loadCurrentLocation({bool showErrors = true}) async {
    setState(() => _isLocating = true);
    final result = await getCurrentLocation();
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _userLocation = result.position!;
        _hasRealLocation = true;
        _isLocating = false;
      });
      _mapController.move(_userLocation, 15);
    } else {
      setState(() => _isLocating = false);
      if (showErrors) {
        showTopBanner(context, result.errorMessage!, isSuccess: false, duration: const Duration(seconds: 3));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _pulseController.dispose();
    _cameraAnimation?.dispose();
    _shopsSubscription?.cancel();
    super.dispose();
  }

  /// Cafés matching the search text, best match first: name starts with
  /// the query, then a word in the name does, then the name contains it,
  /// then the address does. Ties go to the nearest café, then A–Z.
  List<CoffeeShop> get _suggestions {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    int? score(CoffeeShop shop) {
      final name = shop.name.toLowerCase();
      if (name.startsWith(q)) return 0;
      if (name.split(RegExp(r'\s+')).any((word) => word.startsWith(q))) return 1;
      if (name.contains(q)) return 2;
      if (shop.address.toLowerCase().contains(q)) return 3;
      if (shop.mallName?.toLowerCase().contains(q) ?? false) return 3;
      return null;
    }

    final matches = <({CoffeeShop shop, int score, double meters})>[];
    for (final shop in _filteredShops) {
      final s = score(shop);
      if (s == null) continue;
      final meters = _hasRealLocation
          ? _distanceCalculator.as(LengthUnit.Meter, _userLocation, LatLng(shop.latitude, shop.longitude))
          : 0.0;
      matches.add((shop: shop, score: s, meters: meters));
    }
    matches.sort((a, b) {
      final byScore = a.score.compareTo(b.score);
      if (byScore != 0) return byScore;
      final byDistance = a.meters.compareTo(b.meters);
      if (byDistance != 0) return byDistance;
      return a.shop.name.toLowerCase().compareTo(b.shop.name.toLowerCase());
    });
    return matches.take(_maxSuggestions).map((m) => m.shop).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _query = value;
      _showSuggestions = value.trim().isNotEmpty;
    });
  }

  void _onSearchSubmitted(String _) {
    final suggestions = _suggestions;
    if (suggestions.isNotEmpty) _selectSuggestion(suggestions.first);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      _showSuggestions = false;
    });
    _setHighlightedShop(null);
  }

  void _hideSuggestions() {
    if (_searchFocus.hasFocus) _searchFocus.unfocus();
    if (_showSuggestions) setState(() => _showSuggestions = false);
  }

  Future<void> _selectSuggestion(CoffeeShop shop) async {
    // (The Scaffold strips the keyboard inset from this page's
    // MediaQuery, so the search field's focus is the reliable signal.)
    final keyboardWasOpen = _searchFocus.hasFocus;
    _searchController.value = TextEditingValue(
      text: shop.name,
      selection: TextSelection.collapsed(offset: shop.name.length),
    );
    _searchFocus.unfocus();
    setState(() {
      _query = shop.name;
      _showSuggestions = false;
    });
    _setHighlightedShop(shop.id);

    // Let the keyboard finish closing first — the map grows back to full
    // height as it does, which changes where "centered" is.
    if (keyboardWasOpen) await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    await _moveCameraToShop(shop, 17);
    if (!mounted) return;
    _showPinPreview(shop);
  }

  /// Pans/zooms so [shop]'s pin sits in the middle of the map area left
  /// visible above its preview card.
  Future<void> _moveCameraToShop(CoffeeShop shop, double zoom) {
    return _animateCamera(_centerShowingPin(LatLng(shop.latitude, shop.longitude), zoom), zoom);
  }

  void _setHighlightedShop(String? shopId) {
    if (_highlightedShopId == shopId) return;
    setState(() => _highlightedShopId = shopId);
    if (shopId == null) {
      _pulseController.stop();
    } else if (!_pulseController.isAnimating && !MediaQuery.of(context).disableAnimations) {
      _pulseController.repeat();
    }
  }

  /// The map center that puts [target]'s pin in the middle of the map
  /// area left visible between the search bar and the preview card that
  /// opens over the bottom of the screen — so the café's marker isn't
  /// hidden under the card.
  LatLng _centerShowingPin(LatLng target, double zoom) {
    final camera = _mapController.camera;
    final mapHeight = camera.nonRotatedSize.height;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    // Search bar bottom edge, and the top edge of _MapPinPreviewCard
    // (16:9 photo + ~170px of text and button). The map starts at the top
    // of the screen, so screen y == map y.
    final visibleTop = MediaQuery.paddingOf(context).top + 16 + 54;
    final previewCardHeight = screenWidth * 9 / 16 + 170;
    final visibleBottom = screenHeight - previewCardHeight;
    if (visibleBottom - visibleTop < 120) return target;

    // The pin is drawn above its point, so aim its point slightly lower
    // than the visible middle to center the pin itself.
    final pinPointY = (visibleTop + visibleBottom) / 2 + 30;
    final shiftDown = mapHeight / 2 - pinPointY;
    final projected = camera.projectAtZoom(target, zoom);
    return camera.unprojectAtZoom(projected + Offset(0, shiftDown), zoom);
  }

  /// Smoothly pans + zooms the map to [center]/[zoom]. Jumps instantly
  /// when the OS "Reduce Motion" setting is on.
  Future<void> _animateCamera(LatLng center, double zoom) async {
    _cameraAnimation?.dispose();
    _cameraAnimation = null;
    if (MediaQuery.of(context).disableAnimations) {
      _mapController.move(center, zoom);
      return;
    }

    final start = _mapController.camera;
    final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _cameraAnimation = controller;
    final curve = CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);
    controller.addListener(() {
      final t = curve.value;
      _mapController.move(
        LatLng(
          start.center.latitude + (center.latitude - start.center.latitude) * t,
          start.center.longitude + (center.longitude - start.center.longitude) * t,
        ),
        start.zoom + (zoom - start.zoom) * t,
      );
    });
    try {
      await controller.forward().orCancel;
    } on TickerCanceled {
      // Superseded by another camera move, or the page was disposed.
    }
  }

  // Real shops owners have created via sign-up, live from Firestore.
  List<CoffeeShop> get _filteredShops => _liveShops;

  static const _distanceCalculator = Distance();
  static const double _nearbyRadiusMeters = 20000; // 20 km

  /// Only the closest shops to the user's real location, sorted nearest
  /// first — NOT every registered shop. Returns an empty list (rather
  /// than falling back to showing everything) when no real location is
  /// available, since "nearby" is meaningless without one.
  List<CoffeeShop> get _nearbyShops {
    if (!_hasRealLocation) return [];
    final withDistance = _filteredShops.map((shop) {
      final meters = _distanceCalculator.as(
        LengthUnit.Meter,
        _userLocation,
        LatLng(shop.latitude, shop.longitude),
      );
      return (shop: shop, meters: meters);
    }).where((entry) => entry.meters <= _nearbyRadiusMeters).toList();
    withDistance.sort((a, b) => a.meters.compareTo(b.meters));
    return withDistance.map((e) => e.shop).take(10).toList();
  }

  void _openShopDetails(CoffeeShop shop) {
    Navigator.of(context).push(slideUpRoute(ShopDetailPage(shop: shop)));
  }

  void _showPinPreview(CoffeeShop shop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MapPinPreviewCard(
        shop: shop,
        userLocation: _userLocation,
        onViewDetails: () {
          Navigator.pop(context);
          _openShopDetails(shop);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _showSuggestions ? _suggestions : const <CoffeeShop>[];
    // Highlighted café last, so its pin draws on top of any neighbours.
    final shopsForMarkers = [
      ..._filteredShops.where((s) => s.id != _highlightedShopId),
      ..._filteredShops.where((s) => s.id == _highlightedShopId),
    ];

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation,
            initialZoom: 14.5,
            minZoom: 4,
            maxZoom: 19,
            onTap: (_, __) => _hideSuggestions(),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom |
                  InteractiveFlag.drag |
                  InteractiveFlag.doubleTapZoom |
                  InteractiveFlag.flingAnimation,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.kafelo.local_based_coffee_shops',
            ),
            MarkerLayer(
              markers: [
                if (_hasRealLocation)
                  Marker(
                    point: _userLocation,
                    width: 22,
                    height: 22,
                    child: const _UserLocationDot(),
                  ),
                ...shopsForMarkers.map((shop) {
                  final isHighlighted = shop.id == _highlightedShopId;
                  return Marker(
                    point: LatLng(shop.latitude, shop.longitude),
                    width: 54,
                    height: 66,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () {
                        _hideSuggestions();
                        _setHighlightedShop(shop.id);
                        _showPinPreview(shop);
                      },
                      child: _ShopPin(highlighted: isHighlighted, pulse: isHighlighted ? _pulseController : null),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
        // Recenter-to-my-location button, floating above the nearby panel.
        Positioned(
          right: 18,
          bottom: 232,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _isLocating ? null : () => _loadCurrentLocation(showErrors: true),
              child: SizedBox(
                width: 46,
                height: 46,
                child: _isLocating
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryBrown),
                      )
                    : const Icon(Icons.my_location_rounded, color: AppColors.primaryBrown, size: 22),
              ),
            ),
          ),
        ),
        // Persistent "Nearby Coffee Shops" panel — always visible, no tap
        // needed to reveal it, matching the reference design.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Nearby Coffee Shops',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
                    ),
                    GestureDetector(
                      onTap: _hasRealLocation
                          ? () => _showResultsSheet(context)
                          : () {
                              showTopBanner(
                                context,
                                'Turn on location to see nearby shops.',
                                isSuccess: false,
                              );
                            },
                      child: const Text(
                        'View all',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryBrown),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Explore the best coffee spots near you.',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 148,
                  child: _isLocating
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryBrown),
                          ),
                        )
                      : !_hasRealLocation
                          ? _LocationRequiredNotice(onEnableLocation: () => _loadCurrentLocation(showErrors: true))
                          : _nearbyShops.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No coffee shops within 20 km of you yet.',
                                    style: TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                                  ),
                                )
                              : ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _nearbyShops.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                  itemBuilder: (context, index) {
                                    final shop = _nearbyShops[index];
                                    final distance = formatDistance(_userLocation, LatLng(shop.latitude, shop.longitude));
                                    return ShopMiniCard(
                                      shop: shop,
                                      distanceLabel: distance,
                                      width: 130,
                                      onTap: () {
                                        _moveCameraToShop(shop, 16);
                                        _showPinPreview(shop);
                                      },
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
        // Search bar + autocomplete, last so the dropdown sits above the
        // recenter button and the nearby panel.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                    shops: suggestions,
                    query: _query.trim(),
                    userLocation: _hasRealLocation ? _userLocation : null,
                    onSelected: _selectSuggestion,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showResultsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _nearbyShops.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }
                final shop = _nearbyShops[index - 1];
                return _ShopListCard(
                  shop: shop,
                  onTap: () {
                    Navigator.pop(context);
                    _moveCameraToShop(shop, 16);
                    _showPinPreview(shop);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// The branded map pin — logo badge in a white circle with a brown ring
/// and soft shadow, replacing the default marker look entirely.
/// The classic "you are here" blue dot with a soft pulse ring — standard
/// pattern from Google Maps / Apple Maps for showing the device's real
/// GPS position, distinct from the branded brown shop pins.
class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF4285F4).withOpacity(0.2),
      ),
      child: Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4285F4),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

/// Shown in place of the Nearby Coffee Shops list when the user's real
/// location isn't available — makes it explicit that location is
/// required for this feature, instead of silently showing every
/// registered shop regardless of how far away it actually is.
class _LocationRequiredNotice extends StatelessWidget {
  final VoidCallback onEnableLocation;

  const _LocationRequiredNotice({required this.onEnableLocation});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off_rounded, size: 22, color: AppColors.textGrey),
          const SizedBox(height: 6),
          const Text(
            'Turn on location to see nearby shops',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onEnableLocation,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primaryBrown,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Enable Location',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// When [highlighted] (the café picked from search / tapped), the pin is
/// drawn larger with a soft brown ring pulsing out from behind it.
class _ShopPin extends StatelessWidget {
  final bool highlighted;
  final Animation<double>? pulse;

  const _ShopPin({this.highlighted = false, this.pulse});

  @override
  Widget build(BuildContext context) {
    final pin = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (highlighted && pulse != null)
              Positioned(
                left: -22,
                top: -22,
                right: -22,
                bottom: -22,
                child: AnimatedBuilder(
                  animation: pulse!,
                  builder: (context, _) {
                    final t = pulse!.value;
                    return Transform.scale(
                      scale: 0.55 + 0.45 * t,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryBrown.withOpacity(0.45 * (1 - t)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            _pinHead(),
          ],
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTailPainter(),
        ),
      ],
    );

    if (!highlighted) return pin;
    // Grow from the tip so the pin still points at the exact spot.
    return Transform.scale(scale: 1.3, alignment: const Alignment(0, 0.64), child: pin);
  }

  Widget _pinHead() {
    return Container(
          width: 46,
          height: 46,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryBrown,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Image.asset(
            'lib/images/kafelo_logo.png',
            color: Colors.white,
          ),
        );
  }
}

/// Live autocomplete dropdown under the map search bar — photo, name
/// (matching text in bold), address and distance for each café.
class _SearchSuggestionsCard extends StatelessWidget {
  final List<CoffeeShop> shops;
  final String query;
  final LatLng? userLocation;
  final ValueChanged<CoffeeShop> onSelected;

  const _SearchSuggestionsCard({
    required this.shops,
    required this.query,
    required this.userLocation,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 340),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: shops.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search_off_rounded, color: AppColors.textGrey, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No coffee shops match "$query"',
                        style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: shops.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 70, color: Color(0xFFF0EDEA)),
                itemBuilder: (context, index) {
                  final shop = shops[index];
                  final location = userLocation;
                  return InkWell(
                    onTap: () => onSelected(shop),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: ShopPhoto(shop: shop, width: 44, height: 44),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _highlightedName(shop.name),
                                const SizedBox(height: 2),
                                Text(
                                  shop.locationLabel.isEmpty ? shop.categoryLabel : shop.locationLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                                ),
                              ],
                            ),
                          ),
                          if (location != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              formatDistance(location, LatLng(shop.latitude, shop.longitude)),
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primaryBrown),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  /// The café name with the part matching the query in bold brown.
  Widget _highlightedName(String name) {
    const base = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark);
    final start = query.isEmpty ? -1 : name.toLowerCase().indexOf(query.toLowerCase());
    if (start < 0) {
      return Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: base.copyWith(fontWeight: FontWeight.w700));
    }
    final end = start + query.length;
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: name.substring(0, start)),
          TextSpan(
            text: name.substring(start, end),
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryBrown),
          ),
          TextSpan(text: name.substring(end)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Small solid triangle beneath the pin circle so it reads as a map
/// marker pointing at an exact spot, not just a floating badge.
class _PinTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primaryBrown;
    final path = ui.Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Compact preview shown when tapping a pin — full-width photo, a heart
/// toggle overlaid top-right, name/rating/distance/hours, and a
/// "View Details" button. Matches the reference's map-preview bottom sheet.
class _MapPinPreviewCard extends StatelessWidget {
  final CoffeeShop shop;
  final LatLng userLocation;
  final VoidCallback onViewDetails;

  const _MapPinPreviewCard({
    required this.shop,
    required this.userLocation,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final distance = formatDistance(userLocation, LatLng(shop.latitude, shop.longitude));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ShopPhoto(shop: shop, width: double.infinity, height: double.infinity),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: FavoriteHeartButton(shop: shop, size: 36),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.name,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF5A623)),
                    const SizedBox(width: 2),
                    Text(shop.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text('•', style: TextStyle(color: Colors.grey.shade400)),
                    const SizedBox(width: 8),
                    Text(distance, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
                  ],
                ),
                const SizedBox(height: 4),
                OpenStatusLine(hours: shop.hours, fontSize: 12.5),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBrown,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onViewDetails,
                    child: const Text(
                      'View Details',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
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

class _ShopListCard extends StatelessWidget {
  final CoffeeShop shop;
  final VoidCallback onTap;

  const _ShopListCard({required this.shop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ShopPhoto(shop: shop, width: 60, height: 60),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    shop.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 15),
                    const SizedBox(width: 2),
                    Text(
                      shop.rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                OpenStatusBadge(hours: shop.hours, tinted: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
