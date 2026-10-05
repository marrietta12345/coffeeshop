import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';
import 'package:local_based_coffee_shops_mobile_application/models/menu_item.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/fitted_image.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/menu_item_image.dart';

// A 1×1 PNG, standing in for any uploaded photo.
final _pixel = MemoryImage(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
));

void main() {
  test('standard containers', () {
    expect(ImageRatios.banner, 16 / 9);
    expect(ImageRatios.coffee, 4 / 3);
    expect(ImageRatios.thumbnail, 4 / 3);
    expect(ImageRatios.square, 1);
  });

  testWidgets('photos are shown whole inside a fixed box — never stretched or cropped', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Center(child: FittedImage(image: _pixel, width: 160, height: 120)),
    ));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);
    // The box keeps its size whatever the photo's shape.
    expect(tester.getSize(find.byType(FittedImage)), const Size(160, 120));
  });

  testWidgets('a picked photo is previewed in its box with Cancel / Use Image', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400); // a phone screen
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await confirmPhoto(context, image: _pixel, aspectRatio: ImageRatios.coffee),
          child: const Text('pick'),
        ),
      ),
    ));

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    expect(find.text('Use this photo?'), findsOneWidget);
    expect(find.byType(AspectRatio), findsOneWidget);
    expect(tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio, 4 / 3);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use Image'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('coffee photos fill their 4:3 box (centered), like food apps', (tester) async {
    final shop = CoffeeShop(
      id: 'shop1', ownerId: 'owner1', name: 'Brew Haven', description: '', address: 'Butuan City',
      openTime: '8 AM', closeTime: '8 PM', latitude: 0, longitude: 0, rating: 0, category: ShopCategory.coffee,
    );
    const item = MenuItem(name: 'Iced Spanish Latte', description: '', price: 200, imageUrl: 'https://example.com/latte.jpg');
    await tester.pumpWidget(MaterialApp(
      home: Center(child: MenuItemImage(item: item, shop: shop, fallbackIndex: 0, width: 160, height: 120)),
    ));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.cover);
    expect(image.alignment, Alignment.center);
    expect(tester.getSize(find.byType(FittedImage)), const Size(160, 120));
  });

  testWidgets('the coffee photo preview shows the filled framing and a tip', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => confirmPhoto(context, image: _pixel, aspectRatio: ImageRatios.coffee, fit: BoxFit.cover),
          child: const Text('pick'),
        ),
      ),
    ));
    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
    expect(find.textContaining('square or landscape photos look best'), findsOneWidget);
  });
}
