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

/// GPS settings used across the app. On Android, the default fused
/// location provider can hang indefinitely on emulators/AVDs that don't
/// have full Google Play Services support — forceLocationManager routes
/// requests through Android's plain LocationManager instead, which
/// reliably works with the emulator's Extended Controls > Location
/// "Send" feature. [distanceFilter] (meters) skips updates for tiny moves.
LocationSettings deviceLocationSettings({Duration? timeLimit, int distanceFilter = 0}) {
  return (!kIsWeb && Platform.isAndroid)
      ? AndroidSettings(
          accuracy: LocationAccuracy.high,
          forceLocationManager: true,
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
  return Geolocator.getPositionStream(locationSettings: deviceLocationSettings(distanceFilter: distanceFilter))
      .map((position) => LatLng(position.latitude, position.longitude));
}

/// Requests location permission (if needed) and returns the device's
/// current GPS position. Shared by every screen that needs the user's
/// real location instead of a hardcoded fallback coordinate.
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

    final position = await Geolocator.getCurrentPosition(
      locationSettings: deviceLocationSettings(timeLimit: const Duration(seconds: 10)),
    ).timeout(const Duration(seconds: 12));

    return LocationResult.success(LatLng(position.latitude, position.longitude));
  } on TimeoutException {
    return const LocationResult.failure(
      "Couldn't get your location in time. On an emulator, open Extended "
      "Controls (⋮) → Location, set a point, and tap Send.",
    );
  } catch (e) {
    return const LocationResult.failure("Couldn't get your current location.");
  }
}
