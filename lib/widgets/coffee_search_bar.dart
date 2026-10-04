import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Floating rounded search field that sits over the map — soft shadow,
/// generous radius, and a leading multicolor-style pin icon to echo the
/// "search here" pattern from the reference design. Shows a clear (×)
/// button while there's text, when [onClear] is provided.
class CoffeeSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onFilterTap;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  const CoffeeSearchBar({
    super.key,
    required this.controller,
    this.onFilterTap,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 18),
          const Icon(Icons.location_on_rounded, color: AppColors.primaryBrown, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search coffee shops near you',
                hintStyle: TextStyle(color: Color(0xFFA8A29A), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500),
            ),
          ),
          if (onClear != null)
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => controller.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textGrey, size: 20),
                      tooltip: 'Clear search',
                      onPressed: onClear,
                    ),
            ),
          Container(width: 1, height: 22, color: const Color(0xFFEDEAE6)),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.primaryBrown, size: 20),
            onPressed: onFilterTap,
          ),
        ],
      ),
    );
  }
}
