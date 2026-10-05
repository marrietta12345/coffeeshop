import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../utils/saved_shops_service.dart';
import '../utils/page_transitions.dart';
import '../widgets/shop_photo.dart';
import 'shop_detail_page.dart';

/// Lists every shop the signed-in user has hearted, live via Firestore —
/// unsaving a shop here (or anywhere else in the app) removes it
/// instantly from this list.
class SavedShopsPage extends StatelessWidget {
  const SavedShopsPage({super.key});

  Future<CoffeeShop?> _resolveShop(String shopId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('shops').doc(shopId).get();
      if (doc.exists) return CoffeeShop.fromFirestore(doc);
    } catch (_) {
      // Shop may have been deleted — treat as unavailable.
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Saved Shops',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                ),
                child: StreamBuilder<Set<String>>(
                  stream: SavedShopsService.savedShopIdsStream(),
                  builder: (context, snapshot) {
                    final savedIds = snapshot.data ?? {};

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primaryBrown));
                    }

                    if (savedIds.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite_border_rounded, size: 48, color: AppColors.textGrey.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            const Text(
                              'No saved shops yet',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap the heart on any shop to save it here.',
                              style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: savedIds.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final shopId = savedIds.elementAt(index);
                        return FutureBuilder<CoffeeShop?>(
                          future: _resolveShop(shopId),
                          builder: (context, shopSnapshot) {
                            if (!shopSnapshot.hasData) {
                              return const SizedBox(
                                height: 76,
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBrown)),
                              );
                            }
                            final shop = shopSnapshot.data;
                            if (shop == null) return const SizedBox.shrink();
                            return _SavedShopRow(shop: shop);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedShopRow extends StatelessWidget {
  final CoffeeShop shop;

  const _SavedShopRow({required this.shop});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, slideUpRoute(ShopDetailPage(shop: shop))),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ShopPhoto(shop: shop, width: 64, height: 48),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A623)),
                      const SizedBox(width: 2),
                      Text(shop.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
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