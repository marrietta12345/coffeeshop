import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Turns a map point into a readable address, and an address into a map
/// point. Phones use their built-in geocoder (the `geocoding` plugin);
/// web browsers have none, so the website asks OpenStreetMap's Nominatim
/// service instead.
class AddressLookup {
  AddressLookup._();

  static const Duration _timeout = Duration(seconds: 8);
  static const String _nominatim = 'nominatim.openstreetmap.org';

  /// "Street, Barangay, City, Province" for [point], or null if unknown.
  static Future<String?> addressFrom(LatLng point, {http.Client? client}) async {
    if (!kIsWeb && client == null) {
      final placemarks = await placemarkFromCoordinates(point.latitude, point.longitude).timeout(_timeout);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      return joinParts([p.street, p.subLocality, p.locality, p.administrativeArea]);
    }
    final uri = Uri.https(_nominatim, '/reverse', {
      'lat': '${point.latitude}',
      'lon': '${point.longitude}',
      'format': 'jsonv2',
      'addressdetails': '1',
      'accept-language': 'en',
    });
    final res = await (client ?? http.Client()).get(uri).timeout(_timeout);
    if (res.statusCode != 200) return null;
    return parseReverse(res.body);
  }

  /// The map point of a typed [address], or null if it wasn't found.
  static Future<LatLng?> pointFrom(String address, {http.Client? client}) async {
    if (!kIsWeb && client == null) {
      final found = await locationFromAddress(address).timeout(_timeout);
      return found.isEmpty ? null : LatLng(found.first.latitude, found.first.longitude);
    }
    final uri = Uri.https(_nominatim, '/search', {
      'q': address,
      'format': 'jsonv2',
      'limit': '1',
      'countrycodes': 'ph',
      'viewbox': '125.40,9.05,125.70,8.80', // prefer results around Butuan City
    });
    final res = await (client ?? http.Client()).get(uri).timeout(_timeout);
    if (res.statusCode != 200) return null;
    final list = jsonDecode(res.body);
    if (list is! List || list.isEmpty) return null;
    final lat = double.tryParse('${list.first['lat']}');
    final lon = double.tryParse('${list.first['lon']}');
    return (lat == null || lon == null) ? null : LatLng(lat, lon);
  }

  /// Reads a Nominatim reverse result in the same order the phone uses:
  /// street, barangay, city, province.
  static String? parseReverse(String body) {
    final data = jsonDecode(body);
    if (data is! Map || data['address'] is! Map) return null;
    final a = data['address'] as Map;
    String? first(List<String> keys) {
      for (final k in keys) {
        final v = a[k];
        if (v is String && v.trim().isNotEmpty) return v;
      }
      return null;
    }

    final road = first(['road', 'pedestrian', 'street']);
    final number = first(['house_number']);
    final street = road == null ? null : (number == null ? road : '$number $road');
    return joinParts([
      street,
      first(['suburb', 'village', 'neighbourhood', 'quarter', 'hamlet']),
      first(['city', 'town', 'municipality']),
      first(['state', 'province', 'region']),
    ]);
  }

  static String? joinParts(List<String?> parts) {
    final kept = parts.where((p) => p != null && p.trim().isNotEmpty).cast<String>().toList();
    return kept.isEmpty ? null : kept.join(', ');
  }
}
