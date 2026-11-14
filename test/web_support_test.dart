import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/address_lookup.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/picked_image.dart';

void main() {
  group('Picked photos (work on phones and the web)', () {
    test('keeps the photo as bytes with a preview', () {
      final photo = PickedImage(Uint8List.fromList([1, 2, 3]));
      expect(photo.bytes, [1, 2, 3]);
      expect(photo.provider, isA<MemoryImage>());
      expect(identical(photo.provider, photo.provider), isTrue); // one preview, not a new one per build
    });

    test('uploads with the right image type', () {
      expect(PickedImage.contentTypeOf('image/png', 'x'), 'image/png');
      expect(PickedImage.contentTypeOf(null, 'cafe.PNG'), 'image/png');
      expect(PickedImage.contentTypeOf(null, 'cafe.webp'), 'image/webp');
      expect(PickedImage.contentTypeOf('', 'cafe.jpg'), 'image/jpeg');
      expect(PickedImage.contentTypeOf('application/octet-stream', 'blob'), 'image/jpeg');
    });
  });

  group('Address lookup on the website (OpenStreetMap)', () {
    const reverse = '''
{"address":{"house_number":"12","road":"J.C. Aquino Avenue","suburb":"Libertad",
 "city":"Butuan City","state":"Agusan del Norte","country":"Philippines"}}''';

    test('reads street, barangay, city and province like the phone does', () {
      expect(AddressLookup.parseReverse(reverse), '12 J.C. Aquino Avenue, Libertad, Butuan City, Agusan del Norte');
      expect(AddressLookup.parseReverse('{"address":{"village":"Ampayon","city":"Butuan City"}}'), 'Ampayon, Butuan City');
      expect(AddressLookup.parseReverse('{"error":"Unable to geocode"}'), isNull);
    });

    test('map pin → address', () async {
      Uri? asked;
      final client = MockClient((r) async {
        asked = r.url;
        return http.Response(reverse, 200);
      });
      final address = await AddressLookup.addressFrom(const LatLng(8.95, 125.54), client: client);
      expect(asked!.host, 'nominatim.openstreetmap.org');
      expect(asked!.path, '/reverse');
      expect(address, startsWith('12 J.C. Aquino Avenue'));
    });

    test('typed address → map point, near Butuan', () async {
      Uri? asked;
      final client = MockClient((r) async {
        asked = r.url;
        return http.Response('[{"lat":"8.9475","lon":"125.5406"}]', 200);
      });
      final point = await AddressLookup.pointFrom('Robinsons Place Butuan', client: client);
      expect(asked!.path, '/search');
      expect(asked!.queryParameters['countrycodes'], 'ph');
      expect(point, const LatLng(8.9475, 125.5406));
    });

    test('nothing found or service down → no made-up location', () async {
      expect(await AddressLookup.pointFrom('nowhere', client: MockClient((_) async => http.Response('[]', 200))), isNull);
      expect(await AddressLookup.addressFrom(const LatLng(0, 0), client: MockClient((_) async => http.Response('', 503))), isNull);
    });
  });
}
