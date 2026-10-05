import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shop_collection.dart';
import 'shop_activity_service.dart';

/// The user's collections, stored under `users/{uid}/collections/`:
///  * the 8 built-in categories — doc id = category id, `{name, shopIds}`,
///    created when the user picks it in Create Collection or first saves
///    a café to it (only then is it shown);
///  * custom collections the user creates — auto id,
///    `{name, icon, shopIds, custom: true, createdAt}`.
/// Covered by the `users/{userId}/collections` rule in firestore.rules.
class CollectionsService {
  CollectionsService._();

  /// The signed-in user's collections, for writes that must not silently
  /// do nothing when signed out.
  static CollectionReference<Map<String, dynamic>> _requireCollection() {
    final col = _collection();
    if (col == null) throw StateError('Sign in to manage collections.');
    return col;
  }

  static CollectionReference<Map<String, dynamic>>? _collection() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('collections');
  }

  /// The 8 built-in categories in their fixed order — with [ShopCollection.exists]
  /// false for ones the user hasn't started — followed by the user's
  /// custom collections, oldest first. Screens show only `exists` ones.
  static Stream<List<ShopCollection>> collectionsStream() {
    final col = _collection();
    final empty = [for (final c in CollectionCategory.all) ShopCollection.empty(c)];
    if (col == null) return Stream.value(empty);
    _migrateOnce(col);
    return col.snapshots().map((snap) {
      final all = snap.docs.map(ShopCollection.fromFirestore).toList();
      final byId = {for (final c in all) c.id: c};
      final custom = all.where((c) => c.isCustom).toList()
        ..sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));
      return [
        for (final c in CollectionCategory.all)
          ShopCollection(
            id: c.id,
            name: c.name,
            shopIds: byId[c.id]?.shopIds ?? const [],
            exists: byId.containsKey(c.id),
          ),
        ...custom,
      ];
    });
  }

  /// Live stream of one collection. Built-in categories are always there
  /// (empty if nothing saved); a custom collection emits null once deleted.
  static Stream<ShopCollection?> collectionStream(String collectionId) {
    final category = CollectionCategory.byId(collectionId);
    final col = _collection();
    if (col == null) {
      return Stream.value(category == null ? null : ShopCollection.empty(category));
    }
    return col.doc(collectionId).snapshots().map((snap) {
      if (category != null) {
        final ids = (snap.data()?['shopIds'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
        return ShopCollection(id: collectionId, name: category.name, shopIds: ids, exists: snap.exists);
      }
      return snap.exists ? ShopCollection.fromFirestore(snap) : null;
    });
  }

  /// Saves [shopId] to a collection (creating a category's document if
  /// needed).
  static Future<void> addShop(String collectionId, String shopId) async {
    await _collection()?.doc(collectionId).set({
      ..._nameFor(collectionId),
      'shopIds': FieldValue.arrayUnion([shopId]),
    }, SetOptions(merge: true));
    ShopActivityService.syncCollectionSaves([shopId]);
  }

  static Future<void> removeShop(String collectionId, String shopId) async {
    await _collection()?.doc(collectionId).set({
      ..._nameFor(collectionId),
      'shopIds': FieldValue.arrayRemove([shopId]),
    }, SetOptions(merge: true));
    ShopActivityService.syncCollectionSaves([shopId]);
  }

  /// Built-in categories always (re)write their fixed name so their doc
  /// is valid when first created; custom collections already have one.
  static Map<String, dynamic> _nameFor(String collectionId) {
    final category = CollectionCategory.byId(collectionId);
    return category == null ? const {} : {'name': category.name};
  }

  /// Creates a custom collection, optionally starting with [shopIds].
  static Future<void> createCustom({
    required String name,
    required String iconKey,
    List<String> shopIds = const [],
  }) async {
    await _requireCollection().add({
      'name': name,
      'icon': iconKey,
      'shopIds': shopIds,
      'custom': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    ShopActivityService.syncCollectionSaves(shopIds);
  }

  /// Starts a built-in category (from Create Collection), optionally with
  /// [shopIds] already saved in it.
  static Future<void> createCategory(String categoryId, {List<String> shopIds = const []}) async {
    final category = CollectionCategory.byId(categoryId);
    if (category == null) return;
    final doc = _requireCollection().doc(categoryId);
    if (!(await doc.get()).exists) {
      await doc.set({'name': category.name, 'shopIds': shopIds});
    } else if (shopIds.isNotEmpty) {
      await doc.set({'name': category.name, 'shopIds': FieldValue.arrayUnion(shopIds)}, SetOptions(merge: true));
    }
    ShopActivityService.syncCollectionSaves(shopIds);
  }

  static Future<void> updateCustom(String collectionId, {required String name, required String iconKey}) async {
    if (CollectionCategory.byId(collectionId) != null) return; // built-ins are fixed
    await _requireCollection().doc(collectionId).update({'name': name, 'icon': iconKey});
  }

  /// Removes a collection from the user's list (a built-in category just
  /// goes back to being an unused suggestion).
  static Future<void> deleteCollection(String collectionId) async {
    final doc = _collection()?.doc(collectionId);
    if (doc == null) return;
    final shopIds = (((await doc.get()).data()?['shopIds'] as List?) ?? const []).map((e) => e.toString());
    await doc.delete();
    ShopActivityService.syncCollectionSaves(shopIds);
  }

  static final Set<String> _migratedUsers = {};

  /// One-time tidy-up of collections made before the fixed categories:
  /// cafés in an old collection whose name matches a category (e.g. "Want
  /// to Visit") move into that category; old "My Favorites" collections
  /// are removed (Favorites is its own feature). Other old collections
  /// stay and show up as custom collections.
  static Future<void> _migrateOnce(CollectionReference<Map<String, dynamic>> col) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !_migratedUsers.add(uid)) return;
    try {
      final snap = await col.get();
      for (final doc in snap.docs) {
        if (CollectionCategory.byId(doc.id) != null) continue; // already a category
        final name = ((doc.data()['name'] as String?) ?? '').trim().toLowerCase();
        if (name == 'my favorites' || name == 'my favourites') {
          await doc.reference.delete();
          continue;
        }
        CollectionCategory? match;
        for (final c in CollectionCategory.all) {
          if (c.name.toLowerCase() == name) match = c;
        }
        if (match == null) continue;
        final ids = (doc.data()['shopIds'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
        if (ids.isNotEmpty) {
          await col.doc(match.id).set({
            'name': match.name,
            'shopIds': FieldValue.arrayUnion(ids),
          }, SetOptions(merge: true));
        }
        await doc.reference.delete();
      }
    } catch (e) {
      _migratedUsers.remove(uid); // try again next time
      debugPrint('Collections migration skipped: $e');
    }
  }
}
