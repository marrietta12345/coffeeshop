import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../utils/owner_shop_service.dart';

/// Coffee Shop Owner's dashboard — greeting, and real today's-overview
/// stats (profile views, favorites) pulled live from Firestore. Review
/// count and a true activity feed need a review-persistence feature that
/// doesn't exist yet (reviews currently live only in the viewer's local
/// session on the customer side) — shown honestly as 0 / empty rather
/// than fabricated numbers.
class OwnerDashboardPage extends StatelessWidget {
  const OwnerDashboardPage({super.key});

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
          stream: OwnerShopService.myShopStream(),
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

            return ListView(
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
                      const Text("Today's Overview", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        _formattedDate(),
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _StatColumn(label: 'Profile Views', value: '${shop.viewCount}'),
                          _StatColumn(label: 'Favorites', value: '${shop.favoritesCount}'),
                          _StatColumn(label: 'Rating', value: shop.rating > 0 ? shop.rating.toStringAsFixed(1) : '—'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text('Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.timeline_rounded, size: 32, color: AppColors.textGrey.withOpacity(0.4)),
                      const SizedBox(height: 10),
                      const Text(
                        'Activity will appear here as customers view your shop,\nsave it, or leave a review.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: AppColors.textGrey, height: 1.5),
                      ),
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

  String _formattedDate() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
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