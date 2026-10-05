import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/menu_item.dart';
import 'category_chip.dart';

/// Small coffee labels: Best Seller (owner-marked), Featured, New and
/// Unavailable.
enum CoffeeBadgeKind {
  bestSeller('BEST SELLER', Color(0xFFE04B4B), Icons.local_fire_department_rounded),
  featured('FEATURED', Color(0xFF3E5641), Icons.auto_awesome_rounded),
  isNew('NEW', Color(0xFF4A90D9), Icons.fiber_new_rounded),
  popular('POPULAR', Color(0xFFE5566E), Icons.favorite_rounded), // most hearted
  unavailable('UNAVAILABLE', Color(0xFFD64545), Icons.do_not_disturb_on_rounded);

  final String label;
  final Color color;
  final IconData icon;

  const CoffeeBadgeKind(this.label, this.color, this.icon);
}

class CoffeeBadge extends StatelessWidget {
  final CoffeeBadgeKind kind;
  final bool solid; // filled (on photos) or tinted (on white)

  const CoffeeBadge(this.kind, {super.key, this.solid = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: solid ? kind.color : kind.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        boxShadow: solid ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(kind.icon, size: 10, color: solid ? Colors.white : kind.color),
          const SizedBox(width: 3),
          Text(
            kind.label,
            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: solid ? Colors.white : kind.color),
          ),
        ],
      ),
    );
  }
}

/// The badges a coffee has right now, most important first.
List<CoffeeBadgeKind> coffeeBadges(MenuItem item, {DateTime? now, bool includeUnavailable = true}) => [
      if (item.bestSeller) CoffeeBadgeKind.bestSeller,
      if (item.featured) CoffeeBadgeKind.featured,
      if (item.isNewAt(now ?? DateTime.now())) CoffeeBadgeKind.isNew,
      if (includeUnavailable && !item.available) CoffeeBadgeKind.unavailable,
    ];

/// Horizontal "All · Espresso · Latte …" chips for the categories that
/// actually have coffee. [selected] null = All.
class CoffeeCategoryChips extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final EdgeInsetsGeometry padding;

  const CoffeeCategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final category in [null, ...categories]) ...[
            CategoryChip(
              label: category ?? 'All',
              icon: category == null ? Icons.coffee_rounded : Icons.local_cafe_outlined,
              selected: selected == category,
              onTap: () => onSelected(category),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Section title used when the menu is grouped by category.
class CoffeeSectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const CoffeeSectionTitle(this.title, {super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(width: 6),
        Text('$count', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textGrey)),
      ],
    );
  }
}
