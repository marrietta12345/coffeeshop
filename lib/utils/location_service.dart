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

/// Requests location permission (if needed) and returns the device's
/// current GPS position. Shared by every screen that needs the user's
/// real location instead of a hardcoded fallback coordinate.
Future<LocationResult> getCurrentLocation() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult.failure(
        'Location services are turned off. Enable them to see shops near you.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const LocationResult.failure('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult.failure(
        'Location permission is permanently denied. Enable it in your device settings.',
      );
    }

    // On Android, the default fused location provider can hang
    // indefinitely on emulators/AVDs that don't have full Google Play
    // Services support — forceLocationManager routes the request through
    // Android's plain LocationManager instead, which reliably works with
    // the emulator's Extended Controls > Location "Send" feature.
    final LocationSettings locationSettings = (!kIsWeb && Platform.isAndroid)
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            forceLocationManager: true,
            timeLimit: const Duration(seconds: 10),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          );

    final position = await Geolocator.getCurrentPosition(locationSettings: locationSettings)
        .timeout(const Duration(seconds: 12));

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