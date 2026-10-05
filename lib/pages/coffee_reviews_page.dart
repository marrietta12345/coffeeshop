import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/menu_item.dart';
import '../models/review.dart';
import '../utils/coffee_review_service.dart';
import '../utils/page_transitions.dart';
import '../utils/review_insights.dart';
import '../widgets/coffee_review_widgets.dart';
import '../widgets/top_banner.dart';
import 'coffee_review_form_page.dart';

/// Every review of one coffee — "Spanish Latte Reviews" with its average
/// rating, review count and Most Recent / Highest / Lowest / With Photos
/// sorting.
class CoffeeReviewsPage extends StatefulWidget {
  final MenuItem coffee;
  final bool canReview; // false on the owner's own café
  final String? shopName; // the café's current name, for its responses
  final String? shopLogoUrl; // and its logo

  const CoffeeReviewsPage({super.key, required this.coffee, this.canReview = true, this.shopName, this.shopLogoUrl});

  @override
  State<CoffeeReviewsPage> createState() => _CoffeeReviewsPageState();
}

class _CoffeeReviewsPageState extends State<CoffeeReviewsPage> {
  late final Stream<List<Review>> _stream = CoffeeReviewService.coffeeReviewsStream(widget.coffee.shopId, widget.coffee.id);
  ReviewSort _sort = ReviewSort.recent;

  String? get _myReviewId {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? null : CoffeeReviewService.reviewId(widget.coffee.id, uid);
  }

  Future<void> _openForm(Review? mine) async {
    final result = await Navigator.push<CoffeeReviewResult>(
      context,
      slideUpRoute(CoffeeReviewFormPage(coffee: widget.coffee, existing: mine)),
    );
    if (!mounted || result == null) return;
    showTopBanner(context, result == CoffeeReviewResult.deleted ? 'Review deleted.' : 'Thanks for your review!', isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<List<Review>>(
          stream: _stream,
          builder: (context, snapshot) {
            final reviews = snapshot.data ?? const <Review>[];
            Review? mine;
            for (final r in reviews) {
              if (r.id == _myReviewId) mine = r;
            }
            final shown = ReviewInsights.sorted(reviews, _sort);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${widget.coffee.name} Reviews',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: snapshot.hasError
                      ? const Center(child: Text("Couldn't load reviews.", style: TextStyle(color: AppColors.textGrey)))
                      : !snapshot.hasData
                          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBrown))
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              children: [
                                _Summary(reviews: reviews),
                                if (widget.canReview) ...[
                                  const SizedBox(height: 14),
                                  _WriteButton(isEdit: mine != null, onPressed: () => _openForm(mine)),
                                ],
                                if (reviews.isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        for (final sort in ReviewSort.values) ...[
                                          _SortChip(label: sort.label, selected: sort == _sort, onTap: () => setState(() => _sort = sort)),
                                          const SizedBox(width: 8),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (shown.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 32),
                                      child: Center(child: Text('No reviews with photos yet.', style: TextStyle(color: AppColors.textGrey))),
                                    )
                                  else
                                    for (var i = 0; i < shown.length; i++) ...[
                                      if (i > 0) const Divider(height: 1, color: Color(0xFFF0ECE8)),
                                      CoffeeReviewTile(
                                        review: shown[i],
                                        isMine: shown[i].id == _myReviewId,
                                        shopName: widget.shopName,
                                        shopLogoUrl: widget.shopLogoUrl,
                                      ),
                                    ],
                                ],
                              ],
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final List<Review> reviews;

  const _Summary({required this.reviews});

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFFFAF8F5), borderRadius: BorderRadius.circular(16)),
        child: const Column(
          children: [
            Icon(Icons.rate_review_outlined, size: 30, color: AppColors.primaryBrown),
            SizedBox(height: 8),
            Text('No reviews yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            SizedBox(height: 4),
            Text(
              'Be the first to share your thoughts about this coffee.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textGrey),
            ),
          ],
        ),
      );
    }
    final average = CoffeeRatingLine.average(reviews);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFAF8F5), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Text(average.toStringAsFixed(1), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReviewStars(rating: average, size: 18),
              const SizedBox(height: 4),
              Text(
                '${reviews.length} ${reviews.length == 1 ? 'Review' : 'Reviews'}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WriteButton extends StatelessWidget {
  final bool isEdit;
  final VoidCallback onPressed;

  const _WriteButton({required this.isEdit, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(isEdit ? Icons.edit_outlined : Icons.rate_review_outlined, size: 18),
        label: Text(isEdit ? 'Edit Review' : 'Write a Review'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBrown,
          side: BorderSide(color: AppColors.primaryBrown.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBrown : AppColors.inputFill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textGrey),
        ),
      ),
    );
  }
}
