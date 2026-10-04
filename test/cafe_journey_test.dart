import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/cafe_journey.dart';

/// A day [daysAgo] before today, at [hour] local time.
DateTime daysAgo(int daysAgo, {int hour = 12}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - daysAgo, hour);
}

CafeJourney journeyWithDiscoveries(List<DateTime> discoveredAt, {Map<String, dynamic> extra = const {}}) {
  return CafeJourney.fromUserData({
    'discoveredCafes': {
      for (var i = 0; i < discoveredAt.length; i++)
        'shop$i': {'shopName': 'Shop $i', 'discoveredAt': Timestamp.fromDate(discoveredAt[i])},
    },
    ...extra,
  });
}

void main() {
  group('Daily Discovery', () {
    test('goal of 1 is met by a café discovered today', () {
      final journey = journeyWithDiscoveries([daysAgo(0, hour: 9), daysAgo(1)]);
      expect(journey.discoveredToday, 1);
      expect(journey.dailyGoalReached, isTrue);
    });

    test('resets the next day without lowering the discovered total', () {
      final journey = journeyWithDiscoveries([daysAgo(1), daysAgo(2)]);
      expect(journey.discoveredToday, 0);
      expect(journey.dailyGoalReached, isFalse);
      expect(journey.cafesDiscovered, 2);
    });
  });

  group('Exploration streak', () {
    test('counts consecutive days ending today', () {
      final journey = journeyWithDiscoveries([daysAgo(0), daysAgo(1), daysAgo(2), daysAgo(4)]);
      expect(journey.currentStreak, 3);
      expect(journey.streakAtRisk, isFalse);
    });

    test('stays alive (but at risk) when the last discovery was yesterday', () {
      final journey = journeyWithDiscoveries([daysAgo(1), daysAgo(2)]);
      expect(journey.currentStreak, 2);
      expect(journey.streakAtRisk, isTrue);
    });

    test('breaks after a missed day', () {
      expect(journeyWithDiscoveries([daysAgo(2), daysAgo(3)]).currentStreak, 0);
    });

    test('several discoveries on one day count as a single streak day', () {
      final journey = journeyWithDiscoveries([daysAgo(0, hour: 8), daysAgo(0, hour: 20), daysAgo(1)]);
      expect(journey.currentStreak, 2);
    });
  });

  group('Permanent counts', () {
    test('history-only cafés (visited before discoveries were logged) still count', () {
      final journey = CafeJourney.fromUserData({
        'visitedShops': {
          'a': {'shopName': 'A', 'visitedAt': Timestamp.fromDate(daysAgo(3)), 'visitCount': 2},
        },
        'discoveredCafes': {
          'b': {'shopName': 'B', 'discoveredAt': Timestamp.fromDate(daysAgo(1))},
        },
      });
      expect(journey.cafesDiscovered, 2);
      expect(journey.discoveredIds, {'a', 'b'});
    });

    test('discoveries saved under the earlier "cafePassport" field still count', () {
      final journey = CafeJourney.fromUserData({
        'cafePassport': {
          'a': {'shopName': 'A', 'discoveredAt': Timestamp.fromDate(daysAgo(5))},
        },
        'discoveredCafes': {
          'a': {'shopName': 'A', 'discoveredAt': Timestamp.fromDate(daysAgo(5))},
          'b': {'shopName': 'B', 'discoveredAt': Timestamp.fromDate(daysAgo(0))},
        },
      });
      expect(journey.cafesDiscovered, 2); // 'a' counted once
    });

    test('removing a café from history keeps the discovered count and visit total', () {
      final journey = CafeJourney.fromUserData({
        'visitedShops': <String, dynamic>{}, // history cleared
        'discoveredCafes': {
          'a': {'shopName': 'A', 'discoveredAt': Timestamp.fromDate(daysAgo(3))},
        },
        'totalVisits': 5,
      });
      expect(journey.history, isEmpty);
      expect(journey.cafesDiscovered, 1);
      expect(journey.totalVisits, 5);
    });
  });
}
