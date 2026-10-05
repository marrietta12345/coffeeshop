// Responsive layout checks: every screen/widget here is opened at common
// phone sizes (portrait 320–480 wide), in landscape, and with large system
// fonts, using long real-world text. Any overflow ("RenderFlex overflowed")
// or layout error fails the test.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';
import 'package:local_based_coffee_shops_mobile_application/models/menu_item.dart';
import 'package:local_based_coffee_shops_mobile_application/models/review.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/add_review_page.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/business_sign_in_page.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/business_sign_up_page.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/choose_account_type_page.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/coffee_review_form_page.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/create_collection_page.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/directions_page.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/owner_coffee_form_page.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/owner_edit_profile_page.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/owner_hours_page.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/sign_in_page.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/sign_up_page.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/welcome_page.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/cafe_vibe.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/recommendations.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_preferences.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/coffee_review_widgets.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/custom_bottom_nav.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/owner_bottom_nav.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/fitted_image.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/mobile_frame.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/owner_page_widgets.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/review_reply_sheet.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/settings_widgets.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/shop_gallery.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/shop_mini_card.dart';

/// Screen sizes in logical pixels (width × height).
const portraitSizes = <Size>[
  Size(320, 568), // small phone (iPhone SE 1st gen)
  Size(360, 800), // small Android
  Size(390, 844), // standard Android / iPhone
  Size(430, 932), // large Android / large iPhone
  Size(480, 1000),
];
const landscapeSizes = <Size>[
  Size(800, 360),
  Size(932, 430),
];

const longName = 'The Very Long Named Artisan Coffee Roastery & Study Lounge Butuan';

const shop = CoffeeShop(
  id: 'shop1',
  ownerId: 'owner1',
  name: longName,
  description: 'A cozy café with a very long description that goes on and on about beans, brewing and the vibe.',
  address: 'Purok 7, J.C. Aquino Avenue corner Montilla Boulevard, Barangay Libertad, Butuan City, Agusan del Norte',
  openTime: '',
  closeTime: '',
  latitude: 8.95,
  longitude: 125.54,
  rating: 4.7,
  category: ShopCategory.coffee,
  locationType: 'mall',
  mallName: 'Gaisano Grand Mall of Butuan Northern Mindanao Annex',
  mallFloor: 'Upper Ground Mezzanine Level',
  mallUnit: 'Kiosk 204-B East Wing',
  mallLandmark: 'Beside the escalator near the food court and the cinema entrance',
);

const coffee = MenuItem(
  id: 'c1',
  shopId: 'shop1',
  name: 'Iced Caramel Hazelnut Oat Milk Spanish Latte Supreme',
  description: 'Double ristretto over oat milk with house caramel, hazelnut syrup and a sprinkle of sea salt.',
  price: 12345.5,
  category: 'Spanish Latte',
  bestSeller: true,
  featured: true,
);

const review = Review(
  userName: 'Maria Concepcion Dela Cruz-Villanueva',
  rating: 4,
  timeAgo: '2 days ago',
  text: 'Supercalifragilisticexpialidocious coffee, honestly the creamiest Spanish latte I have had in Butuan — '
      'not too sweet, great ambiance and very fast Wi-Fi for studying all afternoon.',
  photoUrl: null,
  ownerReply: 'Thank you so much for visiting and for the kind words! We hope to see you again very soon.',
);

Widget app(Widget home) => MaterialApp(
      builder: (context, child) => MobileFrame(child: child!),
      home: home,
    );

/// Collects every layout error (with the widget's file:line) while [body] runs.
Future<List<String>> collectLayoutErrors(Future<void> Function() body) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final where = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(details.toString())?.group(0) ?? '?';
    errors.add('${details.exceptionAsString().split('\n').first} @ $where');
  };
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

/// Opens [build] at every size (and with large fonts on small phones).
Future<void> checkSizes(WidgetTester tester, Widget Function() build, {List<Size> sizes = const [...portraitSizes, ...landscapeSizes]}) async {
  final problems = <String>{};
  for (final size in sizes) {
    for (final textScale in [1.0, if (size == portraitSizes.first || size == portraitSizes[1]) 1.3]) {
      final errors = await collectLayoutErrors(() async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(build());
        await tester.pump(const Duration(milliseconds: 300));
      });
      for (final e in errors) {
        problems.add('${size.width.toInt()}x${size.height.toInt()} text x$textScale: $e');
      }
    }
  }
  tester.view.reset();
  tester.platformDispatcher.clearTextScaleFactorTestValue();
  expect(problems, isEmpty, reason: problems.join('\n'));
}

/// Flutter's test font draws every letter as a full square — far wider than
/// real text — so load a real font (Arial, close to Android's Roboto) to
/// measure layouts the way a phone would.
Future<void> loadRealFont() async {
  const folders = [r'C:\Windows\Fonts', '/System/Library/Fonts/Supplemental', '/usr/share/fonts/truetype/msttcorefonts'];
  for (final folder in folders) {
    final regular = [File('$folder/arial.ttf'), File('$folder/Arial.ttf')].where((f) => f.existsSync());
    if (regular.isEmpty) continue;
    final bold = [File('$folder/arialbd.ttf'), File('$folder/Arial Bold.ttf')].where((f) => f.existsSync());
    final loader = FontLoader('Roboto');
    for (final file in [regular.first, ...bold]) {
      loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    }
    await loader.load();
    return;
  }
}

void main() {
  setUpAll(loadRealFont);

  group('Auth screens', () {
    testWidgets('Welcome', (t) => checkSizes(t, () => app(const WelcomePage())));
    testWidgets('Choose account type', (t) => checkSizes(t, () => app(const ChooseAccountTypePage())));
    testWidgets('Sign in', (t) => checkSizes(t, () => app(const SignInPage())));
    testWidgets('Sign up', (t) => checkSizes(t, () => app(const SignUpPage())));
    testWidgets('Business sign in', (t) => checkSizes(t, () => app(const BusinessSignInPage())));
    testWidgets('Business sign up', (t) => checkSizes(t, () => app(const BusinessSignUpPage())));
  });

  group('Owner forms', () {
    testWidgets('Add coffee', (t) => checkSizes(t, () => app(const OwnerCoffeeFormPage(shop: shop))));
    testWidgets('Edit coffee', (t) => checkSizes(t, () => app(const OwnerCoffeeFormPage(shop: shop, existing: coffee))));
    testWidgets('Edit café profile', (t) => checkSizes(t, () => app(const OwnerEditProfilePage(shop: shop))));
    testWidgets('Business hours', (t) => checkSizes(t, () => app(const OwnerHoursPage(shop: shop))));
  });

  group('Customer forms', () {
    testWidgets('Write café review', (t) => checkSizes(t, () => app(const AddReviewPage(shop: shop))));
    testWidgets('Write coffee review', (t) => checkSizes(t, () => app(const CoffeeReviewFormPage(coffee: coffee))));
    testWidgets('Edit coffee review', (t) => checkSizes(t, () => app(const CoffeeReviewFormPage(coffee: coffee, existing: review))));
    testWidgets('Create collection', (t) => checkSizes(t, () => app(const CreateCollectionPage(allCollections: []))));
  });

  group('Cards and rows', () {
    testWidgets('Explore / map café carousels', (t) => checkSizes(
          t,
          () => app(Scaffold(
                body: Builder(
                  builder: (context) => ListView(
                    children: [
                      for (final width in [150.0, 130.0])
                        SizedBox(
                          height: ShopMiniCard.heightFor(width, MediaQuery.textScalerOf(context)),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [ShopMiniCard(shop: shop, distanceLabel: '12.4 km away', width: width, onTap: () {})],
                          ),
                        ),
                    ],
                  ),
                ),
              )),
        ));

    testWidgets('Café list row', (t) => checkSizes(
          t,
          () => app(Scaffold(body: ListView(children: [ShopListRow(shop: shop, detail: 'Visited 3 times · Oct 4, 2026', onTap: () {})]))),
        ));

    testWidgets('Coffee review with café reply', (t) => checkSizes(
          t,
          () => app(const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: CoffeeReviewTile(review: review, isMine: true, shopName: longName),
                ),
              )),
        ));

    testWidgets('Owner page header + empty state', (t) => checkSizes(
          t,
          () => app(Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    OwnerPageHeader(
                      title: 'Reviews',
                      subtitle: '12 coffee reviews need a reply',
                      trailing: OwnerPillButton(icon: Icons.add_rounded, label: 'Add Coffee', onPressed: () {}),
                    ),
                    const SizedBox(height: 16),
                    const OwnerEmptyState(
                      icon: Icons.local_cafe_rounded,
                      title: 'Your coffee menu is empty',
                      message: 'Add your first coffee item to start showcasing your menu.',
                    ),
                  ],
                ),
              )),
        ));
  });

  group('Shop gallery', () {
    final urls = [for (var i = 0; i < 6; i++) 'https://example.com/$i.jpg'];
    testWidgets('Full-screen photo viewer', (t) => checkSizes(t, () => app(PhotoViewerPage(urls: urls, initialIndex: 2))));
  });

  group('Directions', () {
    testWidgets('Directions screen (location off message + café details)', (t) async {
      const channel = MethodChannel('flutter.baseflow.com/geolocator');
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async => call.method == 'isLocationServiceEnabled' ? false : 2);
      addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      await checkSizes(t, () => app(const DirectionsPage(shop: shop)));
    });
  });

  group('Navigation', () {
    for (final selected in [0, 1, 2, 3, 4]) {
      testWidgets('Owner bottom nav (tab $selected selected)', (t) => checkSizes(
            t,
            () => app(Scaffold(body: const SizedBox.expand(), bottomNavigationBar: OwnerBottomNav(selectedIndex: selected, onTabSelected: (_) {}))),
          ));
    }
    for (final selected in [0, 1, 2]) {
      testWidgets('Customer bottom nav (tab $selected selected)', (t) => checkSizes(
            t,
            () => app(Scaffold(body: const SizedBox.expand(), bottomNavigationBar: CustomBottomNav(selectedIndex: selected, onTabSelected: (_) {}))),
          ));
    }
  });

  group('Vibe', () {
    const vibeShop = CoffeeShop(
      id: 'v1', name: longName, description: '', address: '', openTime: '', closeTime: '',
      latitude: 0, longitude: 0, rating: 4, category: ShopCategory.coffee,
      coffeeTypes: ['Espresso', 'Latte', 'Cappuccino', 'Cold Brew'],
      atmospheres: ['Cozy', 'Quiet', 'Minimalist'],
      amenities: ['studyFriendly', 'outdoorSeating', 'wifi', 'petFriendly'],
    );
    testWidgets('Name + match pill + vibe tags row', (t) => checkSizes(
          t,
          () => app(Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(children: [
                        const Expanded(child: Text(longName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                        const SizedBox(width: 8),
                        VibeMatchPill(
                          match: vibeMatchFor(const CoffeePreferences(coffeeTypes: {'Latte'}, wifi: true), vibeShop)!,
                          onTap: () {},
                        ),
                      ]),
                      const SizedBox(height: 10),
                      const CafeVibeTags(shop: vibeShop),
                    ],
                  ),
                ),
              )),
        ));
  });

  group('Sheets', () {
    testWidgets('Photo preview sheet (Cancel / Use Image)', (t) async {
      for (final size in [...portraitSizes, ...landscapeSizes]) {
        t.view.physicalSize = size * 3;
        t.view.devicePixelRatio = 3;
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpWidget(app(Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => confirmPhoto(context, image: const AssetImage('lib/images/kafelo_logo.png'), aspectRatio: ImageRatios.banner),
              child: const Text('open'),
            ),
          ),
        )));
        final errors = await collectLayoutErrors(() async {
          await t.tap(find.text('open'));
          await t.pumpAndSettle();
        });
        expect(errors, isEmpty, reason: 'Photo preview at $size: ${errors.join('; ')}');
        // The buttons stay reachable.
        await t.ensureVisible(find.text('Use Image'));
        expect(find.text('Use Image').hitTestable(), findsOneWidget, reason: 'Use Image reachable at $size');
      }
      t.view.reset();
    });

    testWidgets('Owner reply sheet with the keyboard open', (t) async {
      for (final size in [...portraitSizes, ...landscapeSizes]) {
        t.view.physicalSize = size * 3;
        t.view.devicePixelRatio = 3;
        // The on-screen keyboard takes ~40% of a portrait screen, most of a landscape one.
        t.view.viewInsets = FakeViewPadding(bottom: size.height * (size.width > size.height ? 0.55 : 0.4) * 3);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpWidget(app(Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showReviewReplySheet(context, shopId: 'shop1', review: review),
              child: const Text('open'),
            ),
          ),
        )));
        final errors = await collectLayoutErrors(() async {
          await t.tap(find.text('open'));
          await t.pumpAndSettle();
        });
        expect(errors, isEmpty, reason: 'Reply sheet with keyboard at $size: ${errors.join('; ')}');
      }
      t.view.reset();
    });
  });
}
