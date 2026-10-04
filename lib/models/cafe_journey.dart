import 'package:cloud_firestore/cloud_firestore.dart';

/// One entry in the user's Visited Cafés history.
class VisitedShop {
  final String shopId;
  final String shopName;
  final String address;
  final DateTime? visitedAt; // last time the café was visited
  final int visitCount;

  const VisitedShop({
    required this.shopId,
    required this.shopName,
    required this.address,
    this.visitedAt,
    this.visitCount = 1,
  });
}

/// The first time a user visited a café. Kept permanently — removing a
/// café from the visible history never removes its discovery — so the
/// discovered count never goes down.
class CafeDiscovery {
  final String shopId;
  final String shopName;
  final DateTime discoveredAt;

  const CafeDiscovery({required this.shopId, required this.shopName, required this.discoveredAt});
}

/// Everything the Visited Cafés page shows, derived from the user's
/// `users/{uid}` document: `visitedShops` (history), `discoveredCafes`
/// (permanent first-visit log) and `totalVisits`.
///
/// Daily Discovery and the streak are computed from discovery dates
/// rather than stored, so "today" rolls over on its own at local
/// midnight and can never drift out of sync.
class CafeJourney {
  final List<VisitedShop> history; // most recent first
  final List<CafeDiscovery> discoveries; // newest first
  final int totalVisits;

  const CafeJourney({
    this.history = const [],
    this.discoveries = const [],
    this.totalVisits = 0,
  });

  /// Daily Discovery goal: one new café a day.
  static const int dailyGoal = 1;

  int get cafesDiscovered => discoveries.length;

  Set<String> get discoveredIds => {for (final d in discoveries) d.shopId};

  /// New cafés discovered today (local time).
  int get discoveredToday {
    final today = _dayIndex(DateTime.now());
    return discoveries.where((d) => _dayIndex(d.discoveredAt) == today).length;
  }

  bool get dailyGoalReached => discoveredToday >= dailyGoal;

  /// Consecutive days with at least one new café, ending today — or
  /// ending yesterday, since today isn't over yet and the streak is still
  /// alive until midnight.
  int get currentStreak {
    final days = {for (final d in discoveries) _dayIndex(d.discoveredAt)};
    final today = _dayIndex(DateTime.now());
    var day = days.contains(today) ? today : today - 1;
    var streak = 0;
    while (days.contains(day)) {
      streak++;
      day--;
    }
    return streak;
  }

  /// Streak is alive but needs a discovery today to continue past midnight.
  bool get streakAtRisk => currentStreak > 0 && discoveredToday == 0;

  /// Whole days since the epoch for [d]'s local calendar date (DST-safe).
  static int _dayIndex(DateTime d) {
    final local = d.toLocal();
    return DateTime.utc(local.year, local.month, local.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  factory CafeJourney.fromUserData(Map<String, dynamic>? data) {
    data ??= const {};

    // Pending server timestamps read as null for a write made a moment
    // ago — treat them as "now".
    DateTime readTime(Object? value) => (value as Timestamp?)?.toDate() ?? DateTime.now();

    final history = <VisitedShop>[];
    final rawHistory = data['visitedShops'];
    if (rawHistory is Map) {
      rawHistory.forEach((key, value) {
        if (value is! Map) return;
        history.add(VisitedShop(
          shopId: key.toString(),
          shopName: (value['shopName'] as String?) ?? '',
          address: (value['address'] as String?) ?? '',
          visitedAt: readTime(value['visitedAt']),
          visitCount: (value['visitCount'] as num?)?.toInt() ?? 1,
        ));
      });
    }
    history.sort((a, b) => b.visitedAt!.compareTo(a.visitedAt!));

    final byId = <String, CafeDiscovery>{};
    // `cafePassport` is the field name an earlier version used for the
    // same first-visit log — still read so nobody's count drops.
    for (final field in const ['discoveredCafes', 'cafePassport']) {
      final raw = data[field];
      if (raw is! Map) continue;
      raw.forEach((key, value) {
        if (value is! Map) return;
        byId.putIfAbsent(
          key.toString(),
          () => CafeDiscovery(
            shopId: key.toString(),
            shopName: (value['shopName'] as String?) ?? '',
            discoveredAt: readTime(value['discoveredAt']),
          ),
        );
      });
    }
    // Cafés visited before discoveries were logged still count.
    for (final visit in history) {
      byId.putIfAbsent(
        visit.shopId,
        () => CafeDiscovery(shopId: visit.shopId, shopName: visit.shopName, discoveredAt: visit.visitedAt!),
      );
    }
    final discoveries = byId.values.toList()..sort((a, b) => b.discoveredAt.compareTo(a.discoveredAt));

    final historyVisits = history.fold<int>(0, (total, v) => total + v.visitCount);
    final storedVisits = (data['totalVisits'] as num?)?.toInt() ?? 0;

    return CafeJourney(
      history: history,
      discoveries: discoveries,
      totalVisits: storedVisits > historyVisits ? storedVisits : historyVisits,
    );
  }
}
