import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import 'shop_photo.dart';
import 'open_status.dart';
import 'fitted_image.dart';

/// Compact card used in horizontal carousels — "Nearby Coffee Shops" on
/// the map screen, "Popular Coffee Shops" / "Recommended for You" on
/// Explore. Clean photo (only the open status, plus the ✨ match % when
/// given), then name, rating · distance, and where it is (mall + floor,
/// or the street address) below.
class ShopMiniCard extends StatelessWidget {
  final CoffeeShop shop;
  final String distanceLabel; // e.g. "0.8 km away" (shown as "0.8 km")
  final VoidCallback onTap;
  final double width;
  final int? matchPercent; // "Recommended for You" only

  const ShopMiniCard({
    super.key,
    required this.shop,
    required this.distanceLabel,
    required this.onTap,
    this.width = 150,
    this.matchPercent,
  });

  /// Height a carousel needs for cards [width] wide: the 4:3 photo plus
  /// the name, rating and location lines, which grow with the font size.
  static double heightFor(double width, TextScaler textScaler) =>
      width / ImageRatios.thumbnail + 25 + textScaler.scale(51);

  /// "SM Butuan · Ground Floor · Unit 12" for mall cafés, else the address.
  String get _locationLine {
    if (!shop.isInMall) return shop.address.trim();
    return [shop.mallName!.trim(), shop.mallFloorAndUnit ?? ''].where((p) => p.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final distance = distanceLabel.replaceFirst(RegExp(r' away$'), '');
    final location = _locationLine;
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
              aspectRatio: 4 / 3, // same box for every café, photo shown whole
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ShopPhoto(shop: shop, width: double.infinity, height: double.infinity),
                  Positioned(top: 6, left: 6, child: OpenStatusBadge(hours: shop.hours)),
                  if ((matchPercent ?? 0) > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBrown,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 10, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              '$matchPercent%',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
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
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A623)),
                      const SizedBox(width: 2),
                      Text(
                        shop.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                      Expanded(
                        child: Text(
                          ' · $distance',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        shop.isInMall ? Icons.local_mall_outlined : Icons.location_on_outlined,
                        size: 12,
                        color: AppColors.primaryBrown,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
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
