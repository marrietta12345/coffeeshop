import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import 'shop_photo.dart';

/// Compact card used in horizontal carousels — "Nearby Coffee Shops" on
/// the map screen, "Popular Coffee Shops" on Explore. Photo, name,
/// rating, and a distance label.
class ShopMiniCard extends StatelessWidget {
  final CoffeeShop shop;
  final String distanceLabel;
  final VoidCallback onTap;
  final double width;

  const ShopMiniCard({
    super.key,
    required this.shop,
    required this.distanceLabel,
    required this.onTap,
    this.width = 150,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 11,
              child: ShopPhoto(shop: shop, width: double.infinity, height: double.infinity),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A623)),
                      const SizedBox(width: 2),
                      Text(
                        shop.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          distanceLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}