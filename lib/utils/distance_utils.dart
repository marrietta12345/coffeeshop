import 'package:latlong2/latlong.dart';

const _distanceCalculator = Distance();

/// "0.4 km away" style label between two coordinates. Falls back to
/// meters under 1km for readability. Empty when [to] is a café whose
/// location isn't set yet (0, 0).
String formatDistance(LatLng from, LatLng to) {
  if (to.latitude == 0 && to.longitude == 0) return '';
  final meters = _distanceCalculator.as(LengthUnit.Meter, from, to);
  if (meters < 1000) {
    return '${meters.round()} m away';
  }
  final km = meters / 1000;
  return '${km.toStringAsFixed(1)} km away';
}