import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/shop_mini_card.dart';

CoffeeShop _shop({bool mall = false}) => CoffeeShop(
      id: 'shop1',
      ownerId: 'owner1',
      name: 'StarR',
      description: '',
      address: 'J.C. Aquino Ave, Butuan City',
      openTime: '8 AM',
      closeTime: '8 PM',
      latitude: 8.95,
      longitude: 125.54,
      rating: 5,
      category: ShopCategory.coffee,
      locationType: mall ? 'mall' : 'standalone',
      mallName: mall ? 'SM Butuan' : null,
      mallFloor: mall ? 'Ground Floor' : null,
    );

Future<void> _pump(WidgetTester tester, Widget card) => tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(height: 260, child: card))),
    ));

void main() {
  testWidgets('mall cafés: clean photo, mall and floor under the name', (tester) async {
    await _pump(tester, ShopMiniCard(shop: _shop(mall: true), distanceLabel: '0.8 km away', onTap: () {}));
    expect(find.textContaining('Inside'), findsNothing); // no box over the photo
    expect(find.text('SM Butuan · Ground Floor'), findsOneWidget);
    expect(find.byIcon(Icons.local_mall_outlined), findsOneWidget);
    expect(find.text(' · 0.8 km'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
  });

  testWidgets('standalone cafés show their address', (tester) async {
    await _pump(tester, ShopMiniCard(shop: _shop(), distanceLabel: '350 m away', onTap: () {}));
    expect(find.text('J.C. Aquino Ave, Butuan City'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
  });

  testWidgets('Recommended cards show the match % on the photo', (tester) async {
    await _pump(tester, ShopMiniCard(shop: _shop(mall: true), distanceLabel: '0.8 km away', matchPercent: 50, onTap: () {}));
    expect(find.text('50%'), findsOneWidget);
    expect(find.textContaining('Match for'), findsNothing);
  });
}
