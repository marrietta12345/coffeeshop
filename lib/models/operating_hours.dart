/// A café's weekly opening hours, set by its owner, and the logic that
/// turns them into "Open Now / Closed Now / Temporarily Closed / Hours
/// unavailable" — always in Philippine time (Asia/Manila, UTC+8, no
/// daylight saving).
///
/// Stored on `shops/{id}` as:
///   operatingHours: { mon: {open: '08:00', close: '21:00'}, ... }
///   temporarilyClosed: bool, closureNote: string?
/// A day that's missing is a closed day. A closing time earlier than the
/// opening time means the café closes after midnight (e.g. 18:00–02:00);
/// the same opening and closing time means open 24 hours that day.
class DayHours {
  final int openMinute; // minutes after midnight, 0–1439
  final int closeMinute;

  const DayHours(this.openMinute, this.closeMinute);

  /// How long the café is open, in minutes (past midnight runs into the
  /// next day; equal times = 24 hours).
  int get durationMinutes {
    if (closeMinute == openMinute) return 24 * 60;
    if (closeMinute > openMinute) return closeMinute - openMinute;
    return closeMinute + 24 * 60 - openMinute;
  }

  bool get closesAfterMidnight => closeMinute < openMinute;

  static int? parse(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    if (h > 23 || m > 59) return null;
    return h * 60 + m;
  }

  static String encode(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is DayHours && other.openMinute == openMinute && other.closeMinute == closeMinute;

  @override
  int get hashCode => Object.hash(openMinute, closeMinute);
}

enum OpenState { open, closed, temporarilyClosed, unavailable }

/// What to show a customer right now: e.g. "Open Now" + "Closes at 9:00 PM".
class OpenStatus {
  final OpenState state;
  final String headline;
  final String? detail;

  const OpenStatus(this.state, this.headline, [this.detail]);
}

class OperatingHours {
  /// Weekday (DateTime.monday = 1 … DateTime.sunday = 7) → hours.
  final Map<int, DayHours> days;
  final bool temporarilyClosed;
  final String? closureNote;

  const OperatingHours({this.days = const {}, this.temporarilyClosed = false, this.closureNote});

  static const Map<int, String> dayKeys = {
    1: 'mon', 2: 'tue', 3: 'wed', 4: 'thu', 5: 'fri', 6: 'sat', 7: 'sun',
  };
  static const Map<int, String> dayNames = {
    1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday',
  };
  static const Map<int, String> shortDayNames = {
    1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun',
  };

  /// Philippine Standard Time — UTC+8 all year.
  static const Duration manilaOffset = Duration(hours: 8);

  /// Whether the owner has set any opening hours at all.
  bool get hasHours => days.isNotEmpty;

  factory OperatingHours.fromFirestore(Map<String, dynamic> data) {
    final raw = data['operatingHours'];
    final days = <int, DayHours>{};
    if (raw is Map) {
      dayKeys.forEach((weekday, key) {
        final day = raw[key];
        if (day is! Map) return;
        final open = DayHours.parse(day['open']);
        final close = DayHours.parse(day['close']);
        if (open != null && close != null) days[weekday] = DayHours(open, close);
      });
    }
    final note = (data['closureNote'] as String?)?.trim();
    return OperatingHours(
      days: days,
      temporarilyClosed: (data['temporarilyClosed'] as bool?) ?? false,
      closureNote: (note == null || note.isEmpty) ? null : note,
    );
  }

  /// The `operatingHours` map to store (closed days left out).
  Map<String, dynamic> toFirestoreMap() => {
        for (final entry in days.entries)
          dayKeys[entry.key]!: {
            'open': DayHours.encode(entry.value.openMinute),
            'close': DayHours.encode(entry.value.closeMinute),
          },
      };

  OperatingHours copyWith({Map<int, DayHours>? days, bool? temporarilyClosed, String? closureNote}) =>
      OperatingHours(
        days: days ?? this.days,
        temporarilyClosed: temporarilyClosed ?? this.temporarilyClosed,
        closureNote: closureNote ?? this.closureNote,
      );

  /// The status at [now] (any time zone — converted to Manila time).
  OpenStatus statusAt(DateTime now) {
    if (temporarilyClosed) {
      final note = closureNote?.trim();
      return OpenStatus(OpenState.temporarilyClosed, 'Temporarily Closed', (note == null || note.isEmpty) ? null : note);
    }
    if (!hasHours) return const OpenStatus(OpenState.unavailable, 'Hours unavailable');

    final manila = now.toUtc().add(manilaOffset); // UTC fields = Manila wall clock
    final today = manila.weekday;
    final nowMinute = manila.hour * 60 + manila.minute;

    // Opening periods from yesterday (it may run past midnight into today)
    // through a week ahead, in minutes relative to today's midnight;
    // back-to-back periods are merged (e.g. open 24 hours every day).
    final periods = <List<int>>[];
    for (var offset = -1; offset <= 7; offset++) {
      final weekday = (today - 1 + offset) % 7 + 1;
      final hours = days[weekday];
      if (hours == null) continue;
      final start = offset * 1440 + hours.openMinute;
      periods.add([start, start + hours.durationMinutes]);
    }
    periods.sort((a, b) => a[0].compareTo(b[0]));
    final merged = <List<int>>[];
    for (final p in periods) {
      if (merged.isNotEmpty && p[0] <= merged.last[1]) {
        if (p[1] > merged.last[1]) merged.last[1] = p[1];
      } else {
        merged.add([p[0], p[1]]);
      }
    }

    for (final p in merged) {
      if (p[0] <= nowMinute && nowMinute < p[1]) {
        if (p[1] - p[0] >= 7 * 1440) return const OpenStatus(OpenState.open, 'Open Now', 'Open 24 hours');
        return OpenStatus(OpenState.open, 'Open Now', 'Closes ${_when(p[1], today, closing: true)}');
      }
    }
    for (final p in merged) {
      if (p[0] > nowMinute) {
        return OpenStatus(OpenState.closed, 'Closed Now', 'Opens ${_when(p[0], today, closing: false)}');
      }
    }
    return const OpenStatus(OpenState.closed, 'Closed Now');
  }

  /// "at 9:00 PM" / "tomorrow at 8:00 AM" / "Monday at 8:00 AM" for a
  /// time [minute]s after today's midnight.
  static String _when(int minute, int today, {required bool closing}) {
    final dayOffset = minute ~/ 1440;
    final time = formatTime(minute % 1440);
    // Closing just after midnight reads naturally without "tomorrow".
    if (dayOffset == 0 || (closing && dayOffset == 1)) return 'at $time';
    if (dayOffset == 1) return 'tomorrow at $time';
    return '${dayNames[(today - 1 + dayOffset) % 7 + 1]} at $time';
  }

  /// "8:00 AM", "12:30 PM", "12:00 AM".
  static String formatTime(int minute) {
    final h = minute ~/ 60;
    final m = (minute % 60).toString().padLeft(2, '0');
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12:$m ${h < 12 ? 'AM' : 'PM'}';
  }

  /// "8:00 AM – 9:00 PM", "Open 24 hours" or "Closed" for one weekday.
  String describeDay(int weekday) {
    final hours = days[weekday];
    if (hours == null) return 'Closed';
    if (hours.durationMinutes == 1440) return 'Open 24 hours';
    return '${formatTime(hours.openMinute)} – ${formatTime(hours.closeMinute)}';
  }
}
