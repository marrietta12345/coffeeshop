import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/shop_gallery.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/shop_photo.dart';

List<String> photos(int n) => [for (var i = 1; i <= n; i++) 'https://example.supabase.co/storage/v1/object/public/shop-images/gallery/shop1/$i.jpg'];

CoffeeShop cafe({String? banner, List<String> gallery = const []}) => CoffeeShop(
      id: 'shop1',
      name: 'Mega Coffee',
      description: '',
      address: 'Butuan City',
      openTime: '',
      closeTime: '',
      latitude: 0,
      longitude: 0,
      rating: 5,
      category: ShopCategory.coffee,
      bannerUrl: banner,
      photoUrls: gallery,
    );

void main() {
  group('Café header banner', () {
    test('uses the uploaded banner first', () {
      expect(ShopBanner.urlFor(cafe(banner: 'https://x/banner.jpg', gallery: photos(2))), 'https://x/banner.jpg');
    });

    test('no banner set → the first uploaded photo is the banner', () {
      expect(ShopBanner.urlFor(cafe(gallery: photos(3))), photos(3).first);
      expect(ShopBanner.urlFor(cafe()), isNull); // no photos → placeholder
    });

    test('the Shop Gallery never repeats the banner', () {
      // First photo is the banner → gallery is the other photos.
      expect(ShopBanner.galleryFor(cafe(gallery: photos(3))), photos(3).skip(1).toList());
      // Only one photo → it's the banner, and the gallery is empty.
      expect(ShopBanner.galleryFor(cafe(gallery: photos(1))), isEmpty);
      // A separately set banner → every gallery photo shows.
      expect(ShopBanner.galleryFor(cafe(banner: 'https://x/banner.jpg', gallery: photos(2))), photos(2));
    });

    testWidgets('fills the whole header box without stretching (cover)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SizedBox(width: 400, height: 225, child: ShopBanner(shop: cafe(banner: 'https://x/banner.jpg'), width: double.infinity, height: 225)),
      ));
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
    });
  });

  group('Photo viewer', () {
    Future<void> openViewer(WidgetTester tester, {int at = 0}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: SizedBox(
              width: 200,
              height: 150,
              child: GalleryTile(url: photos(5)[at], onTap: () => openPhotoViewer(context, photos(5), initialIndex: at)),
            ),
          ),
        ),
      ));
      await tester.tap(find.byType(GalleryTile));
      await tester.pumpAndSettle();
    }

    testWidgets('opens at the tapped photo; swipe; close', (tester) async {
      await openViewer(tester, at: 1);
      expect(find.byType(PhotoViewerPage), findsOneWidget);
      expect(find.text('2 / 5'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('3 / 5'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewerPage), findsNothing);
    });

    testWidgets('shows the complete original photo (contain)', (tester) async {
      await openViewer(tester);
      final viewerImage = tester.widgetList<Image>(find.descendant(of: find.byType(PageView), matching: find.byType(Image))).first;
      expect(viewerImage.fit, BoxFit.contain);
    });
  });
}
