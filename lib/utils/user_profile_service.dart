import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_role.dart';

/// Reads and writes the signed-in user's own `users/{uid}` document —
/// profile fields (fullName, username, photoUrl), notificationSettings
/// and coffeePreferences all live there alongside the existing `role`.
class UserProfileService {
  UserProfileService._();

  static DocumentReference<Map<String, dynamic>>? _doc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection(usersCollection).doc(uid);
  }

  /// Live stream of the user's profile data (empty map if signed out or
  /// the document doesn't exist yet).
  static Stream<Map<String, dynamic>> profileStream() {
    final doc = _doc();
    if (doc == null) return Stream.value(const {});
    return doc.snapshots().map((snap) => snap.data() ?? const {});
  }

  static Future<Map<String, dynamic>> fetchProfile() async {
    final doc = _doc();
    if (doc == null) return const {};
    final snap = await doc.get();
    return snap.data() ?? const {};
  }

  /// Merges [fields] into the user's document. Nested maps (e.g.
  /// `{'notificationSettings': {'general': false}}`) are deep-merged, so
  /// writing one toggle never wipes the others.
  static Future<void> update(Map<String, dynamic> fields) async {
    final doc = _doc();
    if (doc == null) return;
    await doc.set(fields, SetOptions(merge: true));
  }
}
