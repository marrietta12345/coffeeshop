import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/owner_edit_profile_page.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/business_permit_service.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/business_permit_section.dart';

CoffeeShop _shop() => CoffeeShop(
      id: 'shop1',
      ownerId: 'owner1',
      name: 'Brew Haven',
      description: '',
      address: 'Butuan City',
      openTime: '8 AM',
      closeTime: '8 PM',
      latitude: 8.95,
      longitude: 125.54,
      rating: 0,
      category: ShopCategory.coffee,
    );

Future<void> _pumpSection(WidgetTester tester, BusinessPermitController controller) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: BusinessPermitSection(controller: controller))),
  ));
}

void main() {
  group('BusinessPermitService.validate', () {
    test('accepts images and PDFs', () {
      for (final name in ['permit.jpg', 'permit.JPEG', 'permit.png', 'permit.webp', 'Mayor Permit 2026.pdf']) {
        expect(BusinessPermitService.validate(fileName: name, sizeBytes: 2000), isNull, reason: name);
      }
    });

    test('rejects other file types', () {
      expect(BusinessPermitService.validate(fileName: 'permit.docx', sizeBytes: 2000), isNotNull);
      expect(BusinessPermitService.validate(fileName: 'permit', sizeBytes: 2000), isNotNull);
    });

    test('rejects empty and over-10 MB files', () {
      expect(BusinessPermitService.validate(fileName: 'a.pdf', sizeBytes: 0), isNotNull);
      expect(BusinessPermitService.validate(fileName: 'a.pdf', sizeBytes: BusinessPermitService.maxBytes), isNull);
      expect(BusinessPermitService.validate(fileName: 'a.pdf', sizeBytes: BusinessPermitService.maxBytes + 1), isNotNull);
    });

    test('content types', () {
      expect(BusinessPermitService.contentTypeFor('PDF'), 'application/pdf');
      expect(BusinessPermitService.contentTypeFor('jpg'), 'image/jpeg');
      expect(BusinessPermitService.contentTypeFor('gif'), isNull);
    });

    test('file sizes', () {
      expect(BusinessPermitService.formatSize(300), '1 KB');
      expect(BusinessPermitService.formatSize(340 * 1024), '340 KB');
      expect(BusinessPermitService.formatSize(1258291), '1.2 MB');
    });
  });

  group('BusinessPermit.fromMap', () {
    test('reads a saved permit', () {
      final permit = BusinessPermit.fromMap({
        'path': 'shop1/1_abc.pdf',
        'fileName': 'Permit.pdf',
        'contentType': 'application/pdf',
        'sizeBytes': 5000,
        'shopId': 'shop1',
        'uploadedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 5)),
      })!;
      expect(permit.isPdf, isTrue);
      expect(permit.fileName, 'Permit.pdf');
      expect(permit.uploadedAt!.isAtSameMomentAs(DateTime.utc(2026, 10, 5)), isTrue);
    });

    test('no permit → null', () {
      expect(BusinessPermit.fromMap(null), isNull);
      expect(BusinessPermit.fromMap({'path': ''}), isNull);
    });
  });

  group('BusinessPermitSection', () {
    testWidgets('is labeled optional with an upload button when empty', (tester) async {
      await _pumpSection(tester, BusinessPermitController(shopId: 'shop1'));
      expect(find.text('Business Permit'), findsOneWidget);
      expect(find.text('Optional'), findsOneWidget);
      expect(find.text('Upload Business Permit'), findsOneWidget);
      expect(find.text('Replace'), findsNothing);
    });

    testWidgets('shows progress while a chosen file (e.g. from Drive) is fetched', (tester) async {
      final controller = BusinessPermitController(shopId: 'shop1')..setFetching(true);
      await _pumpSection(tester, controller);
      expect(find.text('Getting your file…'), findsOneWidget);
      expect(find.text('Upload Business Permit'), findsNothing);
    });

    testWidgets('a saved PDF shows its name with Replace and Remove', (tester) async {
      final controller = BusinessPermitController(shopId: 'shop1')
        ..saved = BusinessPermit(
          path: 'shop1/1_abc.pdf',
          fileName: 'Mayor Permit.pdf',
          contentType: 'application/pdf',
          sizeBytes: 340 * 1024,
          shopId: 'shop1',
          uploadedAt: DateTime.utc(2026, 10, 4, 20), // Oct 5 in Manila
        );
      await _pumpSection(tester, controller);
      expect(find.text('Mayor Permit.pdf'), findsOneWidget);
      expect(find.text('PDF · 340 KB · Uploaded Oct 5, 2026'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
      expect(find.text('Replace'), findsOneWidget);
      expect(find.text('Upload Business Permit'), findsNothing);

      await tester.tap(find.text('Remove'));
      await tester.pump();
      expect(controller.hasChanges, isTrue);
      expect(find.text('Upload Business Permit'), findsOneWidget);
    });

    testWidgets('a newly picked file waits for Save Changes', (tester) async {
      final controller = BusinessPermitController(shopId: 'shop1')
        ..pick(PickedPermit(bytes: Uint8List(2048), fileName: 'permit.pdf'));
      await _pumpSection(tester, controller);
      expect(find.text('permit.pdf'), findsOneWidget);
      expect(find.text('PDF · 2 KB · Tap Save Changes to upload'), findsOneWidget);
    });

    test('nothing to upload or remove when untouched', () async {
      final controller = BusinessPermitController(shopId: 'shop1');
      expect(controller.hasChanges, isFalse);
      await controller.commit(); // no storage or Firestore calls
    });
  });

  testWidgets('Edit Profile shows the Business Permit section and saves without one', (tester) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: OwnerEditProfilePage(shop: _shop())));
    await tester.pump();

    expect(find.text('Business Permit'), findsOneWidget);
    expect(find.text('Upload Business Permit'), findsOneWidget);

    final save = find.widgetWithText(ElevatedButton, 'Save Changes');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    // No permit → no permit error (Firebase isn't available in tests, so
    // the shop write itself fails with the general message).
    expect(find.textContaining('business permit'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });
}
