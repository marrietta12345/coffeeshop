import 'package:cloud_firestore/cloud_firestore.dart';

/// A customer review of one coffee shop, stored at
/// `shops/{shopId}/reviews/{userId}` — one review per user per shop
/// (posting again for the same shop updates it), so every review is tied
/// to exactly the shop it was written for.
class Review {
  final String id; // the author's uid
  final String shopId;
  final String userId;
  final String userName;
  final double rating;
  final String timeAgo;
  final String text;
  final int likes;
  final String? photoUrl; // optional attached photo (Supabase Storage)
  final DateTime? createdAt;

  const Review({
    this.id = '',
    this.shopId = '',
    this.userId = '',
    required this.userName,
    required this.rating,
    required this.timeAgo,
    required this.text,
    this.likes = 0,
    this.photoUrl,
    this.createdAt,
  });

  bool get hasPhoto => photoUrl?.isNotEmpty ?? false;

  factory Review.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    // A just-posted review's server timestamp reads as null until saved.
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return Review(
      id: doc.id,
      shopId: (data['shopId'] as String?) ?? doc.reference.parent.parent?.id ?? '',
      userId: (data['userId'] as String?) ?? doc.id,
      userName: (data['userName'] as String?) ?? 'Coffee Lover',
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      timeAgo: formatTimeAgo(createdAt),
      text: (data['text'] as String?) ?? '',
      likes: (data['likes'] as num?)?.toInt() ?? 0,
      photoUrl: data['photoUrl'] as String?,
      createdAt: createdAt,
    );
  }

  /// "Just now", "5 minutes ago", "3 days ago", "2 weeks ago", ...
  static String formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    String plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'} ago';
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return plural(diff.inMinutes, 'minute');
    if (diff.inDays < 1) return plural(diff.inHours, 'hour');
    if (diff.inDays < 7) return plural(diff.inDays, 'day');
    if (diff.inDays < 30) return plural(diff.inDays ~/ 7, 'week');
    if (diff.inDays < 365) return plural(diff.inDays ~/ 30, 'month');
    return plural(diff.inDays ~/ 365, 'year');
  }
}
