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
      expect(mall.kind, SuggestionKind.mall);
      expect(mall.label, 'Gaisano Mall');
      expect(mall.cafeCount, 1);
    });

    test('the city itself is never suggested (every café is in Butuan)', () {
      expect(CafeSearch.suggestions('butuan', shops).where((s) => s.isPlace), isEmpty);
    });

    test('places match from the start of a word ("b" → Bayanihan, not Montalban)', () {
      final area = [
        cafe('One', address: 'Montalban St., Villa Kananga, Butuan City'),
        cafe('Two', address: 'DAR Subdivision, Bayanihan, Butuan City'),
      ];
      final places = CafeSearch.suggestions('b', area).where((s) => s.isPlace).map((s) => s.label).toList();
      expect(places, ['Bayanihan']);
    });

    test('neighborhood names are cleaned and merged', () {
      final area = [
        cafe('One', address: 'Pili Drive St. corner Ipil Road, Brgy. Dagohoy (near TESDA), Butuan City'),
        cafe('Two', address: '721 Molave St., Brgy. Dagohoy, Butuan City'),
        cafe('Three', address: 'Purok 4, Imadejas Pob. (Bgy. 24), Butuan City'),
      ];
      final dagohoy = CafeSearch.suggestions('dago', area).single;
      expect(dagohoy.label, 'Dagohoy'); // "Brgy." dropped, both cafés counted
      expect(dagohoy.cafeCount, 2);
      expect(CafeSearch.suggestions('imad', area).single.label, 'Imadejas'); // "Pob. (Bgy. 24)" dropped
      expect(CafeSearch.suggestions('purok', area), isEmpty); // not a place people search
      expect(CafeSearch.suggestions('molave', area).single.label, 'Molave St.'); // house number dropped
    });

    test('landmarks in addresses become "Near …" places', () {
      final area = [
        cafe('One', address: 'San Francisco St. (near FSUU), Butuan City'),
        cafe('Two', address: 'Inside Caraga State University (CSU), Ampayon, Butuan City'),
        cafe('Three', address: 'Rosewood Subdivision (near the entrance gate), Butuan City'),
      ];
      final fsuu = CafeSearch.suggestions('fs', area).single;
      expect(fsuu.kind, SuggestionKind.landmark);
      expect(fsuu.label, 'Near FSUU');
      expect(CafeSearch.resultsForSuggestion(fsuu, area).single.name, 'One');
      expect(CafeSearch.suggestions('csu', area).single.label, 'Inside Caraga State University (CSU)');
      expect(CafeSearch.suggestions('entrance', area), isEmpty); // not a named place
    });

    test('a place suggestion carries its cafés (for the map)', () {
      final area = [
        cafe('One', address: 'Elloso St., Imadejas, Butuan City'),
        cafe('Two', address: 'Montalban St., Imadejas, Butuan City'),
        cafe('Three', address: 'Ochoa Avenue, Butuan City'),
      ];
      final imadejas = CafeSearch.suggestions('imadejas', area).single;
      expect(imadejas.shops.map((s) => s.name), ['One', 'Two']);
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

  group('typed letters to bold', () {
    test('marks where the query starts a word', () {
      expect(CafeSearch.matchRange('Bayanihan', 'ba'), (0, 2));
      expect(CafeSearch.matchRange('Near FSUU', 'fs'), (5, 7));
      expect(CafeSearch.matchRange('J.C. Aquino Ave.', 'jcaq'), (0, 7));
      expect(CafeSearch.matchRange('Kapé Kubo', 'kape'), (0, 4));
      expect(CafeSearch.matchRange('Montalban St.', 'b'), isNull);
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
