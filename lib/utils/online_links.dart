import 'package:flutter/material.dart';
import '../models/coffee_shop.dart';

/// A café's online presence platforms, in the order the "Online" button
/// prefers them (website first).
enum OnlinePlatform { website, facebook, instagram, tiktok }

extension OnlinePlatformInfo on OnlinePlatform {
  String get label => switch (this) {
        OnlinePlatform.website => 'Website',
        OnlinePlatform.facebook => 'Facebook',
        OnlinePlatform.instagram => 'Instagram',
        OnlinePlatform.tiktok => 'TikTok',
      };

  String get emoji => switch (this) {
        OnlinePlatform.website => '🌐',
        OnlinePlatform.facebook => '📘',
        OnlinePlatform.instagram => '📸',
        OnlinePlatform.tiktok => '🎵',
      };

  IconData get icon => switch (this) {
        OnlinePlatform.website => Icons.public_rounded,
        OnlinePlatform.facebook => Icons.facebook_rounded,
        OnlinePlatform.instagram => Icons.camera_alt_rounded,
        OnlinePlatform.tiktok => Icons.music_note_rounded,
      };

  /// Firestore field on `shops/{id}`.
  String get field => switch (this) {
        OnlinePlatform.website => 'website',
        OnlinePlatform.facebook => 'facebookUrl',
        OnlinePlatform.instagram => 'instagramUrl',
        OnlinePlatform.tiktok => 'tiktokUrl',
      };

  /// Example shown in the field's placeholder and error message.
  String get example => switch (this) {
        OnlinePlatform.website => 'https://yourcafe.com',
        OnlinePlatform.facebook => 'https://facebook.com/yourcafe',
        OnlinePlatform.instagram => 'https://instagram.com/yourcafe',
        OnlinePlatform.tiktok => 'https://tiktok.com/@yourcafe',
      };

  /// Domains a link for this platform must be on (website: any domain).
  List<String> get _domains => switch (this) {
        OnlinePlatform.website => const [],
        OnlinePlatform.facebook => const ['facebook.com', 'fb.com', 'fb.me'],
        OnlinePlatform.instagram => const ['instagram.com', 'instagr.am'],
        OnlinePlatform.tiktok => const ['tiktok.com'],
      };
}

/// One link a café has, ready to open.
class OnlineLink {
  final OnlinePlatform platform;
  final String url;

  const OnlineLink(this.platform, this.url);
}

class OnlineLinks {
  OnlineLinks._();

  /// The links [shop]'s owner actually provided, website first. Empty
  /// when they added none (the Online button is then hidden).
  static List<OnlineLink> forShop(CoffeeShop shop) {
    final raw = {
      OnlinePlatform.website: shop.website,
      OnlinePlatform.facebook: shop.facebookUrl,
      OnlinePlatform.instagram: shop.instagramUrl,
      OnlinePlatform.tiktok: shop.tiktokUrl,
    };
    return [
      for (final platform in OnlinePlatform.values)
        if (validate(platform, raw[platform]) == null && (raw[platform]?.trim().isNotEmpty ?? false))
          OnlineLink(platform, normalize(raw[platform]!)),
    ];
  }

  /// Adds https:// when the owner typed a bare link ("www.mycafe.com").
  static String normalize(String value) {
    final v = value.trim();
    if (v.isEmpty) return '';
    final lower = v.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return v;
    return 'https://$v';
  }

  /// Optional link field: empty is fine; otherwise it must be a real
  /// web link (and, for social platforms, point to that platform).
  static String? validate(OnlinePlatform platform, String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final message = 'Please enter a valid ${platform.label} link (e.g. ${platform.example}).';
    if (v.contains(RegExp(r'\s'))) return message;
    final uri = Uri.tryParse(normalize(v));
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) return message;
    final host = uri.host.toLowerCase();
    // Needs a real domain like "mycafe.com" (a dot, and a 2+ letter ending).
    if (!RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}$').hasMatch(host)) return message;
    final domains = platform._domains;
    if (domains.isNotEmpty && !domains.any((d) => host == d || host.endsWith('.$d'))) return message;
    return null;
  }

  /// The value to save: a cleaned-up link, or null when left empty.
  static String? toStored(String? value) {
    final v = normalize(value ?? '');
    return v.isEmpty ? null : v;
  }
}
