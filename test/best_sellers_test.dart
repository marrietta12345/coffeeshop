import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';
import 'package:local_based_coffee_shops_mobile_application/models/menu_item.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/menu_service.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/best_seller_tile.dart';

CoffeeShop _shop(String id, String name) => CoffeeShop(
      id: id,
      name: name,
      description: '',
      address: 'Butuan City',
      openTime: '',
      closeTime: '',
      latitude: 8.95,
      longitude: 125.54,
      rating: 0,
      category: ShopCategory.coffee,
    );

final _cafeA = _shop('a', '3D Café');
final _cafeB = _shop('b', 'Brew Heim Coffee');

CafeCoffee _coffee(String name, {CoffeeShop? shop, bool bestSeller = false, int likes = 0, bool available = true, double price = 120}) => (
      item: MenuItem(
        id: name,
        shopId: (shop ?? _cafeA).id,
        name: name,
        description: '',
        price: price,
        bestSeller: bestSeller,
        likes: likes,
        available: available,
      ),
      shop: shop ?? _cafeA,
    );

void main() {
  group('Explore Best Sellers ranking (café-marked first, then most hearted)', () {
    test('café-marked Best Sellers come first, then hearted coffees', () {
      final ranked = MenuService.rankBestSellers([
        _coffee('Mocha', likes: 9),
        _coffee('Spanish Latte', shop: _cafeB, bestSeller: true),
        _coffee('Americano', likes: 2),
        _coffee('Sea Salt Matcha', bestSeller: true, likes: 4),
      ]);
      expect(ranked.map((c) => c.item.name), ['Sea Salt Matcha', 'Spanish Latte', 'Mocha', 'Americano']);
    });

    test('coffees with no mark and no hearts are left out', () {
      final ranked = MenuService.rankBestSellers([_coffee('Hot Coffee'), _coffee('Latte', likes: 1)]);
      expect(ranked.map((c) => c.item.name), ['Latte']);
    });

    test('unavailable coffees are left out', () {
      final ranked = MenuService.rankBestSellers([
        _coffee('Biscoff Frappe', bestSeller: true, available: false),
        _coffee('Matcha Frappe', likes: 5, available: false),
      ]);
      expect(ranked, isEmpty);
    });

    test('ties are broken by name', () {
      final ranked = MenuService.rankBestSellers([
        _coffee('Mocha', likes: 3),
        _coffee('americano', likes: 3, shop: _cafeB),
      ]);
      expect(ranked.map((c) => c.item.name), ['americano', 'Mocha']);
    });

    test('nothing on any menu means no best sellers', () {
      expect(MenuService.rankBestSellers([]), isEmpty);
    });
  });

  group('BestSellerTile', () {
    Future<void> pump(WidgetTester tester, CafeCoffee coffee, {VoidCallback? onTap}) => tester.pumpWidget(MaterialApp(
          home: Scaffold(body: BestSellerTile(item: coffee.item, shop: coffee.shop, onTap: onTap ?? () {})),
        ));

    testWidgets('café-marked coffee shows the Best Seller label, café and price', (tester) async {
      await pump(tester, _coffee('Spanish Latte', shop: _cafeB, bestSeller: true, price: 135));
      expect(find.text('Spanish Latte'), findsOneWidget);
      expect(find.text('BEST SELLER'), findsOneWidget);
      expect(find.text('Brew Heim Coffee'), findsOneWidget);
      expect(find.text('₱135'), findsOneWidget);
    });

    testWidgets('hearted coffee without a mark has no label; no price shows "No price yet"', (tester) async {
      await pump(tester, _coffee('Mocha Frappe', likes: 7, price: 0));
      expect(find.text('BEST SELLER'), findsNothing);
      expect(find.text('7'), findsOneWidget);
      expect(find.text(MenuItem.noPriceLabel), findsOneWidget);
    });

    testWidgets('tapping opens the coffee', (tester) async {
      var taps = 0;
      await pump(tester, _coffee('Mocha', likes: 1), onTap: () => taps++);
      await tester.tap(find.text('Mocha'));
      expect(taps, 1);
    });
  });
}
