import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/review.dart';
import '../utils/review_service.dart';
import '../utils/shop_activity_service.dart';

/// The owner dashboard's Activity Summary (aggregated counts with a
/// Today / 7 Days / 30 Days filter) followed by a small Recent Reviews
/// preview (latest 5, live). Never lists individual viewers — only totals
/// and real reviews; managing reviews happens on the Reviews tab.
class OwnerActivitySection extends StatefulWidget {
  final CoffeeShop shop;
  final VoidCallback? onViewAllReviews; // opens the Reviews tab

  const OwnerActivitySection({super.key, required this.shop, this.onViewAllReviews});

  @override
  State<OwnerActivitySection> createState() => OwnerActivitySectionState();
}

class OwnerActivitySectionState extends State<OwnerActivitySection> {
  ActivityPeriod _period = ActivityPeriod.week;
  late Future<ActivitySummary> _summary;
  // Only the 5 newest reviews are fetched; a new one pushes the oldest out.
  late Stream<List<Review>> _recentReviews = ReviewService.reviewsStream(widget.shop.id, limit: 5);

  @override
  void initState() {
    super.initState();
    _summary = ShopActivityService.summary(widget.shop.id, _period);
  }

  @override
  void didUpdateWidget(OwnerActivitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final a = oldWidget.shop, b = widget.shop;
    // New view, favorite or review on the shop doc → refresh the counts.
    if (a.id != b.id) _recentReviews = ReviewService.reviewsStream(b.id, limit: 5);
    if (a.id != b.id || a.viewCount != b.viewCount || a.favoritesCount != b.favoritesCount || a.rating != b.rating) {
      reload();
    }
  }

  /// Re-runs the count queries (pull-to-refresh, period change, new reply).
  Future<void> reload() {
    final future = ShopActivityService.summary(widget.shop.id, _period);
    future.ignore(); // errors are shown by the FutureBuilder, not thrown
    if (mounted) setState(() => _summary = future);
    return future.then((_) {}, onError: (Object e) => debugPrint('Activity summary failed: $e'));
  }

  void _selectPeriod(ActivityPeriod period) {
    if (period == _period) return;
    setState(() => _period = period); // highlight the chip right away
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Activity — ${_period.title}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 12),
        _PeriodFilter(selected: _period, onSelected: _selectPeriod),
        const SizedBox(height: 12),
        FutureBuilder<ActivitySummary>(
          future: _summary,
          builder: (context, snapshot) {
            if (snapshot.hasError && snapshot.connectionState == ConnectionState.done) {
              return _card(
                child: const Text(
                  "Couldn't load your activity. Pull down to refresh.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                ),
              );
            }
            final s = snapshot.connectionState == ConnectionState.done ? snapshot.data : null;
            String value(int Function(ActivitySummary) pick) => s == null ? '–' : '${pick(s)}';
            return _card(
              child: Column(
                children: [
                  Row(
                    children: [
                      _ActivityTile(icon: Icons.visibility_rounded, color: const Color(0xFF4A90D9), label: 'Profile Views', value: value((s) => s.profileViews)),
                      const SizedBox(width: 12),
                      _ActivityTile(icon: Icons.favorite_rounded, color: const Color(0xFFE5566E), label: 'New Favorites', value: value((s) => s.favorites)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _ActivityTile(icon: Icons.star_rounded, color: const Color(0xFFF5A623), label: 'New Reviews', value: value((s) => s.newReviews)),
                      const SizedBox(width: 12),
                      _ActivityTile(icon: Icons.bookmark_rounded, color: AppColors.primaryBrown, label: 'Collection Saves', value: value((s) => s.collectionSaves)),
                    ],
                  ),
                  if (s != null && s.reviewsToRespond > 0) ...[
                    const SizedBox(height: 12),
                    _RespondBanner(count: s.reviewsToRespond),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 28),
        const Text('Recent Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 12),
        StreamBuilder<List<Review>>(
          stream: _recentReviews,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _card(
                child: const Text("Couldn't load reviews.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(color: AppColors.primaryBrown, strokeWidth: 2.5)),
              );
            }
            final reviews = snapshot.data!;
            if (reviews.isEmpty) {
              return _card(
                child: Column(
                  children: [
                    Icon(Icons.rate_review_outlined, size: 32, color: AppColors.textGrey.withOpacity(0.4)),
                    const SizedBox(height: 10),
                    const Text('No reviews yet', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const SizedBox(height: 4),
                    const Text(
                      'Customer reviews will appear here once\ncustomers leave feedback.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: AppColors.textGrey, height: 1.5),
                    ),
                  ],
                ),
              );
            }
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  for (var i = 0; i < reviews.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: Color(0xFFF0ECE8)),
                    _ReviewPreviewRow(review: reviews[i]),
                  ],
                  if (widget.onViewAllReviews != null) ...[
                    const Divider(height: 1, color: Color(0xFFF0ECE8)),
                    TextButton(
                      onPressed: widget.onViewAllReviews,
                      style: TextButton.styleFrom(foregroundColor: AppColors.primaryBrown),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('View All Reviews', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  static Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: child,
      );
}

class _PeriodFilter extends StatelessWidget {
  final ActivityPeriod selected;
  final ValueChanged<ActivityPeriod> onSelected;

  const _PeriodFilter({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          for (final period in ActivityPeriod.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(period),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: period == selected ? AppColors.primaryBrown : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    period.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: period == selected ? Colors.white : AppColors.textGrey,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _ActivityTile({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFAF8F5), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RespondBanner extends StatelessWidget {
  final int count;

  const _RespondBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.rate_review_rounded, size: 18, color: Color(0xFFD98A00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count ${count == 1 ? 'review' : 'reviews'} to respond',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// One review on the Dashboard preview: avatar, stars, the comment (2
/// lines max) and "Name · 2 hours ago". Photos, replies and hearts stay
/// on the Reviews tab.
class _ReviewPreviewRow extends StatelessWidget {
  final Review review;

  const _ReviewPreviewRow({required this.review});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = review.userPhotoUrl?.isNotEmpty ?? false;
    final when = review.timeAgo == '1 day ago' ? 'Yesterday' : review.timeAgo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  children: List.generate(5, (i) {
                    return Icon(
                      i < review.rating.round() ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 14,
                      color: const Color(0xFFF5A623),
                    );
                  }),
                ),
                const SizedBox(height: 3),
                Text(
                  '\u201C${review.text}\u201D',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.35),
                ),
                const SizedBox(height: 3),
                Text(
                  '${review.userName} · $when',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
