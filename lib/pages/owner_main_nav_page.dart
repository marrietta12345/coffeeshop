import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/owner_bottom_nav.dart';
import 'owner_dashboard_page.dart';
import 'owner_shop_profile_page.dart';

/// Owns the 5-tab state for the Coffee Shop Owner side of the app —
/// Dashboard, Menu, Best Sellers, Reviews, Profile.
class OwnerMainNavPage extends StatefulWidget {
  const OwnerMainNavPage({super.key});

  @override
  State<OwnerMainNavPage> createState() => _OwnerMainNavPageState();
}

class _OwnerMainNavPageState extends State<OwnerMainNavPage> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _navIndex,
        children: const [
          OwnerDashboardPage(),
          _OwnerMenuTab(),
          _OwnerBestSellersTab(),
          _OwnerReviewsTab(),
          OwnerShopProfilePage(),
        ],
      ),
      bottomNavigationBar: OwnerBottomNav(
        selectedIndex: _navIndex,
        onTabSelected: (index) => setState(() => _navIndex = index),
      ),
    );
  }
}

/// Menu management for owners isn't built yet — no add/edit UI exists,
/// so this honestly shows an empty state rather than fabricating one.
class _OwnerMenuTab extends StatelessWidget {
  const _OwnerMenuTab();

  @override
  Widget build(BuildContext context) {
    return const _ComingSoonTab(
      icon: Icons.restaurant_menu_rounded,
      title: 'Menu management coming soon',
      subtitle: "You'll be able to add and edit your menu items here.",
    );
  }
}

class _OwnerBestSellersTab extends StatelessWidget {
  const _OwnerBestSellersTab();

  @override
  Widget build(BuildContext context) {
    return const _ComingSoonTab(
      icon: Icons.star_rounded,
      title: 'No best sellers yet',
      subtitle: 'Once your menu is set up, your most-loved items will show here.',
    );
  }
}

/// Real customer reviews currently live only in each viewer's local
/// session (see shop_detail_page.dart) — they aren't persisted to
/// Firestore yet, so owners can't see them here honestly until that's
/// built.
class _OwnerReviewsTab extends StatelessWidget {
  const _OwnerReviewsTab();

  @override
  Widget build(BuildContext context) {
    return const _ComingSoonTab(
      icon: Icons.rate_review_rounded,
      title: 'Reviews coming soon',
      subtitle: "Customer reviews for your shop will appear here once that's connected.",
    );
  }
}

class _ComingSoonTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ComingSoonTab({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFAF8F5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.textGrey.withOpacity(0.4)),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 6),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}