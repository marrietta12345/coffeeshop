import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';
import '../widgets/top_banner.dart';
import '../utils/location_service.dart';

/// Interactive map picker — the map pans/zooms freely underneath a fixed
/// center pin (the classic "drop a pin" pattern used by Google Maps,
/// Grab, Foodpanda, etc.). Whatever the pin is pointing at when the user
/// taps Confirm is returned as the shop's exact coordinates.
class PickShopLocationPage extends StatefulWidget {
  final LatLng initialCenter;

  const PickShopLocationPage({super.key, required this.initialCenter});

  @override
  State<PickShopLocationPage> createState() => _PickShopLocationPageState();
}

class _PickShopLocationPageState extends State<PickShopLocationPage> {
  late final MapController _mapController;
  late LatLng _currentCenter;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = widget.initialCenter;
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);

    final result = await getCurrentLocation();
    if (!mounted) return;

    if (result.isSuccess) {
      final here = result.position!;
      _mapController.move(here, 17);
      setState(() => _currentCenter = here);
    } else {
      showTopBanner(context, result.errorMessage!, isSuccess: false, duration: const Duration(seconds: 3));
    }

    if (mounted) setState(() => _isLocating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: 16,
              minZoom: 4,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.flingAnimation,
              ),
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() => _currentCenter = position.center);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kafelo.local_based_coffee_shops',
              ),
            ],
          ),
          // Fixed pin overlay — always dead-center of the screen, so
          // whatever's underneath it when the map stops moving is the
          // selected coordinate.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36), // visually anchor the pin TIP at center
                child: _CenterPin(),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10)],
                    ),
                    child: const Text(
                      'Drag the map to place your pin',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // "Use my current location" — floats above the confirm button,
          // right-aligned, matching the standard map-app pattern.
          Positioned(
            right: 20,
            bottom: 92,
            child: SafeArea(
              top: false,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _isLocating ? null : _useCurrentLocation,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: _isLocating
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryBrown),
                          )
                        : const Icon(Icons.my_location_rounded, color: AppColors.primaryBrown, size: 22),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBrown,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  onPressed: () => Navigator.pop(context, _currentCenter),
                  child: const Text(
                    'Confirm This Location',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryBrown,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Image.asset(
            'lib/images/kafelo_logo.png',
            color: Colors.white,
          ),
        ),
        Container(
          width: 3,
          height: 18,
          color: AppColors.primaryBrown,
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.25),
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10)],
        ),
        child: Icon(icon, size: 20, color: AppColors.textDark),
      ),
    );
  }
}