import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Floating rounded search field that sits over the map — soft shadow,
/// generous radius, and a leading multicolor-style pin icon to echo the
/// "search here" pattern from the reference design.
class CoffeeSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onFilterTap;

  const CoffeeSearchBar({
    super.key,
    required this.controller,
    this.onFilterTap,
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
              decoration: const InputDecoration(
                hintText: 'Search coffee shops near you',
                hintStyle: TextStyle(color: Color(0xFFA8A29A), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500),
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