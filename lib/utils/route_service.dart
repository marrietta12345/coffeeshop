import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// How the customer is travelling — like the mode buttons in Google Maps.
enum TravelMode {
  walk('foot', 'Walk', 'walk'),
  bike('bike', 'Bike', 'by bike'),
  car('car', 'Car', 'by car');

  final String profile; // routing.openstreetmap.de profile
  final String label;
  final String phrase; // "Approximately 11 min walk" / "… by bike"

  const TravelMode(this.profile, this.label, this.phrase);
}

/// A road route from OSRM: the path to draw, and the route's own distance
/// and travel time.
class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double? durationSeconds; // null when the service gives no ETA

  const RouteResult({required this.points, required this.distanceMeters, this.durationSeconds});
}

enum RouteFailure {
  offline, // no internet connection
  noRoute, // no road route between the two points
  failed, // the routing service errored or timed out
}

class RouteException implements Exception {
  final RouteFailure kind;

  const RouteException(this.kind);

  String get message => switch (kind) {
        RouteFailure.offline => 'An internet connection is required to calculate directions.',
        RouteFailure.noRoute => "There's no road route to this café from where you are.",
        RouteFailure.failed => 'Unable to calculate a route right now. Please try again.',
      };

  @override
  String toString() => 'RouteException($kind)';
}

/// Walking, cycling and driving routes over OpenStreetMap data, from the
/// OSRM servers run by FOSSGIS (routing.openstreetmap.de — free, no key,
/// fair use). Only the start and end points are sent, and nothing is
/// stored.
class RouteService {
  RouteService._();

  static Uri routeUrl(LatLng from, LatLng to, TravelMode mode) => Uri.parse(
        'https://routing.openstreetmap.de/routed-${mode.profile}/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=geojson',
      );

  static Future<RouteResult> fetchRoute(LatLng from, LatLng to, {TravelMode mode = TravelMode.walk, http.Client? client}) async {
    final url = routeUrl(from, to, mode);
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(url, headers: const {'User-Agent': 'Kafelo/1.0 (coffee shop discovery app)'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        // OSRM answers 400 with code "NoRoute" when the points can't be joined.
        if (response.body.contains('"NoRoute"') || response.body.contains('"NoSegment"')) {
          throw const RouteException(RouteFailure.noRoute);
        }
        throw const RouteException(RouteFailure.failed);
      }
      return parse(response.body);
    } on RouteException {
      rethrow;
    } on SocketException {
      throw const RouteException(RouteFailure.offline);
    } on http.ClientException {
      throw const RouteException(RouteFailure.offline);
    } on TimeoutException {
      throw const RouteException(RouteFailure.failed);
    } on FormatException {
      throw const RouteException(RouteFailure.failed);
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Reads an OSRM /route response (GeoJSON geometry).
  static RouteResult parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final code = json['code'] as String?;
    final routes = json['routes'] as List?;
    if (code == 'NoRoute' || code == 'NoSegment' || routes == null || routes.isEmpty) {
      throw const RouteException(RouteFailure.noRoute);
    }
    if (code != 'Ok') throw const RouteException(RouteFailure.failed);
    final route = routes.first as Map<String, dynamic>;
    final coordinates = (route['geometry'] as Map<String, dynamic>)['coordinates'] as List;
    final points = [
      for (final c in coordinates) LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
    ];
    if (points.length < 2) throw const RouteException(RouteFailure.noRoute);
    return RouteResult(
      points: points,
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num?)?.toDouble(),
    );
  }
}

/// Route checks used while the user moves.
class RouteMath {
  RouteMath._();

  /// Further than this from the drawn route counts as "off the route".
  static const double offRouteMeters = 50;

  /// Never ask for a new route more often than this.
  static const Duration minRecalcInterval = Duration(seconds: 20);

  /// Within this of the café counts as arrived.
  static const double arrivedMeters = 40;

  /// Shortest distance in meters from [p] to the [route] line.
  static double distanceToRoute(LatLng p, List<LatLng> route) {
    if (route.isEmpty) return double.infinity;
    if (route.length == 1) return const Distance().as(LengthUnit.Meter, p, route.first);
    // Flat x/y in meters around p — accurate at these short distances.
    const metersPerDegree = 111320.0;
    final cosLat = math.cos(p.latitudeInRad);
    double x(LatLng q) => (q.longitude - p.longitude) * metersPerDegree * cosLat;
    double y(LatLng q) => (q.latitude - p.latitude) * metersPerDegree;
    var best = double.infinity;
    for (var i = 0; i < route.length - 1; i++) {
      final ax = x(route[i]), ay = y(route[i]);
      final bx = x(route[i + 1]), by = y(route[i + 1]);
      final dx = bx - ax, dy = by - ay;
      final lengthSq = dx * dx + dy * dy;
      // Closest point on segment AB to p (the origin).
      final t = lengthSq == 0 ? 0.0 : (-(ax * dx + ay * dy) / lengthSq).clamp(0.0, 1.0);
      final cx = ax + t * dx, cy = ay + t * dy;
      best = math.min(best, math.sqrt(cx * cx + cy * cy));
    }
    return best;
  }

  /// Whether to request a new route now: only when the user has moved
  /// off the current route (or there's none yet) and the last request
  /// wasn't too recent — GPS updates alone never trigger it.
  static bool shouldRecalculate({
    required LatLng position,
    required List<LatLng>? route,
    required DateTime? lastRequestAt,
    required DateTime now,
  }) {
    if (lastRequestAt != null && now.difference(lastRequestAt) < minRecalcInterval) return false;
    if (route == null || route.isEmpty) return true;
    return distanceToRoute(position, route) > offRouteMeters;
  }

  /// "850 m" / "1.8 km" / "12 km".
  static String formatDistance(double meters) {
    if (meters < 1000) return '${(meters / 10).round() * 10} m';
    final km = meters / 1000;
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  /// "7 min" / "1 hr 5 min" — the time on a travel-mode button.
  static String shortDuration(double seconds) {
    final minutes = math.max(1, (seconds / 60).round());
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return '$hours hr${rest == 0 ? '' : ' $rest min'}';
  }

  /// "Approximately 7 min" / "Approximately 1 hr 5 min".
  static String formatDuration(double seconds) => 'Approximately ${shortDuration(seconds)}';
}
