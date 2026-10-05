import 'package:flutter/material.dart';
import '../widgets/owner_bottom_nav.dart';
import 'owner_dashboard_page.dart';
import 'owner_menu_page.dart';
import 'owner_popular_coffee_page.dart';
import 'owner_reviews_page.dart';
import 'owner_shop_profile_page.dart';

/// Owns the 5-tab state for the Coffee Shop Owner side of the app —
/// Dashboard, Menu, Popular Coffee, Reviews, Profile.
class OwnerMainNavPage extends StatefulWidget {
  const OwnerMainNavPage({super.key});

  @override
  State<OwnerMainNavPage> createState() => _OwnerMainNavPageState();
}

class _OwnerMainNavPageState extends State<OwnerMainNavPage> {
  static const int _reviewsTab = 3;
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _navIndex,
        children: [
          OwnerDashboardPage(onViewAllReviews: () => setState(() => _navIndex = _reviewsTab)),
          const OwnerMenuPage(),
          const OwnerPopularCoffeePage(),
          const OwnerReviewsPage(),
          const OwnerShopProfilePage(),
        ],
      ),
      bottomNavigationBar: OwnerBottomNav(
        selectedIndex: _navIndex,
        onTabSelected: (index) => setState(() => _navIndex = index),
      ),
    );
  }
}
