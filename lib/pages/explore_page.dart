import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/menu_item.dart';
import '../data/mock_coffee_shops.dart';
import '../widgets/coffee_search_bar.dart';
import '../widgets/shop_mini_card.dart';
import '../utils/distance_utils.dart';
import '../utils/location_service.dart';
import '../utils/page_transitions.dart';
import 'shop_detail_page.dart';

/// Browse-style Explore tab — search, a horizontal "Popular Coffee Shops"
/// carousel, and a "Best Sellers" carousel pulling the most-liked menu
/// items across every shop. Complements the map tab (location-first) with
/// a listing-first way to discover shops.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final _searchController = TextEditingController();

  // Fallback (Butuan City) used only until real GPS is available, or if
  // the user has denied location permission.
  static const _fallbackLocation = LatLng(8.9475, 125.5406);
  LatLng _userLocation = _fallbackLocation;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    final result = await getCurrentLocation();
    if (!mounted || !result.isSuccess) return;
    setState(() => _userLocation = result.position!);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CoffeeShop> get _popularShops {
    final shops = List.of(mockCoffeeShops)..sort((a, b) => b.rating.compareTo(a.rating));
    return shops;
  }

  List<({MenuItem item, CoffeeShop shop})> get _bestSellers {
    final all = <({MenuItem item, CoffeeShop shop})>[];
    for (final shop in mockCoffeeShops) {
      for (final item in shop.menu) {
        all.add((item: item, shop: shop));
      }
    }
    all.sort((a, b) => b.item.likes.compareTo(a.item.likes));
    return all.take(6).toList();
  }

  void _openShop(CoffeeShop shop) {
    Navigator.of(context).push(slideUpRoute(ShopDetailPage(shop: shop)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFAF8F5),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            const Text(
              'Explore',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
            const SizedBox(height: 14),
            CoffeeSearchBar(controller: _searchController),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Popular Coffee Shops',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
                ),
                Text('View all', style: TextStyle(fontSize: 12, color: AppColors.primaryBrown, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 172,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _popularShops.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final shop = _popularShops[index];
                  final distance = formatDistance(_userLocation, LatLng(shop.latitude, shop.longitude));
                  return ShopMiniCard(
                    shop: shop,
                    distanceLabel: distance,
                    onTap: () => _openShop(shop),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Best Sellers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
                ),
                Text('View all', style: TextStyle(fontSize: 12, color: AppColors.primaryBrown, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            ..._bestSellers.map((entry) => _BestSellerRow(
                  item: entry.item,
                  shop: entry.shop,
                  onTap: () => _openShop(entry.shop),
                )),
          ],
        ),
      ),
    );
  }
}

class _BestSellerRow extends StatelessWidget {
  final MenuItem item;
  final CoffeeShop shop;
  final VoidCallback onTap;

  const _BestSellerRow({required this.item, required this.shop, required this.onTap});

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
              child: Image.network(
                shop.coverPhotoUrl(item.hashCode % 20),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 56,
                  height: 56,
                  color: AppColors.primaryBrown.withOpacity(0.15),
                  child: const Icon(Icons.local_cafe_rounded, color: AppColors.primaryBrown, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(shop.name, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                ],
              ),
            ),
            Text(
              '₱${item.price.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.primaryBrown),
            ),
          ],
        ),
      ),
    );
  }
}