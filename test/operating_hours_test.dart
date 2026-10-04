import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/operating_hours.dart';

/// A Manila wall-clock time expressed as the matching UTC instant.
/// Oct 5 2026 is a Monday.
DateTime manila(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 10, day, hour, minute).subtract(OperatingHours.manilaOffset);

const mon = DateTime.monday, tue = DateTime.tuesday, sat = DateTime.saturday, sun = DateTime.sunday;
int t(int h, [int m = 0]) => h * 60 + m;

OperatingHours weekdays8to9() => OperatingHours(days: {
      for (var d = DateTime.monday; d <= DateTime.friday; d++) d: DayHours(t(8), t(21)),
    });

void main() {
  group('open / closed', () {
    test('open within hours, with closing time', () {
      final s = weekdays8to9().statusAt(manila(5, 10)); // Mon 10:00
      expect(s.state, OpenState.open);
      expect(s.headline, 'Open Now');
      expect(s.detail, 'Closes at 9:00 PM');
    });

    test('closed before opening today', () {
      final s = weekdays8to9().statusAt(manila(5, 7, 30)); // Mon 7:30
      expect(s.state, OpenState.closed);
      expect(s.headline, 'Closed Now');
      expect(s.detail, 'Opens at 8:00 AM');
    });

    test('closed in the evening → opens tomorrow', () {
      final s = weekdays8to9().statusAt(manila(5, 21, 0)); // Mon 21:00 exactly = closed
      expect(s.state, OpenState.closed);
      expect(s.detail, 'Opens tomorrow at 8:00 AM');
    });

    test('closed on the weekend → opens Monday', () {
      final s = weekdays8to9().statusAt(manila(10, 12)); // Sat noon
      expect(s.detail, 'Opens Monday at 8:00 AM');
    });
  });

  test('different hours on different days', () {
    final hours = OperatingHours(days: {mon: DayHours(t(8), t(17)), tue: DayHours(t(10), t(22))});
    expect(hours.statusAt(manila(5, 18)).detail, 'Opens tomorrow at 10:00 AM'); // Mon 6 PM
    expect(hours.statusAt(manila(6, 18)).detail, 'Closes at 10:00 PM'); // Tue 6 PM
  });

  group('open past midnight', () {
    final late = OperatingHours(days: {sat: DayHours(t(18), t(2))});

    test('open on the same evening', () {
      final s = late.statusAt(manila(10, 23)); // Sat 11 PM
      expect(s.state, OpenState.open);
      expect(s.detail, 'Closes at 2:00 AM');
    });

    test("still open after midnight on yesterday's hours", () {
      final s = late.statusAt(manila(11, 1, 30)); // Sun 1:30 AM
      expect(s.state, OpenState.open);
      expect(s.detail, 'Closes at 2:00 AM');
    });

    test('closed once it passes closing time', () {
      final s = late.statusAt(manila(11, 2, 0)); // Sun 2:00 AM
      expect(s.state, OpenState.closed);
      expect(s.detail, 'Opens Saturday at 6:00 PM');
    });
  });

  test('open 24 hours every day', () {
    final always = OperatingHours(days: {for (var d = 1; d <= 7; d++) d: DayHours(0, 0)});
    final s = always.statusAt(manila(7, 3));
    expect(s.state, OpenState.open);
    expect(s.detail, 'Open 24 hours');
  });

  test('uses Manila time, not the phone time zone', () {
    // 01:00 UTC on Monday = 09:00 Monday in Manila → open.
    final s = weekdays8to9().statusAt(DateTime.utc(2026, 10, 5, 1));
    expect(s.state, OpenState.open);
  });

  test('temporarily closed overrides open hours', () {
    final hours = weekdays8to9().copyWith(temporarilyClosed: true, closureNote: 'Back on Oct 20');
    final s = hours.statusAt(manila(5, 10));
    expect(s.state, OpenState.temporarilyClosed);
    expect(s.headline, 'Temporarily Closed');
    expect(s.detail, 'Back on Oct 20');
  });

  test('no hours set → Hours unavailable (not Open or Closed)', () {
    final s = const OperatingHours().statusAt(manila(5, 10));
    expect(s.state, OpenState.unavailable);
    expect(s.headline, 'Hours unavailable');
  });

  test('saves and loads the schedule', () {
    final hours = OperatingHours(days: {mon: DayHours(t(8), t(21, 30)), sun: DayHours(t(18), t(2))});
    final loaded = OperatingHours.fromFirestore({
      'operatingHours': hours.toFirestoreMap(),
      'temporarilyClosed': true,
      'closureNote': ' Renovation ',
    });
    expect(loaded.days, hours.days);
    expect(loaded.temporarilyClosed, isTrue);
    expect(loaded.closureNote, 'Renovation');
    expect(hours.toFirestoreMap()['mon'], {'open': '08:00', 'close': '21:30'});
  });

  test('day descriptions', () {
    final hours = OperatingHours(days: {mon: DayHours(t(8), t(21)), tue: DayHours(0, 0)});
    expect(hours.describeDay(mon), '8:00 AM – 9:00 PM');
    expect(hours.describeDay(tue), 'Open 24 hours');
    expect(hours.describeDay(sun), 'Closed');
  });
}
