import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../utils/location_service.dart';
import '../utils/route_service.dart';

/// What the Directions screen is doing.
enum _Status { locating, routing, ready, recalculating, arrived, problem }

/// What went wrong, so the right message and action can be shown.
enum _Problem { serviceOff, permission, permissionForever, gps, route }

/// In-app directions to one café, on OpenStreetMap — no external maps app.
///
/// Gets the phone's real GPS position, asks OSRM for the road route to the
/// café's own saved coordinates (a mall café uses its own pin, not the
/// mall's), and draws it with the route's real distance and travel time.
/// While the screen is open the "You" marker follows the phone; the route
/// is only re-requested when the user strays off it (and not more than
/// every 20 s). Leaving the screen stops all location tracking. The live
/// position is never saved or shared.
class DirectionsPage extends StatefulWidget {
  final CoffeeShop shop;

  const DirectionsPage({super.key, required this.shop});

  @override
  State<DirectionsPage> createState() => _DirectionsPageState();
}

class _DirectionsPageState extends State<DirectionsPage> {
  final _mapController = MapController();
  StreamSubscription<LatLng>? _locationSub;

  LatLng? _me; // latest real GPS fix
  // Like Google Maps: Walk by default; Bike and Car one tap away. Routes
  // for every mode from the latest starting point (so each button shows
  // its own travel time); the selected one is drawn.
  TravelMode _mode = TravelMode.walk;
  final Map<TravelMode, RouteResult> _routes = {};
  int _routeGeneration = 0; // a newer starting point makes older results stale
  RouteResult? get _route => _routes[_mode];
  _Status _status = _Status.locating;
  _Problem? _problem;
  String? _routeError; // message for a failed route request
  bool _updatesPaused = false; // a re-route failed; the last route is kept
  bool _requesting = false;
  DateTime? _lastRouteRequest;
  bool _following = true; // camera follows "You" until the user moves the map
  bool _mapReady = false;
  bool _fittedOnce = false;

  LatLng get _cafe => LatLng(widget.shop.latitude, widget.shop.longitude);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _locationSub?.cancel(); // stop GPS tracking as soon as the screen closes
    super.dispose();
  }

  // ------------------------------------------------------------ location

  Future<void> _start() async {
    _locationSub?.cancel();
    _locationSub = null;
    setState(() {
      _status = _Status.locating;
      _problem = null;
      _routeError = null;
    });

    LocationAccess access;
    try {
      access = await ensureLocationAccess();
    } catch (e) {
      debugPrint('Location check failed: $e');
      if (!mounted) return;
      setState(() {
        _status = _Status.problem;
        _problem = _Problem.gps;
      });
      return;
    }
    if (!mounted) return;
    if (access != LocationAccess.ready) {
      setState(() {
        _status = _Status.problem;
        _problem = switch (access) {
          LocationAccess.serviceOff => _Problem.serviceOff,
          LocationAccess.deniedForever => _Problem.permissionForever,
          _ => _Problem.permission,
        };
      });
      return;
    }

    // First fix, then live updates every ~10 m of movement.
    final first = await getCurrentLocation();
    if (!mounted) return;
    if (!first.isSuccess) {
      setState(() {
        _status = _Status.problem;
        _problem = _Problem.gps;
      });
      return;
    }
    _onLocation(first.position!);
    _locationSub = watchLocation(distanceFilter: 10).listen(
      _onLocation,
      onError: (Object e) => debugPrint('Location updates stopped: $e'),
    );
  }

  void _onLocation(LatLng position) {
    final arrived = const Distance().as(LengthUnit.Meter, position, _cafe) <= RouteMath.arrivedMeters;
    setState(() {
      _me = position;
      if (arrived) {
        _status = _Status.arrived;
      } else if (_status == _Status.arrived) {
        _status = _Status.ready; // walked away again
      }
    });
    if (_following && _mapReady && _fittedOnce) {
      _mapController.move(position, _mapController.camera.zoom);
    }
    if (arrived) return;
    // GPS updates move the marker; a new route is only requested when off route.
    if (!_requesting &&
        RouteMath.shouldRecalculate(
          position: position,
          route: _route?.points,
          lastRequestAt: _lastRouteRequest,
          now: DateTime.now(),
        )) {
      _fetchRoute(position);
    }
  }

  // --------------------------------------------------------------- route

  Future<void> _fetchRoute(LatLng from) async {
    final hadRoute = _route != null;
    final mode = _mode;
    final generation = ++_routeGeneration;
    _requesting = true;
    _lastRouteRequest = DateTime.now();
    setState(() {
      _status = hadRoute ? _Status.recalculating : _Status.routing;
      _routeError = null;
      if (_problem == _Problem.route) _problem = null;
    });
    try {
      final route = await RouteService.fetchRoute(from, _cafe, mode: mode);
      if (!mounted) return;
      setState(() {
        // A new starting point replaces every mode's route — never two lines.
        _routes
          ..clear()
          ..[mode] = route;
        _updatesPaused = false;
        _status = _status == _Status.arrived ? _Status.arrived : _Status.ready;
      });
      if (!hadRoute) _fitAll();
      _fetchOtherModes(from, generation);
    } on RouteException catch (e) {
      if (!mounted) return;
      setState(() {
        if (hadRoute) {
          // Keep showing the last good route.
          _updatesPaused = true;
          _status = _Status.ready;
        } else {
          _status = _Status.problem;
          _problem = _Problem.route;
          _routeError = e.message;
        }
      });
    } finally {
      _requesting = false;
      // The user switched mode while this was loading → get that one now.
      if (mounted && mode != _mode && _route == null && _me != null) _fetchRoute(_me!);
    }
  }

  /// The other modes' routes, quietly, for the times on their buttons.
  void _fetchOtherModes(LatLng from, int generation) {
    for (final other in TravelMode.values) {
      if (other == _mode) continue;
      RouteService.fetchRoute(from, _cafe, mode: other).then((route) {
        if (mounted && generation == _routeGeneration) setState(() => _routes[other] = route);
      }, onError: (Object e) => debugPrint('${other.label} route unavailable: $e'));
    }
  }

  /// Walk / Bike / Car.
  void _selectMode(TravelMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    if (_route != null) {
      _fitAll(); // already have it — show it
    } else if (_me != null && !_requesting) {
      _fetchRoute(_me!);
    }
  }

  void _retry() {
    if (_problem == _Problem.route && _me != null) {
      setState(() => _problem = null);
      _fetchRoute(_me!);
    } else {
      _start();
    }
  }

  // -------------------------------------------------------------- camera

  /// Shows "You", the café and the whole route.
  void _fitAll() {
    if (!_mapReady) return;
    final points = [_cafe, if (_me != null) _me!, ...?_route?.points];
    if (points.length < 2) {
      _mapController.move(_cafe, 16);
      return;
    }
    final size = MediaQuery.sizeOf(context);
    _mapController.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: EdgeInsets.fromLTRB(48, 110, 48, size.height * 0.36),
      maxZoom: 17,
    ));
    _fittedOnce = true;
  }

  void _recenter() {
    if (_me == null) {
      _fitAll();
      return;
    }
    setState(() => _following = true);
    _mapController.move(_me!, _mapController.camera.zoom < 15 ? 16 : _mapController.camera.zoom);
  }

  // ------------------------------------------------------------------ UI

  String get _statusText => switch (_status) {
        _Status.locating => 'Finding your location…',
        _Status.routing => 'Finding route…',
        _Status.recalculating => 'Recalculating route…',
        _Status.arrived => "You've arrived",
        _Status.problem => _problem == _Problem.route ? 'Unable to calculate route' : 'Location needed',
        _Status.ready => _updatesPaused ? 'Route updates paused' : 'Route ready',
      };

  @override
  Widget build(BuildContext context) {
    final route = _route;
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _cafe,
              initialZoom: 15,
              minZoom: 4,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom | InteractiveFlag.flingAnimation,
              ),
              onMapReady: () {
                _mapReady = true;
                if (_route != null || _me != null) _fitAll();
              },
              // Moving the map by hand stops the camera following "You".
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && _following) setState(() => _following = false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kafelo.local_based_coffee_shops',
              ),
              if (route != null)
                PolylineLayer(
                  polylines: [
                    // Walking: a dotted line, like Google Maps; Bike / Car: solid.
                    _mode == TravelMode.walk
                        ? Polyline(
                            points: route.points,
                            strokeWidth: 7,
                            color: AppColors.primaryBrown,
                            pattern: const StrokePattern.dotted(spacingFactor: 1.6),
                          )
                        : Polyline(
                            points: route.points,
                            strokeWidth: 6,
                            color: AppColors.primaryBrown,
                            borderStrokeWidth: 2,
                            borderColor: Colors.white,
                          ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(point: _cafe, width: 54, height: 66, alignment: Alignment.topCenter, child: const _CafePin()),
                  if (_me != null) Marker(point: _me!, width: 26, height: 26, child: const _YouDot()),
                ],
              ),
            ],
          ),
          // Back + status, over the map.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(context),
                      child: const SizedBox(width: 44, height: 44, child: Icon(Icons.arrow_back_rounded, color: AppColors.textDark)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(child: _StatusChip(text: _statusText, busy: _status == _Status.locating || _status == _Status.routing || _status == _Status.recalculating)),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _InfoPanel(
              shop: widget.shop,
              route: route,
              mode: _mode,
              routes: _routes,
              onModeSelected: _selectMode,
              arrived: _status == _Status.arrived,
              updatesPaused: _updatesPaused,
              problem: _status == _Status.problem ? _problem : null,
              routeError: _routeError,
              onRecenter: _recenter,
              onShowAll: _fitAll,
              onRetry: _retry,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final bool busy;

  const _StatusChip({required this.text, required this.busy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBrown))
          else
            const Icon(Icons.directions_rounded, size: 16, color: AppColors.primaryBrown),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Café, distance, ETA, and the action buttons (or what's needed to continue).
class _InfoPanel extends StatelessWidget {
  final CoffeeShop shop;
  final RouteResult? route;
  final TravelMode mode;
  final Map<TravelMode, RouteResult> routes;
  final ValueChanged<TravelMode> onModeSelected;
  final bool arrived;
  final bool updatesPaused;
  final _Problem? problem;
  final String? routeError;
  final VoidCallback onRecenter;
  final VoidCallback onShowAll;
  final VoidCallback onRetry;

  const _InfoPanel({
    required this.shop,
    required this.route,
    required this.mode,
    required this.routes,
    required this.onModeSelected,
    required this.arrived,
    required this.updatesPaused,
    required this.problem,
    required this.routeError,
    required this.onRecenter,
    required this.onShowAll,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final route = this.route;
    return ConstrainedBox(
      // Never more than half the screen, so the map stays usable (landscape too).
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (problem == null || problem == _Problem.route) ...[
                  Row(
                    children: [
                      for (final m in TravelMode.values) ...[
                        if (m != TravelMode.values.first) const SizedBox(width: 8),
                        Expanded(
                          child: _ModeButton(
                            mode: m,
                            selected: m == mode,
                            minutes: routes[m]?.durationSeconds == null ? null : RouteMath.shortDuration(routes[m]!.durationSeconds!),
                            onTap: () => onModeSelected(m),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primaryBrown.withOpacity(0.12), shape: BoxShape.circle),
                      child: Image.asset('lib/images/kafelo_logo.png', color: AppColors.primaryBrown),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shop.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                          if (shop.locationLabel.isNotEmpty)
                            Text(shop.locationLabel, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                          if (shop.mallDetails != null)
                            Text(shop.mallDetails!, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (problem != null)
                  _ProblemBox(problem: problem!, routeError: routeError, onRetry: onRetry)
                else ...[
                  if (arrived)
                    const _Note(icon: Icons.check_circle_rounded, color: Color(0xFF2E9E5B), text: "You've arrived at the café.")
                  else if (route != null)
                    Wrap(
                      spacing: 18,
                      runSpacing: 6,
                      children: [
                        _Fact(icon: Icons.route_rounded, text: RouteMath.formatDistance(route.distanceMeters)),
                        if (route.durationSeconds != null)
                          _Fact(icon: Icons.schedule_rounded, text: '${RouteMath.formatDuration(route.durationSeconds!)} ${mode.phrase}'),
                      ],
                    ),
                  if (updatesPaused) ...[
                    const SizedBox(height: 10),
                    const _Note(
                      icon: Icons.wifi_off_rounded,
                      color: Color(0xFFD98A00),
                      text: 'Route updates are temporarily unavailable. Showing your last route.',
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onRecenter,
                          icon: const Icon(Icons.my_location_rounded, size: 18),
                          label: const Text('Recenter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBrown,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onShowAll,
                          icon: const Icon(Icons.zoom_out_map_rounded, size: 18),
                          label: const Text('Show route'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryBrown,
                            minimumSize: const Size.fromHeight(46),
                            side: BorderSide(color: AppColors.primaryBrown.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                const Text(
                  'Map data © OpenStreetMap contributors · Routes by OSRM (FOSSGIS)',
                  style: TextStyle(fontSize: 10, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A Walk / Bike / Car button with that mode's travel time.
class _ModeButton extends StatelessWidget {
  final TravelMode mode;
  final bool selected;
  final String? minutes; // null until that route is known
  final VoidCallback onTap;

  const _ModeButton({required this.mode, required this.selected, required this.minutes, required this.onTap});

  static const _icons = {
    TravelMode.walk: Icons.directions_walk_rounded,
    TravelMode.bike: Icons.directions_bike_rounded,
    TravelMode.car: Icons.directions_car_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.textDark;
    return Semantics(
      button: true,
      selected: selected,
      // One clear label for screen readers, e.g. "Walk, 11 min".
      label: minutes == null ? mode.label : '${mode.label}, $minutes',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primaryBrown : AppColors.inputFill,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_icons[mode], size: 18, color: selected ? Colors.white : AppColors.primaryBrown),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    minutes ?? mode.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProblemBox extends StatelessWidget {
  final _Problem problem;
  final String? routeError;
  final VoidCallback onRetry;

  const _ProblemBox({required this.problem, required this.routeError, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final (message, actionLabel, action) = switch (problem) {
      _Problem.serviceOff => (
          'Location services are turned off. Turn them on to see directions.',
          'Open Location Settings',
          () => Geolocator.openLocationSettings(),
        ),
      _Problem.permission => ('Location permission is required to show directions.', 'Allow Location', onRetry),
      _Problem.permissionForever => (
          'Location permission is required to show directions. Turn it on for Kafelo in your settings.',
          'Open App Settings',
          () => Geolocator.openAppSettings(),
        ),
      _Problem.gps => ('Unable to determine your current location.', 'Try Again', onRetry),
      _Problem.route => (routeError ?? 'Unable to calculate a route right now. Please try again.', 'Try Again', onRetry),
    };
    final showRetryToo = problem == _Problem.serviceOff || problem == _Problem.permissionForever;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Note(icon: Icons.info_outline_rounded, color: const Color(0xFFD64545), text: message),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: action,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBrown,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        if (showRetryToo)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryBrown),
            child: const Text("I've turned it on — try again", style: TextStyle(fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Fact({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryBrown),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark))),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Note({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.35))),
      ],
    );
  }
}

/// "You" — the phone's live position.
class _YouDot extends StatelessWidget {
  const _YouDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF4285F4).withOpacity(0.2)),
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4285F4),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

/// The café's own saved position (it never moves) — the same Kafelo-logo
/// pin as on the main map.
class _CafePin extends StatelessWidget {
  const _CafePin();

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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Image.asset('lib/images/kafelo_logo.png', color: Colors.white),
        ),
        CustomPaint(size: const Size(12, 8), painter: _PinTipPainter()),
      ],
    );
  }
}

class _PinTipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.primaryBrown);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
