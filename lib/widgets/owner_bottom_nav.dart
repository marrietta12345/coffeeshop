import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Five-tab bottom bar for the Coffee Shop Owner side of the app —
/// Dashboard, Menu, Popular, Reviews, Profile. Same visual pattern
/// as the customer-side CustomBottomNav for consistency.
class OwnerBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const OwnerBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0EDE9), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', selected: selectedIndex == 0, onTap: () => onTabSelected(0)),
            _NavItem(icon: Icons.restaurant_menu_rounded, label: 'Menu', selected: selectedIndex == 1, onTap: () => onTabSelected(1)),
            _NavItem(icon: Icons.star_rounded, label: 'Popular', selected: selectedIndex == 2, onTap: () => onTabSelected(2)),
            _NavItem(icon: Icons.rate_review_rounded, label: 'Reviews', selected: selectedIndex == 3, onTap: () => onTabSelected(3)),
            _NavItem(icon: Icons.person_rounded, label: 'Profile', selected: selectedIndex == 4, onTap: () => onTabSelected(4)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryBrown.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: selected ? AppColors.primaryBrown : Colors.grey, size: 22),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primaryBrown : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}