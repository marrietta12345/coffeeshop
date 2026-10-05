import 'package:flutter/material.dart';
import 'fitted_image.dart';
import '../theme/app_colors.dart';
import '../models/review.dart';

/// Row of 1–5 stars (half stars for averages).
class ReviewStars extends StatelessWidget {
  final double rating;
  final double size;

  const ReviewStars({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star_rounded
                : rating >= i - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_border_rounded,
            size: size,
            color: const Color(0xFFF5A623),
          ),
      ],
    );
  }
}

/// "⭐ 4.8 · 24 Coffee Reviews", or "No reviews yet" — from real reviews.
class CoffeeRatingLine extends StatelessWidget {
  final List<Review> reviews;

  const CoffeeRatingLine({super.key, required this.reviews});

  static double average(List<Review> reviews) =>
      reviews.isEmpty ? 0 : reviews.fold<double>(0, (sum, r) => sum + r.rating) / reviews.length;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const Text('No reviews yet', style: TextStyle(fontSize: 13, color: AppColors.textGrey, fontWeight: FontWeight.w600));
    }
    final count = reviews.length;
    return Row(
      children: [
        const Icon(Icons.star_rounded, size: 17, color: Color(0xFFF5A623)),
        const SizedBox(width: 3),
        Text(average(reviews).toStringAsFixed(1), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(width: 6),
        Text(
          '· $count Coffee ${count == 1 ? 'Review' : 'Reviews'}',
          style: const TextStyle(fontSize: 13, color: AppColors.textGrey, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// One coffee review as customers see it: avatar, name, stars, date,
/// comment, optional photo, and the café's response below it.
class CoffeeReviewTile extends StatelessWidget {
  final Review review;
  final bool isMine;
  final String? shopName; // the café's current name, for its response
  final String? shopLogoUrl; // and its logo

  const CoffeeReviewTile({super.key, required this.review, this.isMine = false, this.shopName, this.shopLogoUrl});

  void _showPhoto(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: InteractiveViewer(child: Center(child: Image.network(review.photoUrl!))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = review.userPhotoUrl?.isNotEmpty ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryBrown.withOpacity(0.15),
                backgroundImage: hasAvatar ? NetworkImage(review.userPhotoUrl!) : null,
                child: hasAvatar
                    ? null
                    : Text(
                        review.userName.isNotEmpty ? review.userName[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.primaryBrown, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            review.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark),
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.primaryBrown.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                            child: const Text('You', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryBrown)),
                          ),
                        ],
                      ],
                    ),
                    Text(review.timeAgo, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  ],
                ),
              ),
              ReviewStars(rating: review.rating, size: 13),
            ],
          ),
          if (review.hasText) ...[
            const SizedBox(height: 8),
            Text(review.text, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.4)),
          ],
          if (review.hasPhoto) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showPhoto(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: FittedImage.network(
                  review.photoUrl!,
                  width: 72,
                  height: 72,
                  fallback: Container(
                    width: 72,
                    height: 72,
                    color: AppColors.primaryBrown.withOpacity(0.12),
                    child: const Icon(Icons.image_outlined, color: AppColors.primaryBrown, size: 20),
                  ),
                ),
              ),
            ),
          ],
          if (review.hasOwnerReply) ...[
            const SizedBox(height: 10),
            OwnerResponseBox(text: review.ownerReply!, shopName: shopName, shopLogoUrl: shopLogoUrl),
          ],
        ],
      ),
    );
  }
}

/// Who a review response is shown as: the business, never the owner's
/// personal account — "Local Brew Café · Owner". Uses the café's current
/// name; "Coffee Shop · Owner" only if the name isn't available.
String ownerReplyLabel(String? shopName) {
  final name = shopName?.trim() ?? '';
  return '${name.isEmpty ? 'Coffee Shop' : name} · Owner';
}

/// The café's own logo, small and round, beside its name on a reply —
/// the storefront icon only when the café hasn't uploaded a logo.
class ShopReplyLogo extends StatelessWidget {
  final String? logoUrl;
  final double size;

  const ShopReplyLogo({super.key, required this.logoUrl, this.size = 20});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.primaryBrown.withOpacity(0.12), shape: BoxShape.circle),
      child: Icon(Icons.storefront_rounded, size: size * 0.65, color: AppColors.primaryBrown),
    );
    final url = logoUrl?.trim() ?? '';
    if (url.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

/// The café's reply under a review, signed as the café (logo + name).
class OwnerResponseBox extends StatelessWidget {
  final String text;
  final String? shopName;
  final String? shopLogoUrl;

  const OwnerResponseBox({super.key, required this.text, required this.shopName, this.shopLogoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F5),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: AppColors.primaryBrown, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShopReplyLogo(logoUrl: shopLogoUrl),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  ownerReplyLabel(shopName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primaryBrown),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.textDark, height: 1.4)),
        ],
      ),
    );
  }
}
