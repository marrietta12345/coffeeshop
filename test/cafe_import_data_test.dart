import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_preferences.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';
import 'package:local_based_coffee_shops_mobile_application/models/menu_item.dart';
import 'package:local_based_coffee_shops_mobile_application/models/operating_hours.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/distance_utils.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/shop_mini_card.dart';

CoffeeShop _shop({double lat = 0, double lng = 0}) => CoffeeShop(
      id: 'kaffee-antonio', name: 'Kaffee Antonio', description: '', address: 'Pili Drive, Brgy. Dagohoy, Butuan City',
      openTime: '', closeTime: '', latitude: lat, longitude: lng, rating: 0, category: ShopCategory.coffee,
    );

void main() {
  group('tool/cafes/cafes.json', () {
    final data = jsonDecode(File('tool/cafes/cafes.json').readAsStringSync()) as Map<String, dynamic>;
    final cafes = (data['cafes'] as List).cast<Map<String, dynamic>>();

    test('20 cafés with unique ids and a Facebook page', () {
      expect(cafes.length, 20);
      expect(cafes.map((c) => c['id']).toSet().length, cafes.length);
      expect(cafes.every((c) => (c['facebookUrl'] as String).startsWith('https://www.facebook.com/')), isTrue);
      expect(cafes.every((c) => (c['address'] as String).isNotEmpty), isTrue);
    });

    test('uses the same options as the app (Café Features, hours, menu categories)', () {
      for (final cafe in cafes) {
        for (final t in cafe['coffeeTypes'] as List) {
          expect(CoffeePreferences.coffeeTypeOptions, contains(t));
        }
        for (final a in cafe['atmospheres'] as List) {
          expect(CoffeePreferences.atmosphereOptions, contains(a));
        }
        for (final a in cafe['amenities'] as List) {
          expect(CoffeePreferences.amenityLabels.keys, contains(a));
        }
        for (final day in (cafe['hours'] as Map).keys) {
          expect(OperatingHours.dayKeys.values, contains(day));
        }
        for (final item in (cafe['menu'] as List).cast<Map<String, dynamic>>()) {
          expect(CoffeeCategory.all, contains(item['category']));
          if (item['price'] != null) expect(item['price'], greaterThan(0)); // null = no price yet
        }
      }
    });
  });

  group('Cafés without a map location yet', () {
    test('have no location and no distance', () {
      expect(_shop().hasLocation, isFalse);
      expect(_shop(lat: 8.95, lng: 125.54).hasLocation, isTrue);
      expect(formatDistance(const LatLng(8.95, 125.54), const LatLng(0, 0)), '');
      expect(formatDistance(const LatLng(8.95, 125.54), const LatLng(8.95, 125.54)), '0 m away');
    });

    testWidgets('card shows the address but no distance', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(height: 260, child: ShopMiniCard(shop: _shop(), distanceLabel: '', onTap: () {})))),
      ));
      expect(find.text('Kaffee Antonio'), findsOneWidget);
      expect(find.text('Pili Drive, Brgy. Dagohoy, Butuan City'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });
  });
}
