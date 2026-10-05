import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

/// Result of a location lookup — either a real GPS fix, or a reason it
/// couldn't be obtained (so callers can show an accurate message instead
/// of silently falling back).
class LocationResult {
  final LatLng? position;
  final String? errorMessage;

  const LocationResult.success(LatLng position)
      : position = position,
        errorMessage = null;

  const LocationResult.failure(String errorMessage)
      : position = null,
        errorMessage = errorMessage;

  bool get isSuccess => position != null;
}

/// Whether the app can use the phone's location right now.
enum LocationAccess { ready, serviceOff, denied, deniedForever }

/// Checks location services and permission, asking for permission if it
/// hasn't been decided yet. Screens that ask at the same time (the Map and
/// Explore tabs both load at startup) share ONE request — Android only
/// shows one permission prompt and drops a second request, which would
/// otherwise never get an answer.
Future<LocationAccess> ensureLocationAccess() {
  return _accessInFlight ??= _checkAccess().whenComplete(() => _accessInFlight = null);
}

Future<LocationAccess>? _accessInFlight;

Future<LocationAccess> _checkAccess() async {
  const quick = Duration(seconds: 8);
  if (!await Geolocator.isLocationServiceEnabled().timeout(quick)) return LocationAccess.serviceOff;
  var permission = await Geolocator.checkPermission().timeout(quick);
  if (permission == LocationPermission.denied) {
    // The person answers the permission prompt — give them time.
    permission = await Geolocator.requestPermission().timeout(const Duration(minutes: 2));
  }
  if (permission == LocationPermission.denied) return LocationAccess.denied;
  if (permission == LocationPermission.deniedForever) return LocationAccess.deniedForever;
  return LocationAccess.ready;
}

/// GPS settings used across the app. [useLocationManager] (Android)
/// routes requests through Android's plain LocationManager instead of
/// Google's fused location service: the fused service is fast and works
/// indoors on real phones, but can hang on emulators without full Google
/// Play Services, where LocationManager works with the emulator's
/// Extended Controls > Location "Send". [distanceFilter] (meters) skips
/// updates for tiny moves.
LocationSettings deviceLocationSettings({
  Duration? timeLimit,
  int distanceFilter = 0,
  bool useLocationManager = true,
  LocationAccuracy accuracy = LocationAccuracy.high,
}) {
  return (!kIsWeb && Platform.isAndroid)
      ? AndroidSettings(
          accuracy: accuracy,
          forceLocationManager: useLocationManager,
          distanceFilter: distanceFilter,
          timeLimit: timeLimit,
        )
      : LocationSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
          timeLimit: timeLimit,
        );
}

/// Live position updates while listened to — every [distanceFilter]
/// meters of movement, not on every tiny GPS jitter. Cancel the
/// subscription to stop tracking.
Stream<LatLng> watchLocation({int distanceFilter = 10}) {
  return Geolocator.getPositionStream(
    locationSettings: deviceLocationSettings(distanceFilter: distanceFilter, useLocationManager: false),
  )
      .map((position) => LatLng(position.latitude, position.longitude));
}

/// A position the phone already knows that's recent enough to use right
/// away (it's refreshed by a live fix afterwards where that matters).
const Duration _recentEnough = Duration(minutes: 5);

/// Requests location permission (if needed) and returns the device's
/// current GPS position. Shared by every screen that needs the user's
/// real location instead of a hardcoded fallback coordinate.
///
/// Fast on real phones, indoors too. Tries, in order:
///  1. a recent position the phone already knows (instant);
///  2. Google's fused location service (Wi-Fi / cell / GPS);
///  3. Android's network location (Wi-Fi / cell — no Google Play needed);
///  4. GPS only (slow indoors; needed on some emulators).
/// Each step logs to the console ("Kafelo location: …") for diagnosis.
Future<LocationResult> getCurrentLocation() {
  // Callers at the same moment share one lookup (and one permission prompt).
  return _locationInFlight ??= _lookUpLocation().whenComplete(() => _locationInFlight = null);
}

Future<LocationResult>? _locationInFlight;

Future<LocationResult> _lookUpLocation() async {
  final watch = Stopwatch()..start();
  void log(String message) => debugPrint('Kafelo location [${watch.elapsedMilliseconds} ms]: $message');
  try {
    final access = await ensureLocationAccess();
    log('access = ${access.name}');
    switch (access) {
      case LocationAccess.serviceOff:
        return const LocationResult.failure(
          'Location services are turned off. Enable them to see shops near you.',
        );
      case LocationAccess.denied:
        return const LocationResult.failure('Location permission was denied.');
      case LocationAccess.deniedForever:
        return const LocationResult.failure(
          'Location permission is permanently denied. Enable it in your device settings.',
        );
      case LocationAccess.ready:
        break;
    }

    final android = !kIsWeb && Platform.isAndroid;

    // 1. A position the phone already knows (fused, then Android's own).
    Position? lastKnown;
    for (final useLocationManager in android ? const [false, true] : const [false]) {
      try {
        lastKnown ??= await Geolocator.getLastKnownPosition(forceAndroidLocationManager: useLocationManager)
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        log('last known (${useLocationManager ? 'Android' : 'fused'}) failed: $e');
      }
    }
    log('last known = ${lastKnown == null ? 'none' : '${lastKnown.timestamp}'}');
    if (lastKnown != null && DateTime.now().difference(lastKnown.timestamp).abs() < _recentEnough) {
      return LocationResult.success(LatLng(lastKnown.latitude, lastKnown.longitude));
    }

    // 2–4. A fresh fix, fastest way first.
    final attempts = <(String, bool, LocationAccuracy, int)>[
      ('fused', false, LocationAccuracy.medium, 8),
      if (android) ('network', true, LocationAccuracy.low, 8),
      if (android) ('gps', true, LocationAccuracy.high, 12),
    ];
    for (final (name, useLocationManager, accuracy, seconds) in attempts) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: deviceLocationSettings(
            timeLimit: Duration(seconds: seconds),
            useLocationManager: useLocationManager,
            accuracy: accuracy,
          ),
        ).timeout(Duration(seconds: seconds + 2));
        log('$name fix found');
        return LocationResult.success(LatLng(position.latitude, position.longitude));
      } catch (e) {
        log('$name failed: $e');
      }
    }

    // 3. Nothing fresh — an older known position is still the real one.
    if (lastKnown != null) {
      return LocationResult.success(LatLng(lastKnown.latitude, lastKnown.longitude));
    }
    throw TimeoutException('No location fix');
  } on TimeoutException catch (e) {
    log('gave up: $e');
    return const LocationResult.failure(
      "Couldn't get your location yet. Try again near a window or outdoors. "
      "On an emulator, open Extended Controls (⋮) → Location and tap Send.",
    );
  } catch (e) {
    log('error: $e');
    return const LocationResult.failure("Couldn't get your current location.");
  }
}
