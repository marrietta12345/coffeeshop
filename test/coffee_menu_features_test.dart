import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';
import 'package:local_based_coffee_shops_mobile_application/models/menu_item.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/owner_coffee_form_page.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/coffee_badges.dart';

final now = DateTime(2026, 10, 5, 12);

MenuItem coffee(String name, String category, {bool featured = false, bool bestSeller = false, bool available = true, int daysOld = 30}) =>
    MenuItem(
      id: name,
      name: name,
      description: '',
      price: 120,
      category: category,
      featured: featured,
      bestSeller: bestSeller,
      available: available,
      createdAt: now.subtract(Duration(days: daysOld)),
    );

const shop = CoffeeShop(
  id: 'shop1',
  ownerId: 'owner1',
  name: 'StarR',
  description: '',
  address: 'Butuan City',
  openTime: '',
  closeTime: '',
  latitude: 0,
  longitude: 0,
  rating: 0,
  category: ShopCategory.coffee,
);

Future<void> pumpForm(WidgetTester tester, {MenuItem? existing}) async {
  tester.view.physicalSize = const Size(1080, 4400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  // A home page underneath, so the form can be popped.
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerCoffeeFormPage(shop: shop, existing: existing))),
            child: const Text('open form'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open form'));
  await tester.pumpAndSettle();
}

Future<void> tapBack(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
}

void main() {
  group('Menu organized by category', () {
    test('groups in category order, featured first, then newest', () {
      final groups = CoffeeCategory.group([
        coffee('Iced Latte', 'Latte', daysOld: 10),
        coffee('Doppio', 'Espresso'),
        coffee('Spanish Latte', 'Latte', featured: true, daysOld: 40),
        coffee('Vanilla Latte', 'Latte', daysOld: 1),
      ]);
      expect(groups.map((g) => g.$1), ['Espresso', 'Latte']);
      expect(groups[1].$2.map((i) => i.name), ['Spanish Latte', 'Vanilla Latte', 'Iced Latte']);
    });

    test('chips list only categories that have coffee', () {
      expect(CoffeeCategory.used([coffee('A', 'Mocha'), coffee('B', 'Cold Brew')]), ['Cold Brew', 'Mocha']);
    });
  });

  group('Badges', () {
    test('New lasts 14 days after adding a coffee', () {
      expect(coffee('A', 'Latte', daysOld: 3).isNewAt(now), isTrue);
      expect(coffee('A', 'Latte', daysOld: 15).isNewAt(now), isFalse);
    });

    test('Best Seller and Featured only when the owner turns them on', () {
      expect(coffeeBadges(coffee('A', 'Latte'), now: now), isEmpty);
      expect(
        coffeeBadges(coffee('A', 'Latte', bestSeller: true, featured: true, available: false, daysOld: 2), now: now),
        [CoffeeBadgeKind.bestSeller, CoffeeBadgeKind.featured, CoffeeBadgeKind.isNew, CoffeeBadgeKind.unavailable],
      );
    });
  });

  group('Add / Edit Coffee form', () {
    testWidgets('has Best Seller and Featured toggles, loaded when editing', (tester) async {
      await pumpForm(tester, existing: coffee('Spanish Latte', 'Spanish Latte', bestSeller: true));
      expect(find.text('Mark as Best Seller'), findsOneWidget);
      expect(find.text('Feature this coffee'), findsOneWidget);
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches.map((s) => s.value), [true, false]);
    });

    testWidgets('leaving without changes closes right away', (tester) async {
      await pumpForm(tester);
      await tapBack(tester);
      expect(find.text('open form'), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
    });

    testWidgets('leaving with unsaved changes asks first', (tester) async {
      await pumpForm(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Cold Brew Tonic');
      await tester.pump();
      await tapBack(tester);
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();
      expect(find.text('Add Coffee'), findsWidgets); // still on the form

      await tapBack(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('open form'), findsOneWidget);
    });
  });
}
