import 'package:flutter/material.dart';
import '../models/review.dart';

/// Sort / filter options on the owner Reviews page.
enum ReviewSort {
  recent('Most Recent'),
  highest('Highest Rated'),
  lowest('Lowest Rated'),
  withPhotos('With Photos');

  final String label;

  const ReviewSort(this.label);
}

/// Overall rating and star breakdown, computed from the actual reviews.
class RatingSummary {
  final double average; // 0 when there are no reviews
  final int total;
  final Map<int, int> counts; // stars (1–5) → number of reviews

  const RatingSummary({required this.average, required this.total, required this.counts});

  /// Share of reviews with [stars] stars, 0–1.
  double share(int stars) => total == 0 ? 0 : (counts[stars] ?? 0) / total;

  /// Whole-number percentages for 5…1 stars that add up to exactly 100
  /// (largest-remainder rounding), so the list never shows 99% or 101%.
  Map<int, int> get percentages {
    if (total == 0) return {for (var s = 5; s >= 1; s--) s: 0};
    final exact = {for (var s = 5; s >= 1; s--) s: (counts[s] ?? 0) * 100 / total};
    final result = {for (final e in exact.entries) e.key: e.value.floor()};
    var left = 100 - result.values.fold(0, (a, b) => a + b);
    final byRemainder = exact.keys.toList()
      ..sort((a, b) => (exact[b]! - result[b]!).compareTo(exact[a]! - result[a]!));
    for (final s in byRemainder) {
      if (left == 0) break;
      result[s] = result[s]! + 1;
      left--;
    }
    return result;
  }
}

/// Something customers keep praising, found in real review text.
class CustomerLove {
  final String label;
  final IconData icon;
  final int mentions; // number of positive reviews that mention it

  const CustomerLove(this.label, this.icon, this.mentions);
}

class ReviewInsights {
  ReviewInsights._();

  static RatingSummary summarize(List<Review> reviews) {
    final counts = {for (var s = 1; s <= 5; s++) s: 0};
    var sum = 0.0;
    for (final r in reviews) {
      final stars = r.rating.round().clamp(1, 5);
      counts[stars] = counts[stars]! + 1;
      sum += r.rating;
    }
    return RatingSummary(
      average: reviews.isEmpty ? 0 : sum / reviews.length,
      total: reviews.length,
      counts: counts,
    );
  }

  /// [reviews] in the chosen order ("With Photos" keeps only reviews with
  /// a photo, newest first). Ties fall back to newest first.
  static List<Review> sorted(List<Review> reviews, ReviewSort sort) {
    int newest(Review a, Review b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
    final list = sort == ReviewSort.withPhotos ? reviews.where((r) => r.hasPhoto).toList() : List.of(reviews);
    switch (sort) {
      case ReviewSort.recent:
      case ReviewSort.withPhotos:
        list.sort(newest);
      case ReviewSort.highest:
        list.sort((a, b) {
          final c = b.rating.compareTo(a.rating);
          return c != 0 ? c : newest(a, b);
        });
      case ReviewSort.lowest:
        list.sort((a, b) {
          final c = a.rating.compareTo(b.rating);
          return c != 0 ? c : newest(a, b);
        });
    }
    return list;
  }

  /// Themes and the words that count as mentioning them.
  static const List<(String, IconData, List<String>)> _themes = [
    ('Coffee Quality', Icons.local_cafe_rounded, [
      'coffee', 'latte', 'espresso', 'brew', 'cappuccino', 'americano', 'mocha', 'macchiato',
      'taste', 'tasty', 'delicious', 'flavor', 'flavour', 'beans', 'roast', 'sarap',
    ]),
    ('Cozy Atmosphere', Icons.spa_rounded, ['cozy', 'cosy', 'chill', 'relaxing', 'calm', 'peaceful', 'quiet', 'homey', 'warm']),
    ('Wi-Fi', Icons.wifi_rounded, ['wifi', 'wi-fi', 'internet']),
    ('Café Ambiance', Icons.auto_awesome_rounded, ['ambiance', 'ambience', 'aesthetic', 'vibe', 'vibes', 'interior', 'music', 'instagrammable', 'design', 'lighting']),
    ('Comfortable Space', Icons.chair_rounded, ['comfortable', 'comfy', 'spacious', 'seats', 'seating', 'sofa', 'space', 'roomy']),
    ('Friendly Staff', Icons.emoji_people_rounded, ['staff', 'barista', 'service', 'friendly', 'accommodating', 'welcoming']),
  ];

  /// Minimum reviews before the section can show at all.
  static const int minReviews = 3;

  /// Minimum positive reviews that must mention a theme for it to show.
  static const int minMentions = 2;

  /// What customers love, from positive (4–5★) reviews only: a theme
  /// shows when at least [minMentions] of them mention it. Empty when
  /// there isn't enough real review data — the section is then hidden.
  static List<CustomerLove> customersLove(List<Review> reviews) {
    if (reviews.length < minReviews) return const [];
    final positive = reviews.where((r) => r.rating >= 4).map((r) => _words(r.text)).toList();
    final result = <CustomerLove>[];
    for (final (label, icon, keywords) in _themes) {
      final mentions = positive.where((words) => keywords.any(words.contains)).length;
      if (mentions >= minMentions) result.add(CustomerLove(label, icon, mentions));
    }
    result.sort((a, b) => b.mentions.compareTo(a.mentions));
    return result.take(4).toList();
  }

  /// Lower-case words of [text] ("Wi-Fi" kept as "wi-fi" and also "wifi").
  static Set<String> _words(String text) {
    final lower = text.toLowerCase();
    final words = RegExp(r"[a-z]+(?:-[a-z]+)?").allMatches(lower).map((m) => m.group(0)!).toSet();
    return {...words, for (final w in words) if (w.contains('-')) w.replaceAll('-', '')};
  }
}
