import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/menu_item.dart';
import 'supabase_image_service.dart';

/// Popular Coffee time ranges — only ones the stored like dates support.
enum PopularityPeriod {
  week('This Week', 7),
  month('This Month', 30),
  allTime('All Time', null);

  final String label;
  final int? days; // null = all time

  const PopularityPeriod(this.label, this.days);
}

/// One coffee's place in the Popular Coffee ranking.
class PopularCoffee {
  final MenuItem item;
  final int likes; // hearts within the chosen period

  const PopularCoffee(this.item, this.likes);
}

/// A shop's coffee menu, stored at `shops/{shopId}/menu/{itemId}`:
///   `name, description, price, category, available, bestSeller,
///    featured, imageUrl, likeCount, createdAt, updatedAt`
/// and customer hearts at `.../menu/{itemId}/likes/{uid}` = `{likedAt}` —
/// one per customer, kept in step with `likeCount` in the same write.
/// Photos go to the existing Supabase `best-sellers/` folder.
///
/// Anyone can read a menu (customers browse it); only the shop's owner can
/// add, edit or delete items, and owners can't heart their own coffee —
/// see the `menu` rules in firestore.rules.
class MenuService {
  MenuService._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _menu(String shopId) =>
      _db.collection('shops').doc(shopId).collection('menu');

  /// Live menu, newest first.
  static Stream<List<MenuItem>> menuStream(String shopId) {
    return _menu(shopId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(MenuItem.fromFirestore).toList());
  }

  /// Adds a new coffee (when [itemId] is null) or updates an existing one.
  /// [newImage] uploads a new photo; [removeImage] clears the current one.
  static Future<void> saveItem({
    required String shopId,
    String? itemId,
    required String name,
    required String description,
    required double price,
    required String category,
    required bool available,
    bool bestSeller = false,
    bool featured = false,
    String? currentImageUrl,
    File? newImage,
    bool removeImage = false,
  }) async {
    // A fixed id up front, so a retry after a failure updates the same
    // document instead of adding a duplicate.
    final ref = itemId == null ? _menu(shopId).doc() : _menu(shopId).doc(itemId);

    String? imageUrl = removeImage ? null : currentImageUrl;
    if (newImage != null) {
      imageUrl = await SupabaseImageService.uploadImage(
        file: newImage,
        folder: 'best-sellers',
        shopId: shopId,
        fileName: '${ref.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
    }

    final data = <String, dynamic>{
      'name': name.trim(),
      'description': description.trim(),
      'price': price,
      'category': category,
      'available': available,
      'bestSeller': bestSeller,
      'featured': featured,
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      if (itemId == null) {
        await ref.set({...data, 'likeCount': 0, 'createdAt': FieldValue.serverTimestamp()});
      } else {
        await ref.update(data);
      }
    } catch (_) {
      // Don't leave a just-uploaded photo behind if the save failed.
      if (newImage != null && imageUrl != null) _deleteImage(imageUrl);
      rethrow;
    }

    // Clean up the photo this item no longer uses.
    if (currentImageUrl != null && currentImageUrl.isNotEmpty && currentImageUrl != imageUrl) {
      _deleteImage(currentImageUrl);
    }
  }

  /// Quick Available / Unavailable switch from the menu list.
  static Future<void> setAvailable(String shopId, String itemId, bool available) {
    return _menu(shopId).doc(itemId).update({
      'available': available,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a coffee, its hearts, its coffee reviews and its photo.
  static Future<void> deleteItem(MenuItem item) async {
    final ref = _menu(item.shopId).doc(item.id);
    final likes = await ref.collection('likes').get();
    final reviews = await _db
        .collection('shops')
        .doc(item.shopId)
        .collection('coffeeReviews')
        .where('coffeeId', isEqualTo: item.id)
        .get();
    final batch = _db.batch();
    for (final like in likes.docs) {
      batch.delete(like.reference);
    }
    for (final review in reviews.docs) {
      batch.delete(review.reference);
    }
    batch.delete(ref);
    await batch.commit();
    if (item.hasImage) _deleteImage(item.imageUrl!);
  }

  static void _deleteImage(String url) {
    SupabaseImageService.deleteImageByUrl(url).catchError((Object e) {
      debugPrint('Menu photo cleanup failed: $e');
    });
  }

  // ------------------------------ Hearts ------------------------------

  /// Ids of the items in [items] the signed-in customer has hearted.
  static Future<Set<String>> likedItemIds(String shopId, List<MenuItem> items) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || items.isEmpty) return {};
    final snaps = await Future.wait([
      for (final item in items) _menu(shopId).doc(item.id).collection('likes').doc(uid).get(),
    ]);
    return {
      for (var i = 0; i < items.length; i++)
        if (snaps[i].exists) items[i].id,
    };
  }

  /// Hearts or un-hearts a coffee for the signed-in customer. Returns
  /// the new state (true = hearted).
  static Future<bool> toggleLike(MenuItem item) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to heart coffee.');
    final itemRef = _menu(item.shopId).doc(item.id);
    final likeRef = itemRef.collection('likes').doc(uid);
    return _db.runTransaction((tx) async {
      final like = await tx.get(likeRef);
      if (like.exists) {
        tx.delete(likeRef);
        tx.update(itemRef, {'likeCount': FieldValue.increment(-1)});
        return false;
      }
      tx.set(likeRef, {'likedAt': FieldValue.serverTimestamp()});
      tx.update(itemRef, {'likeCount': FieldValue.increment(1)});
      return true;
    });
  }

  // --------------------------- Popular Coffee ---------------------------

  /// Hearts per coffee in [period] (counted with count() queries — no
  /// customer details are downloaded), ranked most-hearted first. Coffees
  /// nobody hearted in the period are left out.
  static Future<List<PopularCoffee>> popular(String shopId, List<MenuItem> items, PopularityPeriod period) async {
    final days = period.days;
    List<int> counts;
    if (days == null) {
      counts = [for (final item in items) item.likes];
    } else {
      final start = Timestamp.fromDate(periodStart(days, DateTime.now()));
      counts = await Future.wait([
        for (final item in items)
          _menu(shopId)
              .doc(item.id)
              .collection('likes')
              .where('likedAt', isGreaterThanOrEqualTo: start)
              .count()
              .get()
              .then((snap) => snap.count ?? 0),
      ]);
    }
    return rankPopular([for (var i = 0; i < items.length; i++) PopularCoffee(items[i], counts[i])]);
  }

  /// Most hearts first; ties by name. Coffees with no hearts are dropped.
  static List<PopularCoffee> rankPopular(List<PopularCoffee> entries) {
    return entries.where((e) => e.likes > 0).toList()
      ..sort((a, b) {
        final byLikes = b.likes.compareTo(a.likes);
        return byLikes != 0 ? byLikes : a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
      });
  }

  /// Manila midnight [days] − 1 days ago — "This Week" is today plus the
  /// 6 days before (Philippine time, UTC+8).
  static DateTime periodStart(int days, DateTime now) {
    const manilaOffset = Duration(hours: 8);
    final manila = now.toUtc().add(manilaOffset);
    return DateTime.utc(manila.year, manila.month, manila.day - (days - 1)).subtract(manilaOffset);
  }
}
