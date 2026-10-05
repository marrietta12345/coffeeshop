import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/menu_item.dart';
import 'fitted_image.dart';

/// Background shared by the owner tabs (same as the Dashboard).
const Color ownerPageBackground = Color(0xFFFAF8F5);

/// Title + subtitle at the top of an owner tab, with an optional action.
class OwnerPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const OwnerPageHeader({super.key, required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

/// Friendly empty state in a white rounded card.
class OwnerEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const OwnerEmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.primaryBrown.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 30, color: AppColors.primaryBrown),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey, height: 1.5)),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

/// Brown pill button, e.g. "+ Add Coffee".
class OwnerPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const OwnerPillButton({super.key, required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBrown,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Segmented filter (e.g. This Week | This Month | All Time).
class OwnerSegmentedFilter<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  const OwnerSegmentedFilter({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          for (final value in values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == selected ? AppColors.primaryBrown : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    labelOf(value),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: value == selected ? Colors.white : AppColors.textGrey,
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

/// A coffee's photo in a fixed 4:3 box ([size] wide) — the real uploaded
/// image filling the box, or a plain coffee-cup tile when it has none (never a
/// stock photo). Greyed out when unavailable.
class CoffeeThumb extends StatelessWidget {
  final MenuItem item;
  final double size; // width; height follows the 4:3 ratio

  const CoffeeThumb({super.key, required this.item, this.size = 80});

  @override
  Widget build(BuildContext context) {
    final height = size / ImageRatios.coffee;
    final placeholder = Container(
      width: size,
      height: height,
      color: AppColors.primaryBrown.withOpacity(0.12),
      child: Icon(Icons.local_cafe_rounded, color: AppColors.primaryBrown, size: height * 0.45),
    );
    Widget image = item.hasImage
        ? FittedImage.network(item.imageUrl!, width: size, height: height, fit: BoxFit.cover, fallback: placeholder)
        : placeholder;
    if (!item.available) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 0.6, 0,
        ]),
        child: image,
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: image);
  }
}

/// Green "Available" / red "Unavailable" pill.
class AvailabilityBadge extends StatelessWidget {
  final bool available;

  const AvailabilityBadge({super.key, required this.available});

  @override
  Widget build(BuildContext context) {
    final color = available ? const Color(0xFF2E9E5B) : const Color(0xFFD64545);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            available ? 'Available' : 'Unavailable',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// Small brown category tag, e.g. "Spanish Latte".
class CoffeeCategoryTag extends StatelessWidget {
  final String category;

  const CoffeeCategoryTag({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.primaryBrown.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(category, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primaryBrown)),
    );
  }
}

/// "Oct 4, 2026".
String formatShortDate(DateTime? date) {
  if (date == null) return '';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final d = date.toLocal();
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// "Delete Coffee?"-style confirmation. Resolves to true on the red button.
Future<bool> confirmDelete(BuildContext context, {required String title, required String message}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
      content: Text(message, style: const TextStyle(fontSize: 13.5, color: AppColors.textGrey, height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete', style: TextStyle(color: Color(0xFFD64545), fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  return result == true;
}
