import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/menu_item.dart';
import 'package:local_based_coffee_shops_mobile_application/models/review.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/form_validators.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/menu_service.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/review_insights.dart';

MenuItem coffee(String name, {int likes = 0}) => MenuItem(id: name, name: name, description: '', price: 120, likes: likes);

Review review(double rating, {String text = 'Nice', String? photo, int daysAgo = 0, String? reply}) => Review(
      userName: 'Customer',
      rating: rating,
      timeAgo: '',
      text: text,
      photoUrl: photo,
      createdAt: DateTime(2026, 10, 4).subtract(Duration(days: daysAgo)),
      ownerReply: reply,
    );

void main() {
  group('Coffee price validation', () {
    test('requires a price', () {
      expect(FormValidators.price(''), FormValidators.requiredMessage);
      expect(FormValidators.price('   '), FormValidators.requiredMessage);
    });

    test('accepts whole and decimal pesos', () {
      expect(FormValidators.price('120'), isNull);
      expect(FormValidators.price('120.50'), isNull);
      expect(FormValidators.price('1,250'), isNull);
      expect(FormValidators.parsePrice('1,250.5'), 1250.5);
    });

    test('rejects negative, zero and invalid prices', () {
      expect(FormValidators.price('-5'), 'Price cannot be negative.');
      expect(FormValidators.price('0'), 'Price must be more than ₱0.');
      expect(FormValidators.price('abc'), isNotNull);
      expect(FormValidators.price('12.345'), isNotNull);
      expect(FormValidators.price('1.2.3'), isNotNull);
      expect(FormValidators.price('100000'), isNotNull);
    });

    test('prices display in pesos', () {
      expect(MenuItem.formatPrice(120), '₱120');
      expect(MenuItem.formatPrice(120.5), '₱120.50');
    });
  });

  group('Coffee categories', () {
    test('are coffee only and reuse the Coffee Preferences spelling', () {
      expect(CoffeeCategory.all, contains('Pour-over'));
      expect(CoffeeCategory.all, contains('Other Coffee'));
      for (final banned in ['Tea', 'Pastries', 'Desserts', 'Snacks', 'Food', 'Non-coffee']) {
        expect(CoffeeCategory.all, isNot(contains(banned)));
      }
    });
  });

  group('Popular Coffee ranking', () {
    test('ranks by hearts, ties by name, and drops coffees nobody hearted', () {
      final ranked = MenuService.rankPopular([
        PopularCoffee(coffee('Mocha'), 3),
        PopularCoffee(coffee('Cold Brew'), 0),
        PopularCoffee(coffee('Americano'), 3),
        PopularCoffee(coffee('Spanish Latte'), 9),
      ]);
      expect(ranked.map((e) => e.item.name), ['Spanish Latte', 'Americano', 'Mocha']);
    });

    test('no hearts at all means no popular coffee', () {
      expect(MenuService.rankPopular([PopularCoffee(coffee('Latte'), 0)]), isEmpty);
    });

    test('This Week starts at Manila midnight 6 days ago', () {
      // 10:30 in Manila on Oct 4 = 02:30 UTC.
      expect(MenuService.periodStart(7, DateTime.utc(2026, 10, 4, 2, 30)), DateTime.utc(2026, 9, 27, 16));
      expect(MenuService.periodStart(30, DateTime.utc(2026, 10, 4, 2, 30)), DateTime.utc(2026, 9, 4, 16));
    });
  });

  group('Review summary', () {
    test('average, total and star counts come from the reviews', () {
      final s = ReviewInsights.summarize([review(5), review(5), review(4), review(1)]);
      expect(s.total, 4);
      expect(s.average, 3.75);
      expect(s.counts[5], 2);
      expect(s.counts[3], 0);
    });

    test('percentages always add up to 100', () {
      final s = ReviewInsights.summarize([review(5), review(4), review(3)]);
      expect(s.percentages.values.fold(0, (a, b) => a + b), 100);
    });

    test('no reviews → zeros, nothing invented', () {
      final s = ReviewInsights.summarize([]);
      expect((s.total, s.average), (0, 0.0));
      expect(s.percentages.values.every((p) => p == 0), isTrue);
    });
  });

  group('Review sorting', () {
    final reviews = [
      review(3, daysAgo: 1),
      review(5, daysAgo: 3, photo: 'https://x/p.jpg'),
      review(1, daysAgo: 0),
    ];

    test('most recent first', () {
      expect(ReviewInsights.sorted(reviews, ReviewSort.recent).map((r) => r.rating), [1, 3, 5]);
    });

    test('highest and lowest rated', () {
      expect(ReviewInsights.sorted(reviews, ReviewSort.highest).map((r) => r.rating), [5, 3, 1]);
      expect(ReviewInsights.sorted(reviews, ReviewSort.lowest).map((r) => r.rating), [1, 3, 5]);
    });

    test('with photos keeps only reviews that have one', () {
      expect(ReviewInsights.sorted(reviews, ReviewSort.withPhotos).length, 1);
    });

    test('needs reply until the owner responds', () {
      expect(review(5).hasOwnerReply, isFalse);
      expect(review(5, reply: 'Thank you!').hasOwnerReply, isTrue);
    });
  });

  group('What Customers Love', () {
    test('hidden when there are too few reviews', () {
      expect(ReviewInsights.customersLove([review(5, text: 'Great coffee'), review(5, text: 'Love the coffee')]), isEmpty);
    });

    test('shows themes mentioned in at least two positive reviews', () {
      final loves = ReviewInsights.customersLove([
        review(5, text: 'Great coffee and fast Wi-Fi'),
        review(4, text: 'Cozy place, the latte was delicious'),
        review(5, text: 'Very cozy and the wifi is strong'),
        review(1, text: 'Cozy but rude'), // negative reviews don't count
      ]);
      final labels = loves.map((l) => l.label).toList();
      expect(labels, containsAll(['Coffee Quality', 'Cozy Atmosphere', 'Wi-Fi']));
      expect(loves.firstWhere((l) => l.label == 'Cozy Atmosphere').mentions, 2);
    });

    test('a single mention is not enough', () {
      final loves = ReviewInsights.customersLove([
        review(5, text: 'Great coffee'),
        review(5, text: 'Nice coffee, comfy sofa'),
        review(4, text: 'Okay'),
      ]);
      expect(loves.map((l) => l.label), isNot(contains('Comfortable Space')));
    });
  });
}
