import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cafe_journey.dart';
import '../models/coffee_shop.dart';
import 'user_role.dart';

export '../models/cafe_journey.dart' show VisitedShop, CafeDiscovery, CafeJourney;

/// Visited Cafés storage, all on the user's own `users/{uid}` document so
/// the existing `users/{userId}` Firestore rule covers it:
///
/// * `visitedShops.{shopId}` — visit history (name, address, last
///   `visitedAt`, `visitCount`). One entry per café; visiting again just
///   bumps it. The user can remove entries.
/// * `discoveredCafes.{shopId}` — permanent first-visit log
///   (`discoveredAt`), never removed, so the discovered count never
///   resets. Daily Discovery and the streak are computed from it.
/// * `totalVisits` — permanent running total of café visits.
class VisitedShopsService {
  VisitedShopsService._();

  static const String _history = 'visitedShops';
  static const String _discoveries = 'discoveredCafes';
  static const String _legacyDiscoveries = 'cafePassport'; // earlier name

  static DocumentReference<Map<String, dynamic>>? _userDoc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection(usersCollection).doc(uid);
  }

  static bool _isDiscovered(Map<String, dynamic> data, String shopId) {
    bool has(String field) => data[field] is Map && (data[field] as Map).containsKey(shopId);
    return has(_discoveries) || has(_legacyDiscoveries);
  }

  /// Records a visit to [shop] (called when its details are opened) and
  /// logs it as a discovery if it's the user's first time there.
  /// Returns true when this was a brand-new discovery.
  static Future<bool> recordVisit(CoffeeShop shop) async {
    final doc = _userDoc();
    if (doc == null) return false;
    try {
      final data = (await doc.get()).data() ?? const <String, dynamic>{};
      final history = data[_history];
      final alreadyDiscovered = _isDiscovered(data, shop.id);
      final legacyVisit = history is Map ? history[shop.id] : null;
      final isNewDiscovery = !alreadyDiscovered && legacyVisit == null;

      await doc.set({
        // Nested maps deep-merge, so this only touches this one café.
        _history: {
          shop.id: {
            'shopName': shop.name,
            'address': shop.address,
            'visitedAt': FieldValue.serverTimestamp(),
            'visitCount': FieldValue.increment(1),
          },
        },
        // Start the permanent counter from existing history the first time.
        'totalVisits': data['totalVisits'] == null
            ? _sumVisits(history) + 1
            : FieldValue.increment(1),
        if (!alreadyDiscovered)
          _discoveries: {
            shop.id: {
              'shopName': shop.name,
              // A café visited before discoveries were logged keeps its
              // original date instead of counting as today's discovery.
              'discoveredAt': (legacyVisit is Map ? legacyVisit['visitedAt'] : null) ??
                  FieldValue.serverTimestamp(),
            },
          },
      }, SetOptions(merge: true));
      return isNewDiscovery;
    } catch (e) {
      // Non-critical — a missed history entry shouldn't disrupt browsing.
      debugPrint('Visited Cafés: could not record visit to ${shop.id}: $e');
      return false;
    }
  }

  /// Removes [shopId] from the visible history only — it still counts as
  /// discovered, so the total never goes down.
  static Future<void> removeVisit(String shopId) async {
    final doc = _userDoc();
    if (doc == null) return;
    final data = (await doc.get()).data() ?? const <String, dynamic>{};
    final visit = (data[_history] is Map) ? (data[_history] as Map)[shopId] : null;
    final needsDiscovery = !_isDiscovered(data, shopId) && visit is Map;

    await doc.update({
      FieldPath([_history, shopId]): FieldValue.delete(),
      // Visits from before discoveries were logged only live in the
      // history, so log them before the history entry goes away.
      if (needsDiscovery)
        FieldPath([_discoveries, shopId]): {
          'shopName': visit['shopName'] ?? '',
          'discoveredAt': visit['visitedAt'] ?? FieldValue.serverTimestamp(),
        },
    });
  }

  /// Live visited-café data — history, discoveries, streak, daily progress.
  static Stream<CafeJourney> journeyStream() {
    final doc = _userDoc();
    if (doc == null) return Stream.value(const CafeJourney());
    return doc.snapshots().map((snap) => CafeJourney.fromUserData(snap.data()));
  }

  static int _sumVisits(Object? history) {
    if (history is! Map) return 0;
    var sum = 0;
    for (final value in history.values) {
      if (value is Map) sum += (value['visitCount'] as num?)?.toInt() ?? 1;
    }
    return sum;
  }
}
