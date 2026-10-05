import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/menu_item.dart';
import 'fitted_image.dart';

/// Displays a menu item's photo — the real uploaded image (Supabase
/// Storage), filling its box (centered, like food apps), or a plain
/// coffee-cup tile when it has none (never a stand-in photo).
class MenuItemImage extends StatelessWidget {
  final MenuItem item;
  final CoffeeShop shop;
  final int fallbackIndex;
  final double width;
  final double height;

  const MenuItemImage({
    super.key,
    required this.item,
    required this.shop,
    required this.fallbackIndex,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return FittedImage.network(item.imageUrl!, width: width, height: height, fit: BoxFit.cover, fallback: _placeholder());
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        width: width,
        height: height,
        color: AppColors.primaryBrown.withOpacity(0.12),
        child: const Center(child: Icon(Icons.local_cafe_rounded, color: AppColors.primaryBrown, size: 26)),
      );
}