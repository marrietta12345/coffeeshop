import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
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
/// hasn't been decided yet.
Future<LocationAccess> ensureLocationAccess() async {
  if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceOff;
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
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
LocationSettings deviceLocationSettings({Duration? timeLimit, int distanceFilter = 0, bool useLocationManager = true}) {
  return (!kIsWeb && Platform.isAndroid)
      ? AndroidSettings(
          accuracy: LocationAccuracy.high,
          forceLocationManager: useLocationManager,
          distanceFilter: distanceFilter,
          timeLimit: timeLimit,
        )
      : LocationSettings(
          accuracy: LocationAccuracy.high,
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
/// Fast on real phones: uses the phone's recent last-known position if it
/// has one, otherwise Google's fused location service (Wi-Fi / cell / GPS
/// — works indoors), and only then falls back to GPS-only LocationManager
/// (needed on some emulators).
Future<LocationResult> getCurrentLocation() async {
  try {
    switch (await ensureLocationAccess()) {
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

    // 1. The phone's own recent position — instant.
    Position? lastKnown;
    try {
      lastKnown = await Geolocator.getLastKnownPosition().timeout(const Duration(seconds: 3));
    } catch (_) {
      lastKnown = null;
    }
    if (lastKnown != null && DateTime.now().difference(lastKnown.timestamp).abs() < _recentEnough) {
      return LocationResult.success(LatLng(lastKnown.latitude, lastKnown.longitude));
    }

    // 2. A fresh fix: the fast fused service first, then GPS-only.
    for (final useLocationManager in (!kIsWeb && Platform.isAndroid) ? const [false, true] : const [false]) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: deviceLocationSettings(timeLimit: const Duration(seconds: 10), useLocationManager: useLocationManager),
        ).timeout(const Duration(seconds: 12));
        return LocationResult.success(LatLng(position.latitude, position.longitude));
      } catch (_) {
        // try the next way
      }
    }

    // 3. Nothing fresh — an older known position is still the real one.
    if (lastKnown != null) {
      return LocationResult.success(LatLng(lastKnown.latitude, lastKnown.longitude));
    }
    throw TimeoutException('No location fix');
  } on TimeoutException {
    return const LocationResult.failure(
      "Couldn't get your location yet. Try again near a window or outdoors. "
      "On an emulator, open Extended Controls (⋮) → Location and tap Send.",
    );
  } catch (e) {
    return const LocationResult.failure("Couldn't get your current location.");
  }
}
