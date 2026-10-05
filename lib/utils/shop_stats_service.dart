import 'package:cloud_firestore/cloud_firestore.dart';

/// Denormalized, real-time shop stats — kept as simple atomic counters on
/// the shop's own document rather than expensive aggregation queries.
/// This is a standard Firestore pattern: cheap to read (it's just a field
/// on a doc you're already fetching), and avoids needing broad read
/// access across other users' private data to compute a count.
class ShopStatsService {
  ShopStatsService._();

  static final _shops = FirebaseFirestore.instance.collection('shops');

  /// Adjusts the favorites counter by +1 or -1 when a customer
  /// saves/unsaves this shop.
  static Future<void> adjustFavoritesCount(String shopId, int delta) async {
    try {
      await _shops.doc(shopId).set(
        {'favoritesCount': FieldValue.increment(delta)},
        SetOptions(merge: true),
      );
    } catch (_) {
      // Non-critical — the user's saved-shops list is still correct even
      // if this denormalized counter update fails.
    }
  }
}