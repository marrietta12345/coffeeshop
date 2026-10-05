import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/menu_item.dart';
import '../models/review.dart';
import 'coffee_review_service.dart';

/// Profile → My Reviews: every review the signed-in customer has written,
/// across all cafés — café reviews (`shops/{id}/reviews/{uid}`) and coffee
/// reviews (`shops/{id}/coffeeReviews/{coffeeId}_{uid}`).
///
/// Uses collection-group queries filtered by `userId`, which need:
///   * the `{path=**}/reviews` and `{path=**}/coffeeReviews` read rules in
///     firestore.rules (own reviews only), and
///   * a collection-group index on `userId` for each (see
///     firestore.indexes.json → fieldOverrides).
/// Sorted newest first on the phone, so no composite index is needed.
class MyReviewsService {
  MyReviewsService._();

  static final _db = FirebaseFirestore.instance;

  static Stream<List<Review>> _mine(String collection) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collectionGroup(collection)
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) => CoffeeReviewService.newestFirst(snap.docs.map(Review.fromFirestore).toList()));
  }

  static Stream<List<Review>> cafeReviews() => _mine('reviews');

  static Stream<List<Review>> coffeeReviews() => _mine('coffeeReviews');

  /// The reviewed coffee as it is on the menu now, or null if the café
  /// removed it.
  static Future<MenuItem?> coffee(String shopId, String coffeeId) async {
    final doc = await _db.collection('shops').doc(shopId).collection('menu').doc(coffeeId).get();
    return doc.exists ? MenuItem.fromFirestore(doc) : null;
  }
}
