import 'dart:io' show SocketException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show SemanticsFlag;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/directions_page.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/route_service.dart';

const okBody = '''
{"code":"Ok","routes":[{"distance":1834.6,"duration":412.3,
 "geometry":{"type":"LineString","coordinates":[[125.5400,8.9470],[125.5420,8.9480],[125.5440,8.9500]]}}]}''';

const from = LatLng(8.9470, 125.5400);
const to = LatLng(8.9500, 125.5440);

void main() {
  group('Road route from OSRM', () {
    test('reads the real road path, distance and travel time', () {
      final route = RouteService.parse(okBody);
      expect(route.points.length, 3);
      expect(route.points.first, const LatLng(8.9470, 125.5400)); // [lng, lat] → LatLng(lat, lng)
      expect(route.distanceMeters, 1834.6);
      expect(route.durationSeconds, 412.3);
    });

    test('asks for a route from the user to the café, not a straight line', () async {
      Uri? asked;
      final client = MockClient((request) async {
        asked = request.url;
        return http.Response(okBody, 200);
      });
      await RouteService.fetchRoute(from, to, client: client);
      expect(asked!.host, 'routing.openstreetmap.de');
      // Walking is the default, like Google Maps for nearby places.
      expect(asked!.path, '/routed-foot/route/v1/driving/125.54,8.947;125.544,8.95');
      expect(asked!.queryParameters['geometries'], 'geojson');

      await RouteService.fetchRoute(from, to, mode: TravelMode.bike, client: client);
      expect(asked!.path, startsWith('/routed-bike/'));
      await RouteService.fetchRoute(from, to, mode: TravelMode.car, client: client);
      expect(asked!.path, startsWith('/routed-car/'));
    });

    test('no internet → the connection message', () async {
      final client = MockClient((_) async => throw const SocketException('offline'));
      expect(
        () => RouteService.fetchRoute(from, to, client: client),
        throwsA(isA<RouteException>().having((e) => e.message, 'message', 'An internet connection is required to calculate directions.')),
      );
    });

    test('service error → "Unable to calculate a route right now"', () async {
      final client = MockClient((_) async => http.Response('oops', 503));
      expect(
        () => RouteService.fetchRoute(from, to, client: client),
        throwsA(isA<RouteException>().having((e) => e.message, 'message', 'Unable to calculate a route right now. Please try again.')),
      );
    });

    test('no road between the points → no fake route', () {
      expect(() => RouteService.parse('{"code":"NoRoute","routes":[]}'), throwsA(isA<RouteException>()));
    });
  });

  group('Staying on the route', () {
    final route = [const LatLng(8.9470, 125.5400), const LatLng(8.9470, 125.5500)]; // ~1.1 km east-west road
    final start = DateTime(2026, 10, 5, 12);

    test('distance to the route line', () {
      expect(RouteMath.distanceToRoute(const LatLng(8.9470, 125.5450), route), lessThan(1)); // on it
      // ~111 m north of the road
      expect(RouteMath.distanceToRoute(const LatLng(8.9480, 125.5450), route), closeTo(111, 2));
    });

    test('moving along the route never asks for a new route', () {
      expect(
        RouteMath.shouldRecalculate(position: const LatLng(8.9471, 125.5450), route: route, lastRequestAt: start, now: start.add(const Duration(minutes: 5))),
        isFalse,
      );
    });

    test('going off the route asks for a new one', () {
      expect(
        RouteMath.shouldRecalculate(position: const LatLng(8.9480, 125.5450), route: route, lastRequestAt: start, now: start.add(const Duration(seconds: 30))),
        isTrue,
      );
    });

    test('but never more often than every 20 seconds', () {
      expect(
        RouteMath.shouldRecalculate(position: const LatLng(8.9480, 125.5450), route: route, lastRequestAt: start, now: start.add(const Duration(seconds: 5))),
        isFalse,
      );
    });

    test('distance and time labels', () {
      expect(RouteMath.formatDistance(847), '850 m');
      expect(RouteMath.formatDistance(1834.6), '1.8 km');
      expect(RouteMath.formatDistance(23456), '23 km');
      expect(RouteMath.formatDuration(412), 'Approximately 7 min');
      expect(RouteMath.formatDuration(3900), 'Approximately 1 hr 5 min');
    });
  });

  group('Directions screen', () {
    const shop = CoffeeShop(
      id: 'shop1',
      name: 'Local Brew Café',
      description: '',
      address: 'Butuan City',
      openTime: '',
      closeTime: '',
      latitude: 8.95,
      longitude: 125.54,
      rating: 4.5,
      category: ShopCategory.coffee,
      locationType: 'mall',
      mallName: 'Gaisano Mall Butuan',
      mallFloor: '2nd Floor',
      mallLandmark: 'Near Food Court',
    );
    const channel = MethodChannel('flutter.baseflow.com/geolocator');

    /// Simulates the phone's location system.
    void fakeLocation({required bool serviceOn, int permission = 2}) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'isLocationServiceEnabled':
            return serviceOn;
          case 'checkPermission':
          case 'requestPermission':
            return permission; // 0 denied, 1 denied forever, 2 while in use
        }
        return null;
      });
    }

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(const MaterialApp(home: DirectionsPage(shop: shop)));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('location services off → asks to turn them on, no fake location', (tester) async {
      fakeLocation(serviceOn: false);
      await open(tester);
      expect(find.text('Location services are turned off. Turn them on to see directions.'), findsOneWidget);
      expect(find.text('Open Location Settings'), findsOneWidget);
      expect(find.textContaining('km'), findsNothing); // no made-up distance
      // The café, its mall details and the back button are still there.
      expect(find.text('Local Brew Café'), findsOneWidget);
      expect(find.text('2nd Floor · Near Food Court'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('permission denied → explains and offers to allow it', (tester) async {
      fakeLocation(serviceOn: true, permission: 0);
      await open(tester);
      expect(find.text('Location permission is required to show directions.'), findsOneWidget);
      expect(find.text('Allow Location'), findsOneWidget);
    });

    testWidgets('permission permanently denied → opens app settings', (tester) async {
      fakeLocation(serviceOn: true, permission: 1);
      await open(tester);
      expect(find.text('Open App Settings'), findsOneWidget);
    });

    testWidgets('Walk is selected first; Bike and Car can be chosen (Google Maps style)', (tester) async {
      // A phone with location on, permission given and a recent GPS fix.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'isLocationServiceEnabled':
            return true;
          case 'checkPermission':
          case 'requestPermission':
            return 2;
          case 'getLastKnownPosition':
            return {
              'latitude': 8.9480,
              'longitude': 125.5340,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'accuracy': 10.0,
              'altitude': 0.0,
              'altitude_accuracy': 0.0,
              'heading': 0.0,
              'heading_accuracy': 0.0,
              'speed': 0.0,
              'speed_accuracy': 0.0,
              'is_mocked': false,
            };
        }
        return null;
      });
      final semantics = tester.ensureSemantics();
      await open(tester);
      await tester.pump(const Duration(seconds: 1));

      Finder mode(String label) => find.bySemanticsLabel(RegExp('^$label'));
      bool isSelected(String label) => tester.getSemantics(mode(label)).hasFlag(SemanticsFlag.isSelected);
      expect(mode('Walk'), findsOneWidget);
      expect(mode('Bike'), findsOneWidget);
      expect(mode('Car'), findsOneWidget);
      expect(isSelected('Walk'), isTrue);
      expect(isSelected('Car'), isFalse);

      await tester.tap(mode('Car'));
      await tester.pump(const Duration(seconds: 1));
      expect(isSelected('Car'), isTrue);
      expect(isSelected('Walk'), isFalse);
      semantics.dispose();
    });

    testWidgets('Back returns to the café page', (tester) async {
      fakeLocation(serviceOn: false);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DirectionsPage(shop: shop))),
            child: const Text('café page'),
          ),
        ),
      ));
      await tester.tap(find.text('café page'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('café page'), findsOneWidget);
    });
  });
}
