import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/operating_hours.dart';

/// Time periods for the owner's Activity Summary.
enum ActivityPeriod {
  today('Today', 'Today', 1),
  week('7 Days', 'Last 7 Days', 7),
  month('30 Days', 'Last 30 Days', 30);

  final String label; // filter chip
  final String title; // "Activity — Last 7 Days"
  final int days;

  const ActivityPeriod(this.label, this.title, this.days);

  /// When this period starts: Manila midnight today for [today], or Manila
  /// midnight 6 / 29 days ago — so "7 Days" is today plus the 6 days before.
  DateTime startAt(DateTime now) {
    final manila = now.toUtc().add(OperatingHours.manilaOffset); // UTC fields = Manila wall clock
    final midnight = DateTime.utc(manila.year, manila.month, manila.day - (days - 1));
    return midnight.subtract(OperatingHours.manilaOffset);
  }
}

/// Aggregated engagement numbers for one shop over one [ActivityPeriod].
class ActivitySummary {
  final int profileViews; // unique users who viewed during the period
  final int favorites; // users who added the café to Favorites
  final int newReviews;
  final int collectionSaves; // users who saved the café to a collection
  final int reviewsToRespond; // all-time reviews without an owner reply

  const ActivitySummary({
    required this.profileViews,
    required this.favorites,
    required this.newReviews,
    required this.collectionSaves,
    required this.reviewsToRespond,
  });
}

/// Per-user engagement with a shop, stored as ONE document per user per
/// shop at `shops/{shopId}/activity/{uid}`:
///   `firstViewedAt`     first time the user opened the café page
///   `lastViewedAt`      latest day they opened it (written at most once a day)
///   `favoritedAt`       when they hearted it (removed when un-hearted)
///   `collectionSavedAt` when they first saved it to any collection
///                       (removed when it's in none of their collections)
///
/// Because each user has a single document, repeat views, refreshes and
/// re-taps never add extra entries — the owner's dashboard counts these
/// documents with Firestore count() queries rather than reading a feed
/// of individual activities. Only the shop's owner (and the user
/// themselves) can read them — see the `activity` rule in firestore.rules.
class ShopActivityService {
  ShopActivityService._();

  static final _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _shopDoc(String shopId) => _db.collection('shops').doc(shopId);

  static CollectionReference<Map<String, dynamic>> _activity(String shopId) =>
      _shopDoc(shopId).collection('activity');

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Records a profile view by the signed-in user. The shop's all-time
  /// `viewCount` goes up only on a user's first ever view, so it counts
  /// unique viewers. Call it when a customer (not the owner) opens the page.
  static Future<void> recordView(String shopId) async {
    final uid = _uid;
    if (uid == null) return;
    final ref = _activity(shopId).doc(uid);
    try {
      await _db.runTransaction((tx) async {
        final data = (await tx.get(ref)).data();
        if (data?['firstViewedAt'] == null) {
          tx.set(ref, {
            'firstViewedAt': FieldValue.serverTimestamp(),
            'lastViewedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          tx.update(_shopDoc(shopId), {'viewCount': FieldValue.increment(1)});
          return;
        }
        final last = (data!['lastViewedAt'] as Timestamp?)?.toDate();
        if (needsViewUpdate(last, DateTime.now())) {
          tx.update(ref, {'lastViewedAt': FieldValue.serverTimestamp()});
        }
      });
    } catch (e) {
      // Non-critical — a missed view shouldn't disrupt browsing.
      debugPrint('View tracking skipped: $e');
    }
  }

  /// Whether a returning viewer's `lastViewedAt` needs bumping: only when
  /// their last recorded view was before today (Manila time). Repeat views
  /// on the same day change nothing.
  static bool needsViewUpdate(DateTime? lastViewedAt, DateTime now) =>
      lastViewedAt == null || lastViewedAt.isBefore(ActivityPeriod.today.startAt(now));

  /// Marks the shop as hearted (or no longer hearted) by the signed-in user.
  static Future<void> setFavorited(String shopId, bool favorited) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _activity(shopId).doc(uid).set(
        {'favoritedAt': favorited ? FieldValue.serverTimestamp() : FieldValue.delete()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Favorite activity skipped: $e');
    }
  }

  /// Brings `collectionSavedAt` in line with the signed-in user's
  /// collections for each of [shopIds]: set when the café is in at least
  /// one collection (kept if already set), removed when it's in none.
  static Future<void> syncCollectionSaves(Iterable<String> shopIds) async {
    final uid = _uid;
    if (uid == null) return;
    final collections = _db.collection('users').doc(uid).collection('collections');
    for (final shopId in shopIds.toSet()) {
      try {
        final inAny = (await collections.where('shopIds', arrayContains: shopId).limit(1).get()).docs.isNotEmpty;
        final ref = _activity(shopId).doc(uid);
        final alreadySaved = (await ref.get()).data()?['collectionSavedAt'] != null;
        if (inAny && !alreadySaved) {
          await ref.set({'collectionSavedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        } else if (!inAny && alreadySaved) {
          await ref.update({'collectionSavedAt': FieldValue.delete()});
        }
      } catch (e) {
        debugPrint('Collection activity skipped for $shopId: $e');
      }
    }
  }

  /// Aggregated counts for the owner's dashboard — count() queries only,
  /// so no individual users are downloaded, however many there are.
  static Future<ActivitySummary> summary(String shopId, ActivityPeriod period) async {
    final start = Timestamp.fromDate(period.startAt(DateTime.now()));
    final activity = _activity(shopId);
    final reviews = _shopDoc(shopId).collection('reviews');

    Future<int> count(Query<Map<String, dynamic>> query) async => (await query.count().get()).count ?? 0;

    final results = await Future.wait([
      count(activity.where('lastViewedAt', isGreaterThanOrEqualTo: start)),
      count(activity.where('favoritedAt', isGreaterThanOrEqualTo: start)),
      count(reviews.where('createdAt', isGreaterThanOrEqualTo: start)),
      count(activity.where('collectionSavedAt', isGreaterThanOrEqualTo: start)),
      count(reviews),
      // A range filter skips documents without the field, so this counts
      // only reviews that have an owner reply.
      count(reviews.where('ownerRepliedAt', isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(0))),
    ]);

    return ActivitySummary(
      profileViews: results[0],
      favorites: results[1],
      newReviews: results[2],
      collectionSaves: results[3],
      reviewsToRespond: (results[4] - results[5]).clamp(0, results[4]),
    );
  }
}
