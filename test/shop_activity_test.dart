import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/shop_activity_service.dart';

void main() {
  group('Activity periods (Manila time)', () {
    // 2026-10-04 10:30 in Manila = 02:30 UTC.
    final now = DateTime.utc(2026, 10, 4, 2, 30);

    test('Today starts at Manila midnight', () {
      expect(ActivityPeriod.today.startAt(now), DateTime.utc(2026, 10, 3, 16));
    });

    test('7 Days covers today and the 6 days before', () {
      expect(ActivityPeriod.week.startAt(now), DateTime.utc(2026, 9, 27, 16));
    });

    test('30 Days covers today and the 29 days before', () {
      expect(ActivityPeriod.month.startAt(now), DateTime.utc(2026, 9, 4, 16));
    });

    test('just after Manila midnight counts as the new day', () {
      // 00:05 Manila on Oct 5 = 16:05 UTC on Oct 4.
      expect(ActivityPeriod.today.startAt(DateTime.utc(2026, 10, 4, 16, 5)), DateTime.utc(2026, 10, 4, 16));
    });
  });

  group('Unique profile views', () {
    final now = DateTime.utc(2026, 10, 4, 2, 30); // 10:30 Manila

    test('a repeat view on the same day changes nothing', () {
      expect(ShopActivityService.needsViewUpdate(DateTime.utc(2026, 10, 4, 1), now), isFalse);
    });

    test('a view on a new day updates the last-viewed date once', () {
      expect(ShopActivityService.needsViewUpdate(DateTime.utc(2026, 10, 3, 15), now), isTrue);
    });

    test('no earlier view needs a record', () {
      expect(ShopActivityService.needsViewUpdate(null, now), isTrue);
    });
  });
}
