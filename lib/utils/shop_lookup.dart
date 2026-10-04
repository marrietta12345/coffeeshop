import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/coffee_shop.dart';

/// Turns a stored shop id back into a full [CoffeeShop] from the `shops`
/// collection. Returns null if the shop no longer exists.
Future<CoffeeShop?> resolveShop(String shopId) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('shops').doc(shopId).get();
    if (doc.exists) return CoffeeShop.fromFirestore(doc);
  } catch (_) {
    // Shop may have been deleted — treat as unavailable.
  }
  return null;
}

/// Every shop a user can pick from: the real owner-created shops.
Future<List<CoffeeShop>> fetchAllShops() async {
  final shops = <CoffeeShop>[];
  try {
    final snap = await FirebaseFirestore.instance.collection('shops').get();
    shops.addAll(snap.docs.map(CoffeeShop.fromFirestore));
  } catch (_) {
    // Offline / rules issue — return what we have (nothing).
  }
  shops.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return shops;
}
