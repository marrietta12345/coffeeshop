import 'package:latlong2/latlong.dart';

const _distanceCalculator = Distance();

/// "0.4 km away" style label between two coordinates. Falls back to
/// meters under 1km for readability.
String formatDistance(LatLng from, LatLng to) {
  final meters = _distanceCalculator.as(LengthUnit.Meter, from, to);
  if (meters < 1000) {
    return '${meters.round()} m away';
  }
  final km = meters / 1000;
  return '${km.toStringAsFixed(1)} km away';
}