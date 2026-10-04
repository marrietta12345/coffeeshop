import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/form_validators.dart';

void main() {
  group('Philippine mobile number', () {
    test('accepts +639 followed by 9 digits (12 digits after +)', () {
      expect(FormValidators.phMobile('+639171234567'), isNull);
    });

    test('accepts common ways of typing it', () {
      expect(FormValidators.phMobile('09171234567'), isNull);
      expect(FormValidators.phMobile('+63 917 123 4567'), isNull);
      expect(FormValidators.phMobile('917-123-4567'), isNull);
    });

    test('incomplete or too long numbers are rejected', () {
      expect(FormValidators.phMobile('+63917123'), FormValidators.phoneMessage);
      expect(FormValidators.phMobile('+6391712345678'), FormValidators.phoneMessage);
    });

    test('non-mobile numbers are rejected', () {
      expect(FormValidators.phMobile('+63281234567'), FormValidators.phoneMessage); // Manila landline
    });

    test('empty, or just the +639 prefix, is required', () {
      expect(FormValidators.phMobile(''), FormValidators.requiredMessage);
      expect(FormValidators.phMobile('+639'), FormValidators.requiredMessage);
    });

    test('normalizes to +639XXXXXXXXX', () {
      expect(FormValidators.normalizePhMobile('0917 123 4567'), '+639171234567');
      expect(FormValidators.normalizePhMobile('+639171234567'), '+639171234567');
    });
  });

  group('phone input formatter', () {
    const formatter = PhMobileInputFormatter();
    String type(String text) =>
        formatter.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text)).text;

    test('keeps the +639 prefix even when it is deleted', () {
      expect(type(''), '+639');
      expect(type('+63'), '+639');
    });

    test('allows digits only and at most 9 after the prefix', () {
      expect(type('+639abc17'), '+63917');
      expect(type('+63917123456789'), '+639171234567');
    });

    test('converts a pasted local number', () {
      expect(type('0917 123 4567'), '+639171234567');
    });
  });

  group('email', () {
    test('valid addresses pass', () {
      expect(FormValidators.email('example@gmail.com'), isNull);
      expect(FormValidators.email(' owner.name@cafe.com.ph '), isNull);
    });

    test('missing @ or a real domain is rejected', () {
      expect(FormValidators.email('examplegmail.com'), FormValidators.emailMessage);
      expect(FormValidators.email('example@gmail'), FormValidators.emailMessage);
      expect(FormValidators.email('example@.com'), FormValidators.emailMessage);
      expect(FormValidators.email('ex ample@gmail.com'), FormValidators.emailMessage);
    });

    test('empty email is required', () {
      expect(FormValidators.email('  '), FormValidators.requiredMessage);
    });
  });

  test('required fields reject empty and blank values', () {
    expect(FormValidators.required(''), FormValidators.requiredMessage);
    expect(FormValidators.required('   '), FormValidators.requiredMessage);
    expect(FormValidators.required('Brew Haven'), isNull);
  });

  test('password is required and at least 6 characters', () {
    expect(FormValidators.password(''), FormValidators.requiredMessage);
    expect(FormValidators.password('12345'), isNotNull);
    expect(FormValidators.password('123456'), isNull);
  });
}
