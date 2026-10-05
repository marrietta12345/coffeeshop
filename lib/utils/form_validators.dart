import 'package:flutter/services.dart';

/// Shared sign-up form validation. Each validator returns an error
/// message, or null when the value is fine (Flutter's FormField style).
class FormValidators {
  FormValidators._();

  static const String requiredMessage = 'This field is required.';
  static const String emailMessage = 'Please enter a valid email address.';
  static const String phoneMessage = 'Please enter a valid Philippine mobile number.';

  /// Philippine mobile prefix every number starts with.
  static const String phMobilePrefix = '+639';

  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[A-Za-z]{2,}$');

  /// +639 followed by 9 digits — 12 digits after the "+".
  static final RegExp _phMobile = RegExp(r'^\+639\d{9}$');

  static String? required(String? value) =>
      (value == null || value.trim().isEmpty) ? requiredMessage : null;

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return requiredMessage;
    if (!_email.hasMatch(v)) return emailMessage;
    return null;
  }

  static String? phMobile(String? value) {
    final v = normalizePhMobile(value ?? '');
    // Just the prefix (nothing typed yet) counts as empty.
    if (v.isEmpty || v == phMobilePrefix) return requiredMessage;
    if (!_phMobile.hasMatch(v)) return phoneMessage;
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return requiredMessage;
    if (value.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  /// Highest menu price accepted (₱).
  static const double maxPrice = 99999;

  /// A peso price like "120" or "120.50": required, a number, not
  /// negative, above ₱0, at most 2 decimal places.
  static String? price(String? value) {
    final v = (value ?? '').trim().replaceAll(',', '');
    if (v.isEmpty) return requiredMessage;
    if (v.startsWith('-')) return 'Price cannot be negative.';
    final parsed = double.tryParse(v);
    if (parsed == null || !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(v)) return 'Please enter a valid price (e.g. 120 or 120.50).';
    if (parsed <= 0) return 'Price must be more than ₱0.';
    if (parsed > maxPrice) return 'Price must be ₱99,999 or less.';
    return null;
  }

  /// The price typed in [value] (after [price] passed), e.g. "1,250.5" → 1250.5.
  static double parsePrice(String value) => double.parse(value.trim().replaceAll(',', ''));

  /// Puts a Philippine mobile number into +639XXXXXXXXX form, accepting
  /// the common ways people type it (09…, 9…, 639…, +63 9…, spaces or
  /// dashes). Returns '' when nothing was entered.
  /// Anything that isn't a mobile number (e.g. a +632 landline) is kept
  /// as "+digits" so it fails validation instead of being "fixed".
  static String normalizePhMobile(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('639')) return '$phMobilePrefix${digits.substring(3)}';
    if (digits.startsWith('09')) return '$phMobilePrefix${digits.substring(2)}';
    if (digits.startsWith('9')) return '$phMobilePrefix${digits.substring(1)}';
    return '+$digits';
  }
}

/// Keeps a phone field in +639XXXXXXXXX shape while typing: the +639
/// prefix always stays, only digits can be added, at most 9 after the
/// prefix, and pasted numbers like "0917 123 4567" are converted.
class PhMobileInputFormatter extends TextInputFormatter {
  const PhMobileInputFormatter();

  static const int _maxLocalDigits = 9;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    // Deleting into the prefix (e.g. "+63") just leaves the prefix.
    if (digits.length <= 3 && '639'.startsWith(digits)) {
      return const TextEditingValue(
        text: FormValidators.phMobilePrefix,
        selection: TextSelection.collapsed(offset: FormValidators.phMobilePrefix.length),
      );
    }
    final normalized = FormValidators.normalizePhMobile(newValue.text);
    // Not (yet) a +639 number — e.g. an older saved landline. Still let it
    // be edited or deleted (digits only); validation flags it on save.
    if (!normalized.startsWith(FormValidators.phMobilePrefix)) {
      return TextEditingValue(text: normalized, selection: TextSelection.collapsed(offset: normalized.length));
    }
    final local = normalized.substring(FormValidators.phMobilePrefix.length);
    final text = FormValidators.phMobilePrefix +
        (local.length > _maxLocalDigits ? local.substring(0, _maxLocalDigits) : local);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
