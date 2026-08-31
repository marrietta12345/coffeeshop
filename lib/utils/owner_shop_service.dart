import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/coffee_shop.dart';

/// Finds the shop belonging to the currently signed-in Coffee Shop Owner.
/// Assumes one shop per owner account, matching how Business Sign Up
/// creates exactly one `shops` document per owner.
class OwnerShopService {
  OwnerShopService._();

  static CollectionReference<Map<String, dynamic>> get _shops =>
      FirebaseFirestore.instance.collection('shops');

  /// Live stream of the owner's shop — updates instantly whenever the
  /// shop doc changes (e.g. after editing hours, uploading photos, etc.).
  static Stream<CoffeeShop?> myShopStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _shops
        .where('ownerId', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : CoffeeShop.fromFirestore(snap.docs.first));
  }

  static Future<CoffeeShop?> fetchMyShop() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final snap = await _shops.where('ownerId', isEqualTo: uid).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return CoffeeShop.fromFirestore(snap.docs.first);
  }
}