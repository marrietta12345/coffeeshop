import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/menu_item.dart';
import '../models/review.dart';
import 'supabase_image_service.dart';

/// Reviews of a single coffee drink — separate from the café's own
/// reviews (ReviewService). Stored in one collection per café:
///
///   shops/{shopId}/coffeeReviews/{coffeeId}_{userId}
///     coffeeId, shopId, coffeeName, userId, userName, userPhotoUrl,
///     rating (1–5), text (optional), photoUrl (optional),
///     createdAt, updatedAt, ownerReply, ownerRepliedAt
///
/// The document id makes it one review per customer per coffee (posting
/// again edits it). A coffee's rating is worked out from its reviews.
/// Photos go to the existing Supabase `reviews/` folder. Who may write
/// what is enforced by the `coffeeReviews` rules in firestore.rules.
class CoffeeReviewService {
  CoffeeReviewService._();

  static CollectionReference<Map<String, dynamic>> _reviews(String shopId) =>
      FirebaseFirestore.instance.collection('shops').doc(shopId).collection('coffeeReviews');

  static String reviewId(String coffeeId, String userId) => '${coffeeId}_$userId';

  /// Live reviews of one coffee, newest first.
  static Stream<List<Review>> coffeeReviewsStream(String shopId, String coffeeId) {
    return _reviews(shopId)
        .where('coffeeId', isEqualTo: coffeeId)
        .snapshots()
        .map((snap) => newestFirst(snap.docs.map(Review.fromFirestore).toList()));
  }

  /// Live reviews of every coffee at a café, newest first (owner's Reviews tab).
  static Stream<List<Review>> shopCoffeeReviewsStream(String shopId) {
    return _reviews(shopId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Review.fromFirestore).toList());
  }

  static List<Review> newestFirst(List<Review> reviews) =>
      reviews..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

  /// Posts or updates the signed-in customer's review of [coffee].
  /// [photo] attaches a new photo; [keepExistingPhoto] keeps the one from
  /// their earlier review; neither = no photo.
  static Future<void> submitReview({
    required MenuItem coffee,
    required int rating,
    required String text,
    File? photo,
    bool keepExistingPhoto = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in to review this coffee.');
    final ref = _reviews(coffee.shopId).doc(reviewId(coffee.id, user.uid));
    final previous = await ref.get();
    final previousPhoto = previous.data()?['photoUrl'] as String?;

    String? photoUrl;
    if (photo != null) {
      photoUrl = await SupabaseImageService.uploadImage(
        file: photo,
        folder: 'reviews',
        shopId: coffee.shopId,
        fileName: 'coffee_${coffee.id}_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
    } else if (keepExistingPhoto) {
      photoUrl = previousPhoto;
    }

    try {
      await ref.set({
        'coffeeId': coffee.id,
        'shopId': coffee.shopId,
        'coffeeName': coffee.name,
        'userId': user.uid,
        'userName': (user.displayName?.trim().isNotEmpty ?? false) ? user.displayName!.trim() : 'Coffee Lover',
        'userPhotoUrl': (user.photoURL?.isNotEmpty ?? false) ? user.photoURL : null,
        'rating': rating.clamp(1, 5),
        'text': text.trim(),
        'photoUrl': photoUrl,
        // An edit keeps the original date; the review moves to "updated".
        'createdAt': previous.exists ? previous.data()!['createdAt'] : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (photo != null && photoUrl != null) _deletePhoto(photoUrl);
      rethrow;
    }

    if (previousPhoto != null && previousPhoto.isNotEmpty && previousPhoto != photoUrl) _deletePhoto(previousPhoto);
  }

  /// Deletes the signed-in customer's own review (and its photo).
  static Future<void> deleteMyReview(Review review) async {
    await _reviews(review.shopId).doc(review.id).delete();
    if (review.hasPhoto) _deletePhoto(review.photoUrl!);
  }

  /// The café owner's response to a coffee review (add or edit).
  static Future<void> replyToReview({
    required String shopId,
    required String reviewId,
    required String reply,
    bool firstReply = false,
  }) {
    return _reviews(shopId).doc(reviewId).update(_replyFields(reply, firstReply: firstReply));
  }

  /// The owner's response: [reply], who wrote it (their uid — for security,
  /// never shown) and when. [firstReply] also records when it was first
  /// written; an edit keeps that date.
  static Map<String, dynamic> _replyFields(String reply, {required bool firstReply}) => {
        'ownerReply': reply.trim(),
        'ownerReplyBy': FirebaseAuth.instance.currentUser?.uid,
        'ownerRepliedAt': FieldValue.serverTimestamp(),
        if (firstReply) 'ownerReplyCreatedAt': FieldValue.serverTimestamp(),
      };

  static Map<String, dynamic> get _noReply => {
    'ownerReply': FieldValue.delete(),
    'ownerReplyBy': FieldValue.delete(),
    'ownerRepliedAt': FieldValue.delete(),
    'ownerReplyCreatedAt': FieldValue.delete(),
  };


  static Future<void> deleteReply({required String shopId, required String reviewId}) {
    return _reviews(shopId).doc(reviewId).update(_noReply);
  }

  static void _deletePhoto(String url) {
    SupabaseImageService.deleteImageByUrl(url).catchError((Object e) {
      debugPrint('Coffee review photo cleanup failed: $e');
    });
  }
}
