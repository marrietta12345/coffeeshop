import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_preferences.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/recommendations.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/cafe_vibe.dart';

CoffeeShop cafe({List<String> types = const [], List<String> moods = const [], List<String> amenities = const []}) => CoffeeShop(
      id: 'c1',
      name: 'Local Brew Café',
      description: '',
      address: 'Butuan City',
      openTime: '',
      closeTime: '',
      latitude: 0,
      longitude: 0,
      rating: 4.5,
      category: ShopCategory.coffee,
      coffeeTypes: types,
      atmospheres: moods,
      amenities: amenities,
    );

const prefs = CoffeePreferences(
  coffeeTypes: {'Latte', 'Cold Brew'},
  atmospheres: {'Cozy'},
  studyFriendly: true,
  wifi: true,
);

void main() {
  group('Vibe Match', () {
    test('the example from the brief: 5 of 6 preferences → 83% Match', () {
      const customer = CoffeePreferences(
        coffeeTypes: {'Latte', 'Cold Brew'},
        atmospheres: {'Cozy', 'Quiet'},
        wifi: true,
        studyFriendly: true,
      );
      final shop = cafe(types: ['Latte', 'Cold Brew', 'Americano'], moods: ['Cozy', 'Modern'], amenities: ['wifi', 'studyFriendly']);
      final match = vibeMatchFor(customer, shop)!;
      expect(match.matched, ['Latte', 'Cold Brew', 'Cozy', 'Study-friendly', 'Wi-Fi']);
      expect(match.notListed, ['Quiet']); // not counted as a match
      expect(match.percent, 83);
      // Same inputs → same result, every time.
      expect(vibeMatchFor(customer, shop)!.percent, 83);
    });

    test('percent = share of the customer\'s selected preferences', () {
      final match = vibeMatchFor(prefs, cafe(types: ['Latte', 'Cold Brew'], moods: ['Cozy'], amenities: ['wifi']))!;
      expect(match.percent, 80); // 4 of 5
    });

    test('no preferences, or no matches → nothing shown (never "0% Match")', () {
      expect(vibeMatchFor(const CoffeePreferences(), cafe(types: ['Latte'])), isNull);
      expect(vibeMatchFor(prefs, cafe()), isNull);
      expect(vibeMatchFor(prefs, cafe(moods: ['Lively'])), isNull);
    });

    test('Recommended for You is sorted by match %, same % as the café page', () {
      final a = cafe(types: ['Latte'], moods: ['Cozy']); // 2 of 5 = 40%
      final b = CoffeeShop(
        id: 'c2', name: 'Coffee Corner', description: '', address: '', openTime: '', closeTime: '',
        latitude: 0, longitude: 0, rating: 4, category: ShopCategory.coffee,
        coffeeTypes: const ['Latte', 'Cold Brew'], atmospheres: const ['Cozy'], amenities: const ['wifi'], // 4 of 5 = 80%
      );
      final ranked = recommendCafes(prefs, [a, b]);
      expect(ranked.map((r) => r.percent), [80, 40]);
      expect(ranked.first.shop.name, 'Coffee Corner');
      expect(ranked.first.percent, vibeMatchFor(prefs, b)!.percent);
    });
  });

  group('Café vibe tags', () {
    test('come only from the café\'s own features: atmosphere, must-haves, coffee', () {
      final tags = CafeVibeTags.tagsFor(cafe(types: ['Espresso', 'Non-coffee'], moods: ['Quiet'], amenities: ['studyFriendly', 'wifi']));
      expect(tags.map((t) => t.$2), ['Quiet', 'Study-friendly', 'Wi-Fi', 'Espresso']);
      expect(CafeVibeTags.tagsFor(cafe()), isEmpty);
    });
  });

  testWidgets('pill shows the match; tapping explains it', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final match = vibeMatchFor(prefs, cafe(types: ['Latte', 'Cold Brew'], moods: ['Cozy'], amenities: ['wifi']))!;
    var editedPreferences = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: VibeMatchPill(
              match: match,
              onTap: () => showVibeMatchSheet(context, match: match, shopName: 'Local Brew Café', onEditPreferences: () => editedPreferences = true),
            ),
          ),
        ),
      ),
    ));
    expect(find.text('80% Match'), findsOneWidget);

    await tester.tap(find.text('80% Match'));
    await tester.pumpAndSettle();
    expect(find.text('Your Match'), findsOneWidget);
    expect(find.text('80% Match for You'), findsOneWidget);
    expect(find.text('Matches your preferences'), findsOneWidget);
    expect(find.text('Cold Brew'), findsOneWidget);
    // Only what actually matches — unmatched preferences aren't listed.
    expect(find.text('Study-friendly'), findsNothing);

    await tester.tap(find.text('Edit my Coffee Preferences'));
    await tester.pumpAndSettle();
    expect(editedPreferences, isTrue);
  });
}
