import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/online_links.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/online_action_button.dart';

CoffeeShop _shop({String? website, String? facebook, String? instagram, String? tiktok}) => CoffeeShop(
      id: 'x',
      name: 'Brew Haven',
      description: '',
      address: '',
      openTime: '8 AM',
      closeTime: '8 PM',
      latitude: 0,
      longitude: 0,
      rating: 0,
      category: ShopCategory.coffee,
      website: website,
      facebookUrl: facebook,
      instagramUrl: instagram,
      tiktokUrl: tiktok,
    );

void main() {
  group('link validation', () {
    test('every field is optional', () {
      for (final p in OnlinePlatform.values) {
        expect(OnlineLinks.validate(p, ''), isNull);
        expect(OnlineLinks.validate(p, null), isNull);
      }
    });

    test('valid links pass, with or without https://', () {
      expect(OnlineLinks.validate(OnlinePlatform.website, 'https://brewhaven.ph'), isNull);
      expect(OnlineLinks.validate(OnlinePlatform.website, 'www.brewhaven.com'), isNull);
      expect(OnlineLinks.validate(OnlinePlatform.facebook, 'facebook.com/brewhaven'), isNull);
      expect(OnlineLinks.validate(OnlinePlatform.facebook, 'https://m.facebook.com/brewhaven'), isNull);
      expect(OnlineLinks.validate(OnlinePlatform.instagram, 'https://www.instagram.com/brewhaven'), isNull);
      expect(OnlineLinks.validate(OnlinePlatform.tiktok, 'https://www.tiktok.com/@brewhaven'), isNull);
    });

    test('malformed links get a clear error', () {
      expect(OnlineLinks.validate(OnlinePlatform.website, 'brewhaven'), contains('valid Website link'));
      expect(OnlineLinks.validate(OnlinePlatform.website, 'brew haven.com'), isNotNull);
      expect(OnlineLinks.validate(OnlinePlatform.website, 'ftp://brewhaven.com'), isNotNull);
    });

    test('a social link must point to that platform', () {
      expect(
        OnlineLinks.validate(OnlinePlatform.facebook, 'https://instagram.com/brewhaven'),
        'Please enter a valid Facebook link (e.g. https://facebook.com/yourcafe).',
      );
      expect(OnlineLinks.validate(OnlinePlatform.tiktok, 'https://notiktok.com/x'), isNotNull);
    });

    test('stored links get https:// and empty fields are saved as nothing', () {
      expect(OnlineLinks.toStored('www.brewhaven.com'), 'https://www.brewhaven.com');
      expect(OnlineLinks.toStored('  '), isNull);
    });
  });

  group('available links', () {
    test('only links the owner added, website first', () {
      final links = OnlineLinks.forShop(_shop(tiktok: 'tiktok.com/@b', website: 'brewhaven.com'));
      expect(links.map((l) => l.platform), [OnlinePlatform.website, OnlinePlatform.tiktok]);
      expect(links.first.url, 'https://brewhaven.com');
    });

    test('no links means none', () {
      expect(OnlineLinks.forShop(_shop()), isEmpty);
    });
  });

  group('Online button', () {
    Future<List<OnlineLink>> pump(WidgetTester tester, CoffeeShop shop) async {
      final opened = <OnlineLink>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(child: OnlineActionButton(links: OnlineLinks.forShop(shop), onOpen: opened.add)),
        ),
      ));
      return opened;
    }

    testWidgets('hidden when the café has no links', (tester) async {
      await pump(tester, _shop());
      expect(find.byType(InkWell), findsNothing);
      expect(find.text('Online'), findsNothing);
    });

    testWidgets('one link: shows that platform and opens it directly', (tester) async {
      final opened = await pump(tester, _shop(facebook: 'facebook.com/brewhaven'));
      expect(find.text('Facebook'), findsOneWidget);
      await tester.tap(find.text('Facebook'));
      await tester.pumpAndSettle();
      expect(opened.single.url, 'https://facebook.com/brewhaven');
    });

    testWidgets('website wins the label when it is the only one', (tester) async {
      await pump(tester, _shop(website: 'brewhaven.com'));
      expect(find.text('Website'), findsOneWidget);
    });

    testWidgets('several links: "Online" opens a menu of only those platforms', (tester) async {
      final opened = await pump(tester, _shop(website: 'brewhaven.com', instagram: 'instagram.com/brewhaven'));
      expect(find.text('Online'), findsOneWidget);
      await tester.tap(find.text('Online'));
      await tester.pumpAndSettle();
      expect(find.text('🌐 Website'), findsOneWidget);
      expect(find.text('📸 Instagram'), findsOneWidget);
      expect(find.text('📘 Facebook'), findsNothing);
      expect(find.text('🎵 TikTok'), findsNothing);

      await tester.tap(find.text('📸 Instagram'));
      await tester.pumpAndSettle();
      expect(opened.single.platform, OnlinePlatform.instagram);
    });
  });
}
