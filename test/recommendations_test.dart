import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_preferences.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';
import 'package:local_based_coffee_shops_mobile_application/models/menu_item.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/recommendations.dart';

CoffeeShop cafe(
  String name, {
  List<String> types = const [],
  List<String> moods = const [],
  List<String> amenities = const [],
  List<String> menu = const [],
  double rating = 4,
}) {
  return CoffeeShop(
    id: name,
    name: name,
    description: '',
    address: '',
    openTime: '8 AM',
    closeTime: '8 PM',
    latitude: 0,
    longitude: 0,
    rating: rating,
    category: ShopCategory.coffee,
    coffeeTypes: types,
    atmospheres: moods,
    amenities: amenities,
    menu: [for (final m in menu) MenuItem(name: m, description: '', price: 100)],
  );
}

void main() {
  // The example from the brief: Latte + Cozy + Quiet + Study-friendly + Wi-Fi.
  const prefs = CoffeePreferences(
    coffeeTypes: {'Latte'},
    atmospheres: {'Cozy', 'Quiet'},
    studyFriendly: true,
    wifi: true,
  );

  test('cafés matching the most preferences come first', () {
    final perfect = cafe('Perfect', types: ['Latte'], moods: ['Cozy', 'Quiet'], amenities: ['studyFriendly', 'wifi']);
    final partial = cafe('Partial', types: ['Latte'], moods: ['Lively'], amenities: ['wifi']);
    final one = cafe('One', moods: ['Cozy']);

    final ranked = recommendCafes(prefs, [one, partial, perfect]);
    expect(ranked.map((r) => r.shop.name), ['Perfect', 'Partial', 'One']);
    expect(ranked.first.matched, ['Latte', 'Cozy', 'Quiet', 'Study-friendly', 'Wi-Fi']);
    expect(ranked[1].score, 2);
  });

  test('cafés that match nothing are not recommended', () {
    final none = cafe('Nope', types: ['Americano'], moods: ['Lively'], amenities: ['petFriendly']);
    expect(recommendCafes(prefs, [none]), isEmpty);
  });

  test('no preferences selected means no personalized recommendations', () {
    final good = cafe('Good', types: ['Latte'], moods: ['Cozy']);
    expect(recommendCafes(const CoffeePreferences(), [good]), isEmpty);
  });

  test('a coffee type on the menu counts even if not listed as a feature', () {
    final menuOnly = cafe('Menu', menu: ['Hazelnut Latte']);
    final ranked = recommendCafes(const CoffeePreferences(coffeeTypes: {'Latte'}), [menuOnly]);
    expect(ranked.single.matched, ['Latte']);
  });

  test('spelling differences like "Pour Over" vs "Pour-over" still match', () {
    final s = cafe('Drip', types: ['Pour Over'], moods: ['minimalist']);
    final ranked = recommendCafes(const CoffeePreferences(coffeeTypes: {'Pour-over'}, atmospheres: {'Minimalist'}), [s]);
    expect(ranked.single.score, 2);
  });

  test('"Non-coffee" only matches cafés that list it, not menu names', () {
    final menuOnly = cafe('Tea Spot', menu: ['Non-coffee Matcha']);
    final listed = cafe('Listed', types: ['Non-coffee']);
    final ranked = recommendCafes(const CoffeePreferences(coffeeTypes: {'Non-coffee'}), [menuOnly, listed]);
    expect(ranked.map((r) => r.shop.name), ['Listed']);
  });

  test('ties are broken by rating, then distance', () {
    final a = cafe('A', moods: ['Cozy'], rating: 4.2);
    final b = cafe('B', moods: ['Cozy'], rating: 4.8);
    final c = cafe('C', moods: ['Cozy'], rating: 4.8);
    final distances = {'A': 100.0, 'B': 900.0, 'C': 300.0};
    final ranked = recommendCafes(
      const CoffeePreferences(atmospheres: {'Cozy'}),
      [a, b, c],
      distanceMeters: (s) => distances[s.name]!,
    );
    expect(ranked.map((r) => r.shop.name), ['C', 'B', 'A']);
  });
}
