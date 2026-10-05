import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/business_sign_up_page.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/form_validators.dart';

Finder _field(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
      matching: find.byType(TextFormField),
    );

Future<void> _pumpForm(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: BusinessSignUpPage()));
}

Future<void> _submit(WidgetTester tester) async {
  final button = find.widgetWithText(ElevatedButton, 'Continue');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(seconds: 3)); // let the error banner finish
}

void main() {
  testWidgets('placeholders and the +639 prefix are shown', (tester) async {
    await _pumpForm(tester);
    expect(find.text('example@gmail.com'), findsOneWidget); // email placeholder
    final phone = tester.widget<TextFormField>(_field('Phone Number'));
    expect(phone.controller!.text, '+639');
  });

  testWidgets('required fields are marked with *', (tester) async {
    await _pumpForm(tester);
    // name, email, phone, password, shop name, location type, café address, GPS
    expect(find.text(' *'), findsNWidgets(8));
  });

  testWidgets('submitting an empty form shows required errors', (tester) async {
    await _pumpForm(tester);
    await _submit(tester);
    expect(find.text(FormValidators.requiredMessage), findsNWidgets(6));
  });

  testWidgets('invalid email and incomplete phone show their messages', (tester) async {
    await _pumpForm(tester);
    await tester.enterText(_field('Email'), 'examplegmail.com');
    await tester.enterText(_field('Phone Number'), '+639171');
    await _submit(tester);
    expect(find.text(FormValidators.emailMessage), findsOneWidget);
    expect(find.text(FormValidators.phoneMessage), findsOneWidget);
  });

  testWidgets('phone field keeps +639 and only takes digits', (tester) async {
    await _pumpForm(tester);
    await tester.enterText(_field('Phone Number'), '0917 123 4567');
    final phone = tester.widget<TextFormField>(_field('Phone Number'));
    expect(phone.controller!.text, '+639171234567');
  });

  group('Location Type', () {
    testWidgets('standalone (default) shows Café Address and no mall fields', (tester) async {
      await _pumpForm(tester);
      expect(find.text('Café Address'), findsOneWidget);
      expect(find.text('Mall Name'), findsNothing);
      expect(find.text('Floor Level'), findsNothing);
      expect(find.text('Café GPS Location'), findsOneWidget);
      expect(find.text('Use Current Location'), findsOneWidget);
    });

    Future<void> chooseMall(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Inside a Mall'));
      await tester.tap(find.text('Inside a Mall'));
      await tester.pump();
    }

    testWidgets('Inside a Mall shows mall fields and hides the address', (tester) async {
      await _pumpForm(tester);
      await chooseMall(tester);
      expect(find.text('Mall Name'), findsOneWidget);
      expect(find.text('Floor Level'), findsOneWidget);
      expect(find.text('Unit / Store Number'), findsOneWidget);
      expect(find.text('Specific Location / Landmark'), findsOneWidget);
      expect(find.text('Café Address'), findsNothing);
      // Only the short list of floors, plus Other.
      for (final floor in ['Ground Floor', '1st Floor', '2nd Floor', '3rd Floor', '4th Floor', 'Other']) {
        expect(find.text(floor), findsOneWidget);
      }
      expect(find.text('5th Floor'), findsNothing);
    });

    testWidgets('mall name, floor and landmark are required; unit is optional', (tester) async {
      await _pumpForm(tester);
      await chooseMall(tester);
      await _submit(tester);
      // name, email, phone, password, shop name, mall name, floor level, landmark
      expect(find.text(FormValidators.requiredMessage), findsNWidgets(8));
    });

    testWidgets('choosing Other asks for the floor, and it is required', (tester) async {
      await _pumpForm(tester);
      await chooseMall(tester);
      expect(find.text('Enter Floor Level'), findsNothing);
      await tester.ensureVisible(find.text('Other'));
      await tester.tap(find.text('Other'));
      await tester.pump();
      expect(find.text('Enter Floor Level'), findsOneWidget);
      expect(find.text('e.g., 6th Floor, 10th Floor, Mezzanine'), findsOneWidget);
      await _submit(tester);
      // the 5 account/shop fields, mall name, custom floor, landmark
      expect(find.text(FormValidators.requiredMessage), findsNWidgets(8));
      await tester.enterText(_field('Enter Floor Level'), '10th Floor');
      await tester.pump();
      expect(find.text(FormValidators.requiredMessage), findsNWidgets(7));
    });

    testWidgets('switching back to Standalone hides the mall fields', (tester) async {
      await _pumpForm(tester);
      await chooseMall(tester);
      await tester.tap(find.text('Standalone / Street Location'));
      await tester.pump();
      expect(find.text('Mall Name'), findsNothing);
      expect(find.text('Floor Level'), findsNothing);
      expect(find.text('Café Address'), findsOneWidget);
      expect(find.text('Enter complete café address'), findsOneWidget);
    });

    testWidgets('submitting without a GPS location shows an error and does not continue', (tester) async {
      await _pumpForm(tester);
      await tester.enterText(_field('Full Name'), 'Juan Dela Cruz');
      await tester.enterText(_field('Email'), 'owner@gmail.com');
      await tester.enterText(_field('Phone Number'), '09171234567');
      await tester.enterText(_field('Password'), 'secret123');
      await tester.enterText(_field('Coffee Shop Name'), 'Brew Haven');
      await tester.enterText(_field('Café Address'), 'J.C. Aquino Ave, Butuan City');
      await _submit(tester);
      expect(find.text("Please capture your café's GPS location."), findsOneWidget);
      expect(find.text(FormValidators.requiredMessage), findsNothing);
      expect(find.text('No location captured yet'), findsOneWidget);
    });
  });
}
