import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../utils/owner_shop_service.dart';
import '../widgets/owner_activity_section.dart';

/// Coffee Shop Owner's dashboard — greeting, an all-time Shop Overview
/// (rating, total reviews, total favorites), an aggregated Activity Summary (Today / 7 Days /
/// 30 Days) and Recent Reviews with owner responses. Pull down to refresh.
class OwnerDashboardPage extends StatefulWidget {
  final VoidCallback? onViewAllReviews; // switches to the Reviews tab

  const OwnerDashboardPage({super.key, this.onViewAllReviews});

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  final _activityKey = GlobalKey<OwnerActivitySectionState>();
  // Created once — a new stream on every rebuild would flash the loader
  // and reset the Activity filter.
  final Stream<CoffeeShop?> _shopStream = OwnerShopService.myShopStream();

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final ownerName = (user?.displayName?.isNotEmpty ?? false) ? user!.displayName! : 'there';

    return Container(
      color: const Color(0xFFFAF8F5),
      child: SafeArea(
        child: StreamBuilder<CoffeeShop?>(
          stream: _shopStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primaryBrown));
            }

            final shop = snapshot.data;
            if (shop == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    "We couldn't find your shop. Please contact support.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                ),
              );
            }

            return RefreshIndicator(
              color: AppColors.primaryBrown,
              onRefresh: () => _activityKey.currentState?.reload() ?? Future.value(),
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primaryBrown.withOpacity(0.15),
                      child: const Icon(Icons.person_rounded, color: AppColors.primaryBrown),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$_greeting,', style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                          Text(ownerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                          Text(shop.name, style: const TextStyle(fontSize: 12.5, color: AppColors.primaryBrown, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
                      ]),
                      child: const Icon(Icons.notifications_none_rounded, color: AppColors.textDark, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3E5641),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Shop Overview', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        'All-time',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _StatColumn(label: 'Rating', value: shop.rating > 0 ? shop.rating.toStringAsFixed(1) : '—'),
                          _StatColumn(label: 'Total Reviews', value: '${shop.reviewCount}'),
                          _StatColumn(label: 'Total Favorites', value: '${shop.favoritesCount < 0 ? 0 : shop.favoritesCount}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                OwnerActivitySection(key: _activityKey, shop: shop, onViewAllReviews: widget.onViewAllReviews),
              ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11.5)),
        ],
      ),
    );
  }
}