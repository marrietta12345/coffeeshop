import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';
import 'package:local_based_coffee_shops_mobile_application/models/menu_item.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/cafe_search.dart';

CoffeeShop cafe(
  String name, {
  String address = 'Butuan City',
  String? mall,
  List<String> types = const [],
  List<String> moods = const [],
  List<String> amenities = const [],
  List<String> menu = const [],
  double rating = 4,
}) {
  return CoffeeShop(
    id: name.toLowerCase().replaceAll(' ', '-'),
    name: name,
    description: '',
    address: address,
    openTime: '8 AM',
    closeTime: '8 PM',
    latitude: 0,
    longitude: 0,
    rating: rating,
    category: ShopCategory.coffee,
    mallName: mall,
    coffeeTypes: types,
    atmospheres: moods,
    amenities: amenities,
    menu: [for (final m in menu) MenuItem(name: m, description: '', price: 100)],
  );
}

void main() {
  final shops = [
    cafe('Star Coffee', address: 'J.C. Aquino Ave, Butuan City', types: ['Latte'], moods: ['Cozy'], amenities: ['wifi']),
    cafe('Brew Haven', address: 'Montilla Blvd, Butuan City', mall: 'Gaisano Mall', types: ['Cold Brew'], moods: ['Quiet']),
    cafe('Kapé Kubo', address: 'National Hwy, Butuan City', moods: ['Rustic'], amenities: ['outdoorSeating', 'studyFriendly']),
    cafe('Daily Grind', menu: ['Iced Americano']),
  ];

  List<String> labels(String q) => CafeSearch.suggestions(q, shops).map((s) => s.label).toList();

  group('suggestions', () {
    test('a partial name suggests the café ("star" → Star Coffee)', () {
      final s = CafeSearch.suggestions('star', shops);
      expect(s.first.kind, SuggestionKind.cafe);
      expect(s.first.label, 'Star Coffee');
    });

    test('accents and case are ignored ("kape" → Kapé Kubo)', () {
      expect(labels('KAPE'), contains('Kapé Kubo'));
    });

    test('mall names and locations are suggested with café counts', () {
      final mall = CafeSearch.suggestions('gaisano', shops).single;
      expect(mall.kind, SuggestionKind.location);
      expect(mall.label, 'Gaisano Mall');
      expect(mall.cafeCount, 1);

      final city = CafeSearch.suggestions('butuan', shops).firstWhere((s) => s.kind == SuggestionKind.location);
      expect(city.label, 'Butuan City');
      expect(city.cafeCount, 4);
    });

    test('coffee types, atmospheres and features are suggested', () {
      expect(CafeSearch.suggestions('latte', shops).single.kind, SuggestionKind.coffeeType);
      expect(CafeSearch.suggestions('cozy', shops).single.kind, SuggestionKind.atmosphere);
      final wifi = CafeSearch.suggestions('wifi', shops).single;
      expect(wifi.kind, SuggestionKind.feature);
      expect(wifi.label, 'Wi-Fi');
      expect(CafeSearch.suggestions('outdoor', shops).single.label, 'Outdoor seating');
    });

    test('a coffee type on a menu counts ("americano" → Daily Grind)', () {
      final americano = CafeSearch.suggestions('americano', shops).single;
      expect(americano.kind, SuggestionKind.coffeeType);
      expect(CafeSearch.resultsForSuggestion(americano, shops).single.name, 'Daily Grind');
    });

    test('options no café actually has are not suggested', () {
      expect(labels('espresso'), isEmpty); // nobody serves it
      expect(labels('pet'), isEmpty); // nobody is pet-friendly
    });

    test('empty query gives no suggestions', () {
      expect(labels('  '), isEmpty);
    });
  });

  group('results', () {
    test('picking a suggestion shows the matching cafés', () {
      final quiet = CafeSearch.suggestions('quiet', shops).single;
      expect(CafeSearch.resultsForSuggestion(quiet, shops).map((s) => s.name), ['Brew Haven']);

      final mall = CafeSearch.suggestions('gaisano', shops).single;
      expect(CafeSearch.resultsForSuggestion(mall, shops).map((s) => s.name), ['Brew Haven']);
    });

    test('free-text search finds cafés from partial input across fields', () {
      expect(CafeSearch.search('sta', shops).first.name, 'Star Coffee');
      expect(CafeSearch.search('study', shops).map((s) => s.name), ['Kapé Kubo']);
      expect(CafeSearch.search('montilla', shops).map((s) => s.name), ['Brew Haven']);
    });

    test('name matches outrank other matches', () {
      final both = [
        cafe('Cozy Corner'),
        cafe('Other', moods: ['Cozy'], rating: 5),
      ];
      expect(CafeSearch.search('cozy', both).map((s) => s.name), ['Cozy Corner', 'Other']);
    });

    test('no match returns nothing', () {
      expect(CafeSearch.search('zzzz', shops), isEmpty);
    });
  });
}
