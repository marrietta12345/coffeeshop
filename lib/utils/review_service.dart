import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/coffee_shop.dart';
import '../models/review.dart';
import 'supabase_image_service.dart';

/// Customer reviews, stored per shop at `shops/{shopId}/reviews/{uid}` —
/// one review per user per shop, so a user can review as many different
/// shops as they like and each review stays attached to its own shop.
/// Posting again for the same shop updates that review.
///
/// The shop document keeps `ratingSum`, `reviewCount` and the average
/// `rating` in step with its reviews, so the rating shown everywhere else
/// (cards, Popular Coffee Shops, owner dashboard) reflects real reviews.
///
/// Allowed by the reviews and rating-totals rules in `firestore.rules`,
/// which require the review and the shop totals to change together.
class ReviewService {
  ReviewService._();

  static DocumentReference<Map<String, dynamic>> _shopDoc(String shopId) =>
      FirebaseFirestore.instance.collection('shops').doc(shopId);

  static CollectionReference<Map<String, dynamic>> _reviews(String shopId) =>
      _shopDoc(shopId).collection('reviews');

  /// Live reviews for [shopId], newest first ([limit] = only the latest).
  static Stream<List<Review>> reviewsStream(String shopId, {int? limit}) {
    var query = _reviews(shopId).orderBy('createdAt', descending: true);
    if (limit != null) query = query.limit(limit);
    return query
        .snapshots()
        .map((snap) => snap.docs.map(Review.fromFirestore).toList());
  }

  /// The signed-in user's existing review of [shopId], if any.
  static Future<Review?> myReview(String shopId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _reviews(shopId).doc(uid).get();
    return doc.exists ? Review.fromFirestore(doc) : null;
  }

  /// Saves the shop owner's response to a review (replacing an earlier
  /// one). Only the shop's owner may do this — see firestore.rules.
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


  /// Removes the owner's response from a review (it shows as Needs Reply
  /// again).
  static Future<void> deleteReply({required String shopId, required String reviewId}) {
    return _reviews(shopId).doc(reviewId).update(_noReply);
  }

  /// The shop owner's private "appreciate" heart on a review (not a public
  /// like count). Only the shop's owner may set it — see firestore.rules.
  static Future<void> setOwnerHeart({required String shopId, required String reviewId, required bool hearted}) {
    return _reviews(shopId).doc(reviewId).update({
      'ownerHearted': hearted ? true : FieldValue.delete(),
    });
  }

  /// Posts (or updates) the signed-in user's review of [shop].
  ///
  /// [photo] is optional: pass a new file to attach it; leave it null and
  /// set [keepExistingPhoto] to keep a photo from an earlier version of
  /// this review, or leave both off to post without a photo.
  static Future<void> submitReview({
    required CoffeeShop shop,
    required double rating,
    required String text,
    File? photo,
    bool keepExistingPhoto = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in to post a review.');

    final reviewRef = _reviews(shop.id).doc(user.uid);
    final shopRef = _shopDoc(shop.id);
    final previous = await reviewRef.get();
    final previousPhoto = previous.data()?['photoUrl'] as String?;

    // Upload first, so a failed upload never leaves a half-saved review.
    String? photoUrl;
    if (photo != null) {
      photoUrl = await SupabaseImageService.uploadImage(
        file: photo,
        folder: 'reviews',
        shopId: shop.id,
        fileName: '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
    } else if (keepExistingPhoto) {
      photoUrl = previousPhoto;
    }

    try {
      await _saveReview(shop: shop, user: user, reviewRef: reviewRef, shopRef: shopRef, rating: rating, text: text, photoUrl: photoUrl);
    } catch (_) {
      // Don't leave a just-uploaded photo behind if the save failed.
      if (photo != null && photoUrl != null) {
        SupabaseImageService.deleteImageByUrl(photoUrl).catchError((Object e) {
          debugPrint('Review photo cleanup failed: $e');
        });
      }
      rethrow;
    }

    // Clean up a photo this review no longer uses.
    if (previousPhoto != null && previousPhoto.isNotEmpty && previousPhoto != photoUrl) {
      SupabaseImageService.deleteImageByUrl(previousPhoto).catchError((Object e) {
        debugPrint('Review photo cleanup failed: $e');
      });
    }
  }

  /// Writes the review and keeps the shop's rating fields in step, in one
  /// transaction so concurrent reviews can't skew the average.
  static Future<void> _saveReview({
    required CoffeeShop shop,
    required User user,
    required DocumentReference<Map<String, dynamic>> reviewRef,
    required DocumentReference<Map<String, dynamic>> shopRef,
    required double rating,
    required String text,
    required String? photoUrl,
  }) {
    return FirebaseFirestore.instance.runTransaction((tx) async {
      final oldReview = await tx.get(reviewRef);
      final shopSnap = await tx.get(shopRef);
      final shopData = shopSnap.data() ?? const <String, dynamic>{};

      final totals = updatedRatingTotals(
        ratingSum: (shopData['ratingSum'] as num?)?.toDouble() ?? 0,
        reviewCount: (shopData['reviewCount'] as num?)?.toInt() ?? 0,
        previousRating: (oldReview.data()?['rating'] as num?)?.toDouble(),
        newRating: rating,
      );

      tx.set(reviewRef, {
        'shopId': shop.id,
        'userId': user.uid,
        'userName': (user.displayName?.trim().isNotEmpty ?? false) ? user.displayName!.trim() : 'Coffee Lover',
        'rating': rating,
        'text': text,
        'photoUrl': photoUrl,
        'userPhotoUrl': (user.photoURL?.isNotEmpty ?? false) ? user.photoURL : null,
        'likes': (oldReview.data()?['likes'] as num?)?.toInt() ?? 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(shopRef, {
        'ratingSum': totals.sum,
        'reviewCount': totals.count,
        'rating': totals.average,
      }, SetOptions(merge: true));
    });
  }

  /// New rating totals after a user posts [newRating]. [previousRating]
  /// is their earlier rating of the same shop when editing (it's swapped
  /// out rather than counted twice), or null for a first review.
  static ({double sum, int count, double average}) updatedRatingTotals({
    required double ratingSum,
    required int reviewCount,
    required double? previousRating,
    required double newRating,
  }) {
    var sum = ratingSum;
    var count = reviewCount;
    if (previousRating != null && count > 0) {
      sum += newRating - previousRating;
    } else {
      sum += newRating;
      count += 1;
    }
    return (sum: sum, count: count, average: double.parse((sum / count).toStringAsFixed(2)));
  }
}
