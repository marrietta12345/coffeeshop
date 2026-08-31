import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../data/mock_coffee_shops.dart';
import '../widgets/coffee_search_bar.dart';
import '../widgets/shop_mini_card.dart';
import '../utils/distance_utils.dart';
import '../utils/location_service.dart';
import '../utils/page_transitions.dart';
import '../widgets/top_banner.dart';
import '../widgets/favorite_heart_button.dart';
import '../widgets/shop_photo.dart';
import 'shop_detail_page.dart';

/// Map content. Plain widget (no Scaffold) — MainNavPage supplies
/// the Scaffold and bottom nav so tab switching never loses this screen.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  final _mapController = MapController();

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
    _shopsSubscription?.cancel();
    super.dispose();
  }

  List<CoffeeShop> get _filteredShops {
    // Mock shops (demo data) + real shops owners have created via sign-up.
    return [...mockCoffeeShops, ..._liveShops];
  }

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
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation,
            initialZoom: 14.5,
            minZoom: 4,
            maxZoom: 19,
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
                ..._filteredShops.map((shop) {
                  return Marker(
                    point: LatLng(shop.latitude, shop.longitude),
                    width: 54,
                    height: 66,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _showPinPreview(shop),
                      child: const _ShopPin(),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: CoffeeSearchBar(controller: _searchController),
          ),
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
                                        _mapController.move(LatLng(shop.latitude, shop.longitude), 16);
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
                    _mapController.move(
                      LatLng(shop.latitude, shop.longitude),
                      16,
                    );
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

class _ShopPin extends StatelessWidget {
  const _ShopPin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
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
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTailPainter(),
        ),
      ],
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
                Text(
                  '${shop.isOpenNow ? "Open" : "Closed"} • Closes ${shop.closeTime}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: shop.isOpenNow ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                  ),
                ),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: shop.isOpenNow
                        ? const Color(0xFFE7F5E8)
                        : const Color(0xFFFBE7E7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    shop.isOpenNow ? 'Open' : 'Closed',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: shop.isOpenNow
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}