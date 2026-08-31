import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/menu_item.dart';
import 'shop_photo.dart';

/// Displays a menu item's photo — a real uploaded image (Supabase
/// Storage) if the item has one, otherwise falls back to the shop's
/// general photo/placeholder so the layout never looks broken while menu
/// photo uploads aren't built into any UI yet.
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
      return Image.network(
        item.imageUrl!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(width: width, height: height, color: AppColors.primaryBrown.withOpacity(0.1));
        },
        errorBuilder: (context, error, stackTrace) =>
            ShopPhoto(shop: shop, index: fallbackIndex, width: width, height: height),
      );
    }
    return ShopPhoto(shop: shop, index: fallbackIndex, width: width, height: height);
  }
}