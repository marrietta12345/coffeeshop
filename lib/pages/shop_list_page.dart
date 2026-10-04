import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../utils/distance_utils.dart';
import '../utils/page_transitions.dart';
import '../widgets/shop_photo.dart';
import '../widgets/open_status.dart';
import 'shop_detail_page.dart';

/// Full list behind Explore's "View all" links (Popular Coffee Shops,
/// All Cafés). Shows [shops] in the order given — the caller filters and
/// sorts them.
class ShopListPage extends StatelessWidget {
  final String title;
  final List<CoffeeShop> shops;
  final LatLng userLocation;
  final String emptyText;

  const ShopListPage({
    super.key,
    required this.title,
    required this.shops,
    required this.userLocation,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                ],
              ),
            ),
            Expanded(
              child: shops.isEmpty
                  ? Center(
                      child: Text(
                        emptyText,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                      itemCount: shops.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final shop = shops[index];
                        return ShopListCard(
                          shop: shop,
                          distanceLabel: formatDistance(userLocation, LatLng(shop.latitude, shop.longitude)),
                          onTap: () => Navigator.push(context, slideUpRoute(ShopDetailPage(shop: shop))),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White card row matching Explore's Best Sellers rows: photo, name,
/// rating + distance, and location. Also used for Explore search results.
class ShopListCard extends StatelessWidget {
  final CoffeeShop shop;
  final String distanceLabel;
  final VoidCallback onTap;

  const ShopListCard({super.key, required this.shop, required this.distanceLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              child: ShopPhoto(shop: shop, width: 64, height: 64),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A623)),
                      const SizedBox(width: 2),
                      Text(
                        shop.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: Colors.grey.shade400)),
                      const SizedBox(width: 8),
                      Text(distanceLabel, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    ],
                  ),
                  if (shop.locationLabel.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      shop.isInMall ? '📍 ${shop.locationLabel}' : shop.locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                    ),
                  ],
                  if (shop.mallDetails != null)
                    Text(
                      shop.mallDetails!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                    ),
                  const SizedBox(height: 4),
                  OpenStatusLine(hours: shop.hours, fontSize: 11.5),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}
