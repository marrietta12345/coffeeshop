import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/coffee_shop.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/owner_edit_profile_page.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/form_validators.dart';

CoffeeShop _shop({String? phone}) => CoffeeShop(
      id: 'shop1',
      ownerId: 'owner1',
      name: 'Brew Haven',
      description: '',
      address: 'Butuan City',
      openTime: '8 AM',
      closeTime: '8 PM',
      latitude: 0,
      longitude: 0,
      rating: 0,
      category: ShopCategory.coffee,
      phoneNumber: phone,
    );

Finder _phoneField() => find.descendant(
      of: find.ancestor(of: find.text('Phone Number'), matching: find.byType(Column)).first,
      matching: find.byType(TextFormField),
    );

String _phoneText(WidgetTester tester) => tester.widget<TextFormField>(_phoneField()).controller!.text;

Future<void> _pump(WidgetTester tester, CoffeeShop shop) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: OwnerEditProfilePage(shop: shop)));
  await tester.pump();
}

void main() {
  _editableTests();

  testWidgets("shows the café's saved phone number", (tester) async {
    await _pump(tester, _shop(phone: '+639171234567'));
    expect(_phoneText(tester), '+639171234567');
  });

  testWidgets('shows an older 09… number in +639 format', (tester) async {
    await _pump(tester, _shop(phone: '09171234567'));
    expect(_phoneText(tester), '+639171234567');
  });

  testWidgets('with no number yet, the field starts with +639', (tester) async {
    await _pump(tester, _shop());
    expect(_phoneText(tester), '+639');
  });

  testWidgets('an incomplete number is rejected on save', (tester) async {
    await _pump(tester, _shop());
    await tester.enterText(_phoneField(), '+639171');
    final save = find.widgetWithText(ElevatedButton, 'Save Changes');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(find.text(FormValidators.phoneMessage), findsOneWidget);
  });
}

void _editableTests() {
  testWidgets('a saved number in an old/unusual format can still be edited', (tester) async {
    await _pump(tester, _shop(phone: '085 342 1234'));
    // Owner clears it and types their mobile number.
    await tester.enterText(_phoneField(), '');
    await tester.enterText(_phoneField(), '09171234567');
    expect(_phoneText(tester), '+639171234567');
  });

  testWidgets('an old/unusual saved number can be deleted one character at a time', (tester) async {
    await _pump(tester, _shop(phone: '085 342 1234'));
    final start = _phoneText(tester);
    // Backspace once, like a real user.
    await tester.enterText(_phoneField(), start.substring(0, start.length - 1));
    expect(_phoneText(tester), start.substring(0, start.length - 1));
  });

  testWidgets('a saved number can be changed to a new one', (tester) async {
    await _pump(tester, _shop(phone: '+639171234567'));
    await tester.enterText(_phoneField(), '+639998887777');
    expect(_phoneText(tester), '+639998887777');
  });
}
