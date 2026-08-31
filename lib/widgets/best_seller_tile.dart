import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/menu_item.dart';
import 'menu_item_image.dart';

/// A single "best seller" row — photo, item name, shop name, a heart+like
/// badge, and price. Shared between the Explore page's preview list and
/// the full Best Sellers page.
class BestSellerTile extends StatelessWidget {
  final MenuItem item;
  final CoffeeShop shop;
  final VoidCallback onTap;

  const BestSellerTile({
    super.key,
    required this.item,
    required this.shop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: MenuItemImage(item: item, shop: shop, fallbackIndex: item.hashCode % 20, width: 60, height: 60),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                  const SizedBox(height: 3),
                  Text(shop.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryBrown)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(Icons.favorite_rounded, size: 13, color: Color(0xFFE04B4B)),
                    const SizedBox(width: 3),
                    Text('${item.likes}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '₱${item.price.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.textDark),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}