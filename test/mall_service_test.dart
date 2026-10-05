import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/cafe_search.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/mall_service.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/map_pin_spread.dart';

CoffeeShop cafe(String id, {double lat = 8.95, double lng = 125.54, String? mall, String? floor, String? landmark}) => CoffeeShop(
      id: id,
      name: id,
      description: '',
      address: 'Butuan City',
      openTime: '',
      closeTime: '',
      latitude: lat,
      longitude: lng,
      rating: 4,
      category: ShopCategory.coffee,
      locationType: mall == null ? 'standalone' : 'mall',
      mallName: mall,
      mallFloor: floor,
      mallLandmark: landmark,
    );

void main() {
  group('No duplicate malls', () {
    test('different spellings of the same mall share one key', () {
      final key = MallService.mallKey('Gaisano Mall Butuan');
      expect(key, 'gaisano-mall-butuan');
      expect(MallService.mallKey('gaisano mall butuan'), key);
      expect(MallService.mallKey('Gaisano Mall - Butuan'), key);
      expect(MallService.mallKey('  Gaisano   Mall, Butuan '), key);
    });

    test('mall search ignores case and punctuation, starts-with first', () {
      const malls = ['Robinsons Place Butuan', 'Gaisano Mall Butuan', 'CityMall Butuan'];
      expect(MallService.suggestions(malls, 'gaisano'), ['Gaisano Mall Butuan']);
      expect(MallService.suggestions(malls, 'butuan').length, 3);
      expect(MallService.suggestions(malls, 'city').first, 'CityMall Butuan');
    });
  });

  group('Floor level', () {
    test('saved floors map back to a recommended option or Other', () {
      expect(MallFloor.choiceFor('2nd Floor'), '2nd Floor');
      expect(MallFloor.choiceFor('ground floor'), 'Ground Floor');
      expect(MallFloor.choiceFor('10th Floor'), MallFloor.other);
      expect(MallFloor.choiceFor('Mezzanine'), MallFloor.other);
      expect(MallFloor.choiceFor(null), isNull);
    });
  });

  group('Search by mall and floor', () {
    final shops = [
      cafe('Local Brew', mall: 'Gaisano Mall Butuan', floor: '2nd Floor', landmark: 'Near Food Court'),
      cafe('Coffee Corner', mall: 'Gaisano Mall Butuan', floor: '2nd Floor', landmark: 'Near Cinema'),
      cafe('Bean House', mall: 'Gaisano Mall Butuan', floor: '3rd Floor'),
      cafe('Street Cup'),
    ];

    test('mall name finds every café inside it, as separate cafés', () {
      final results = CafeSearch.search('Gaisano', shops).map((s) => s.id).toList();
      expect(results, containsAll(['Local Brew', 'Coffee Corner', 'Bean House']));
      expect(results, isNot(contains('Street Cup')));
    });

    test('"2nd floor" finds only cafés on that floor', () {
      expect(CafeSearch.search('2nd floor', shops).map((s) => s.id).toSet(), {'Local Brew', 'Coffee Corner'});
    });

    test('landmarks are searchable', () {
      expect(CafeSearch.search('cinema', shops).map((s) => s.id), ['Coffee Corner']);
    });
  });

  group('Map pins', () {
    test('a café alone at its spot is not moved', () {
      final offsets = MapPinSpread.offsets([cafe('a'), cafe('b', lat: 8.96)]);
      expect(offsets.values.every((o) => o.dx == 0 && o.dy == 0), isTrue);
    });

    test('cafés at the same mall spot are drawn apart, each with its own pin', () {
      final offsets = MapPinSpread.offsets([cafe('a'), cafe('b'), cafe('c', lat: 8.95001)]);
      expect(offsets.length, 3);
      expect(offsets.values.toSet().length, 3); // all different
      expect(offsets.values.map((o) => o.dx).reduce((a, b) => a + b), closeTo(0, 0.001)); // centered
    });

    test('big groups wrap into rows above the spot', () {
      final offsets = MapPinSpread.offsets([for (var i = 0; i < 6; i++) cafe('c$i')]);
      expect(offsets.values.toSet().length, 6);
      expect(offsets.values.where((o) => o.dy < 0).length, 2);
    });
  });
}
