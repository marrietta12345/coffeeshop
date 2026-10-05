import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_preferences.dart';
import '../models/coffee_shop.dart';
import '../utils/recommendations.dart';

/// "✨ 92% Match" beside a café's name — how well it fits the customer's
/// Coffee Preferences. Tap for "Your Match".
class VibeMatchPill extends StatelessWidget {
  final VibeMatch match;
  final VoidCallback onTap;

  const VibeMatchPill({super.key, required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryBrown.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.primaryBrown),
              const SizedBox(width: 4),
              Text(
                '${match.percent}% Match',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryBrown),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Your Match": the match % and only the preferences this café actually
/// meets (from its own Café Features). [onEditPreferences] opens the
/// customer's Coffee Preferences.
Future<void> showVibeMatchSheet(
  BuildContext context, {
  required VibeMatch match,
  required String shopName,
  required VoidCallback onEditPreferences,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 20, color: AppColors.primaryBrown),
                const SizedBox(width: 8),
                const Text('Your Match', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${match.percent}% Match for You',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primaryBrown),
            ),
            const SizedBox(height: 2),
            Text(
              '$shopName matches ${match.matched.length} of your ${match.selectedCount} Coffee Preferences.',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
            ),
            const SizedBox(height: 16),
            const Text('Matches your preferences', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final label in match.matched) _MatchChip(label: label)],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  onEditPreferences();
                },
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Edit my Coffee Preferences'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBrown,
                  minimumSize: const Size.fromHeight(46),
                  side: BorderSide(color: AppColors.primaryBrown.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A matched preference, with the same icon the café's vibe tags use.
class _MatchChip extends StatelessWidget {
  final String label;

  const _MatchChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2E9E5B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CafeVibeTags.iconFor(label), size: 15, color: AppColors.primaryBrown),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(width: 4),
          const Icon(Icons.check_rounded, size: 14, color: Color(0xFF2E9E5B)),
        ],
      ),
    );
  }
}

/// The café's own vibe, from the Café Features its owner filled in:
/// atmosphere, must-haves and coffee — one scrollable row of small tags.
class CafeVibeTags extends StatelessWidget {
  final CoffeeShop shop;

  const CafeVibeTags({super.key, required this.shop});

  /// Height of the row (before font scaling), for the café page header.
  static const double rowHeight = 28;

  static const Map<String, IconData> _amenityIcons = {
    CoffeePreferences.studyFriendlyKey: Icons.menu_book_rounded,
    CoffeePreferences.outdoorSeatingKey: Icons.deck_rounded,
    CoffeePreferences.wifiKey: Icons.wifi_rounded,
    CoffeePreferences.petFriendlyKey: Icons.pets_rounded,
  };

  /// The icon for a preference label (atmosphere, must-have or coffee type).
  static IconData iconFor(String label) {
    for (final entry in CoffeePreferences.amenityLabels.entries) {
      if (entry.value == label) return _amenityIcons[entry.key]!;
    }
    return CoffeePreferences.atmosphereOptions.contains(label) ? Icons.chair_rounded : Icons.local_cafe_rounded;
  }

  /// Each tag (icon + label), atmosphere first, then must-haves, then coffee.
  static List<(IconData, String)> tagsFor(CoffeeShop shop) => [
        for (final mood in CoffeePreferences.atmosphereOptions)
          if (shop.atmospheres.contains(mood)) (Icons.chair_rounded, mood),
        for (final entry in CoffeePreferences.amenityLabels.entries)
          if (shop.amenities.contains(entry.key)) (_amenityIcons[entry.key]!, entry.value),
        for (final type in CoffeePreferences.coffeeTypeOptions)
          if (type != 'Non-coffee' && shop.coffeeTypes.contains(type)) (Icons.local_cafe_rounded, type),
      ];

  @override
  Widget build(BuildContext context) {
    final tags = tagsFor(shop);
    if (tags.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(rowHeight),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final (icon, label) = tags[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8F5),
              border: Border.all(color: const Color(0xFFEDE6DF)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: AppColors.primaryBrown),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              ],
            ),
          );
        },
      ),
    );
  }
}
