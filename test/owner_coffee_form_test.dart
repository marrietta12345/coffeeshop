import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';
import 'package:local_based_coffee_shops_mobile_application/models/menu_item.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/owner_coffee_form_page.dart';

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

Future<void> pumpForm(WidgetTester tester, {MenuItem? existing, List<MenuItem> menu = const []}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: OwnerCoffeeFormPage(shop: shop, existing: existing, menu: menu)));
}

void main() {
  testWidgets('saving an empty form shows required errors for name, price and category', (tester) async {
    await pumpForm(tester);
    await tester.ensureVisible(find.text('Add Coffee').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Coffee').last);
    await tester.pump();
    expect(find.text('This field is required.'), findsNWidgets(3));
  });

  testWidgets('blocks a coffee already on the menu and a negative price', (tester) async {
    await pumpForm(tester, menu: const [MenuItem(id: 'a', name: 'Cold Brew', description: '', price: 150)]);
    await tester.enterText(find.byType(TextFormField).at(0), 'cold brew');
    await tester.enterText(find.byType(TextFormField).at(2), '-20');
    await tester.ensureVisible(find.text('Add Coffee').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Coffee').last);
    await tester.pump();
    expect(find.text('This coffee is already on your menu.'), findsOneWidget);
    // The price box doesn't accept a minus sign at all.
    expect(find.text('20'), findsOneWidget);
  });

  testWidgets('editing loads the current coffee details', (tester) async {
    await pumpForm(
      tester,
      existing: const MenuItem(id: 'a', name: 'Spanish Latte', description: 'Sweet and creamy', price: 145.5, category: 'Spanish Latte', available: false),
    );
    expect(find.text('Edit Coffee'), findsOneWidget);
    expect(find.text('Spanish Latte'), findsWidgets);
    expect(find.text('Sweet and creamy'), findsOneWidget);
    expect(find.text('145.50'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });
}
