import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';
import 'package:local_based_coffee_shops_mobile_application/models/review.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/my_reviews_page.dart';

const _shop = CoffeeShop(
  id: 'shop1',
  ownerId: 'owner1',
  name: 'StarR',
  description: '',
  address: 'Butuan City',
  openTime: '8 AM',
  closeTime: '8 PM',
  latitude: 0,
  longitude: 0,
  rating: 5,
  category: ShopCategory.coffee,
);

Future<void> _pump(WidgetTester tester, Widget card) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: card))));

void main() {
  testWidgets('a café review shows the café, stars, text and its reply', (tester) async {
    var tapped = false;
    await _pump(
      tester,
      MyReviewCard(
        review: const Review(shopId: 'shop1', userName: 'dadave', rating: 4, timeAgo: '2 days ago', text: 'Cozy spot!', ownerReply: 'Thank you!', ownerHearted: true),
        shop: _shop,
        onTap: () => tapped = true,
      ),
    );
    expect(find.text('StarR'), findsOneWidget);
    expect(find.text('Cozy spot!'), findsOneWidget);
    expect(find.text('2 days ago'), findsOneWidget);
    expect(find.text('Thank you!'), findsOneWidget);
    expect(find.text('Loved by the café'), findsOneWidget);
    await tester.tap(find.text('Cozy spot!'));
    expect(tapped, isTrue);
  });

  testWidgets('a coffee review shows the coffee with the café under it', (tester) async {
    await _pump(
      tester,
      MyReviewCard(
        review: const Review(shopId: 'shop1', userName: 'dadave', rating: 5, timeAgo: '19 hours ago', text: 'Good!!', coffeeId: 'latte', coffeeName: 'Iced Spanish Latte'),
        shop: _shop,
        onTap: () {},
      ),
    );
    expect(find.text('Iced Spanish Latte'), findsOneWidget);
    expect(find.text('StarR'), findsOneWidget);
    expect(find.text('Loved by the café'), findsNothing);
  });

  testWidgets('a removed café is labeled', (tester) async {
    await _pump(
      tester,
      MyReviewCard(
        review: const Review(shopId: 'gone', userName: 'dadave', rating: 3, timeAgo: '1 week ago', text: 'Okay'),
        shop: null,
        onTap: () {},
      ),
    );
    expect(find.text('Café no longer available'), findsOneWidget);
  });
}
