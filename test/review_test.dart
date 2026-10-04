import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/review.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/review_service.dart';

void main() {
  group('Shop rating totals', () {
    test('first review sets the average', () {
      final t = ReviewService.updatedRatingTotals(ratingSum: 0, reviewCount: 0, previousRating: null, newRating: 4);
      expect((t.sum, t.count, t.average), (4.0, 1, 4.0));
    });

    test('reviews from different users are averaged', () {
      final t = ReviewService.updatedRatingTotals(ratingSum: 9, reviewCount: 2, previousRating: null, newRating: 3);
      expect((t.sum, t.count, t.average), (12.0, 3, 4.0));
    });

    test('editing your own review replaces your old rating instead of adding another', () {
      // Two reviews (5 and 3); the author of the 3 changes it to 4.
      final t = ReviewService.updatedRatingTotals(ratingSum: 8, reviewCount: 2, previousRating: 3, newRating: 4);
      expect((t.sum, t.count, t.average), (9.0, 2, 4.5));
    });

    test('average is rounded to two decimals', () {
      final t = ReviewService.updatedRatingTotals(ratingSum: 9, reviewCount: 2, previousRating: null, newRating: 5);
      expect(t.average, 4.67);
    });
  });

  group('Review time labels', () {
    test('formats how long ago a review was posted', () {
      final now = DateTime.now();
      expect(Review.formatTimeAgo(now), 'Just now');
      expect(Review.formatTimeAgo(now.subtract(const Duration(minutes: 1))), '1 minute ago');
      expect(Review.formatTimeAgo(now.subtract(const Duration(hours: 5))), '5 hours ago');
      expect(Review.formatTimeAgo(now.subtract(const Duration(days: 3))), '3 days ago');
      expect(Review.formatTimeAgo(now.subtract(const Duration(days: 14))), '2 weeks ago');
    });
  });
}
