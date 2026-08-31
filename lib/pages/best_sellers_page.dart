import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/menu_item.dart';
import '../widgets/menu_item_image.dart';

/// Full "Best Sellers" listing for a single shop — every menu item
/// sorted by likes, most-loved first. Reached via "See all" from the
/// Menu tab's Most Loved section.
class BestSellersPage extends StatelessWidget {
  final CoffeeShop shop;
  final List<MenuItem> menuItems;

  const BestSellersPage({super.key, required this.shop, required this.menuItems});

  @override
  Widget build(BuildContext context) {
    final sorted = List<MenuItem>.of(menuItems)..sort((a, b) => b.likes.compareTo(a.likes));

    return Scaffold(
      backgroundColor: Colors.white,
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
                    '${shop.name} — Best Sellers',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                ],
              ),
            ),
            Expanded(
              child: sorted.isEmpty
                  ? const Center(
                      child: Text('No menu items yet.', style: TextStyle(color: AppColors.textGrey)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _BestSellerListItem(
                        rank: index + 1,
                        item: sorted[index],
                        shop: shop,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestSellerListItem extends StatelessWidget {
  final int rank;
  final MenuItem item;
  final CoffeeShop shop;

  const _BestSellerListItem({required this.rank, required this.item, required this.shop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MenuItemImage(item: item, shop: shop, fallbackIndex: rank + 30, width: 64, height: 64),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark),
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (item.originalPrice != null) ...[
                      Text(
                        '₱${item.originalPrice!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      '₱${item.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: item.originalPrice != null ? const Color(0xFFE04B4B) : AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Icon(Icons.favorite_rounded, size: 16, color: Color(0xFFE04B4B)),
              const SizedBox(height: 2),
              Text('${item.likes}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            ],
          ),
        ],
      ),
    );
  }
}