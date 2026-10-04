import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Persists "saved" (favorited) shops per signed-in user, under
/// `users/{uid}/savedShops/{shopId}` (see `firestore.rules`).
class SavedShopsService {
  SavedShopsService._();

  static CollectionReference<Map<String, dynamic>>? _collection() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('savedShops');
  }

  /// Toggles saved state for a shop. Returns the new saved state (true =
  /// now saved, false = now removed).
  static Future<bool> toggleSaved(String shopId, String shopName) async {
    final col = _collection();
    if (col == null) return false;

    final doc = col.doc(shopId);
    final snapshot = await doc.get();

    if (snapshot.exists) {
      await doc.delete();
      return false;
    } else {
      await doc.set({
        'shopId': shopId,
        'shopName': shopName,
        'savedAt': FieldValue.serverTimestamp(),
      });
      return true;
    }
  }

  static Future<bool> isSaved(String shopId) async {
    final col = _collection();
    if (col == null) return false;
    final doc = await col.doc(shopId).get();
    return doc.exists;
  }

  /// Live stream of saved shop IDs — updates instantly across the app
  /// whenever a heart is tapped anywhere.
  static Stream<Set<String>> savedShopIdsStream() {
    final col = _collection();
    if (col == null) return Stream.value(<String>{});
    return col.snapshots().map((snap) => snap.docs.map((d) => d.id).toSet());
  }
}