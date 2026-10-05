import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';

CoffeeShop shop({String address = 'A.D. Curato St, Butuan City', String? mall, String? floor, String? unit, String? landmark}) {
  return CoffeeShop(
    id: 'x',
    name: 'Test Café',
    description: '',
    address: address,
    openTime: '8 AM',
    closeTime: '8 PM',
    latitude: 0,
    longitude: 0,
    rating: 4,
    category: ShopCategory.coffee,
    mallName: mall,
    mallFloor: floor,
    mallUnit: unit,
    mallLandmark: landmark,
  );
}

void main() {
  test('café not in a mall shows its address exactly as before', () {
    final s = shop();
    expect(s.isInMall, isFalse);
    expect(s.locationLabel, 'A.D. Curato St, Butuan City');
    expect(s.mallDetails, isNull);
  });

  test('blank mall name counts as not in a mall', () {
    final s = shop(mall: '   ', floor: '2nd Floor');
    expect(s.isInMall, isFalse);
    expect(s.locationLabel, 'A.D. Curato St, Butuan City');
    expect(s.mallDetails, isNull);
  });

  test('café inside a mall shows "Inside <mall>, <city>"', () {
    expect(shop(mall: 'Gaisano Mall').locationLabel, 'Inside Gaisano Mall, Butuan City');
  });

  test('mall label falls back gracefully without a city', () {
    expect(shop(mall: 'Gaisano Mall', address: 'Butuan City').locationLabel, 'Inside Gaisano Mall, Butuan City');
    expect(shop(mall: 'Gaisano Mall', address: '').locationLabel, 'Inside Gaisano Mall');
  });

  test('floor and landmark are shown only when available', () {
    expect(shop(mall: 'Gaisano Mall').mallDetails, isNull);
    expect(shop(mall: 'Gaisano Mall', floor: '2nd Floor').mallDetails, '2nd Floor');
    expect(
      shop(mall: 'Gaisano Mall', floor: '2nd Floor', landmark: 'Near the cinema entrance').mallDetails,
      '2nd Floor · Near the cinema entrance',
    );
  });

  test('a standalone café never shows mall info, even with a leftover mall name', () {
    const s = CoffeeShop(
      id: 'x',
      name: 'Test',
      description: '',
      address: 'A.D. Curato St, Butuan City',
      openTime: '8 AM',
      closeTime: '8 PM',
      latitude: 0,
      longitude: 0,
      rating: 4,
      category: ShopCategory.coffee,
      locationType: 'standalone',
      mallName: 'Gaisano Mall',
      mallFloor: '2nd Floor',
    );
    expect(s.isInMall, isFalse);
    expect(s.locationLabel, 'A.D. Curato St, Butuan City');
    expect(s.mallDetails, isNull);
  });

  test('unit numbers read as "Unit ..." unless they already name the space', () {
    expect(CoffeeShop.formatUnit('204'), 'Unit 204');
    expect(CoffeeShop.formatUnit('Unit 204'), 'Unit 204');
    expect(CoffeeShop.formatUnit('B12'), 'Unit B12');
    expect(CoffeeShop.formatUnit('GF-12'), 'Unit GF-12');
    expect(CoffeeShop.formatUnit('Stall 3B'), 'Stall 3B');
    expect(CoffeeShop.formatUnit('  '), isNull);
  });

  test('details page lines: floor and unit, with the landmark separately', () {
    final s = shop(mall: 'Gaisano Mall Butuan', floor: '2nd Floor', unit: '204', landmark: 'Near the Food Court');
    expect(s.mallFloorAndUnit, '2nd Floor · Unit 204');
    expect(s.mallDetails, '2nd Floor · Unit 204 · Near the Food Court');
    expect(shop(mall: 'Gaisano Mall Butuan', floor: '2nd Floor', landmark: 'Near the Cinema').mallFloorAndUnit, '2nd Floor');
    expect(shop(mall: 'Example Mall', floor: '10th Floor', landmark: 'Near the Main Entrance').mallDetails,
        '10th Floor · Near the Main Entrance');
  });

  test('a standalone café has no floor or unit lines', () {
    expect(shop(floor: '2nd Floor', unit: '204').mallFloorAndUnit, isNull);
  });
}
