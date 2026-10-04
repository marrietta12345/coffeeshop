import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/shop_collection.dart';
import '../utils/collections_service.dart';
import '../widgets/shop_photo.dart';
import '../widgets/top_banner.dart';
import 'collections_page.dart';
import 'create_collection_page.dart';

/// Bottom sheet for saving [shop] into any collection — the 8 built-in
/// categories and the user's custom ones. Tap one to add/remove the café
/// (saved instantly), or create a new custom collection with the café
/// already in it. Same sheet style as the collection's "Add Cafés" sheet.
Future<void> showSaveToCollectionSheet(BuildContext context, CoffeeShop shop) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _SaveToCollectionSheet(shop: shop),
  );
}

class _SaveToCollectionSheet extends StatefulWidget {
  final CoffeeShop shop;

  const _SaveToCollectionSheet({required this.shop});

  @override
  State<_SaveToCollectionSheet> createState() => _SaveToCollectionSheetState();
}

class _SaveToCollectionSheetState extends State<_SaveToCollectionSheet> {
  final Stream<List<ShopCollection>> _collections = CollectionsService.collectionsStream();

  Future<void> _toggle(ShopCollection collection, bool isSaved) async {
    try {
      if (isSaved) {
        await CollectionsService.removeShop(collection.id, widget.shop.id);
      } else {
        await CollectionsService.addShop(collection.id, widget.shop.id);
      }
    } catch (_) {
      if (mounted) showTopBanner(context, "Couldn't update collection. Please try again.", isSuccess: false);
    }
  }

  Future<void> _createWithShop(List<ShopCollection> all) async {
    final created = await openCreateCollection(
      context,
      allCollections: all,
      initialShopId: widget.shop.id,
    );
    if (created == true && mounted) showTopBanner(context, 'Saved to your new collection!', isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: StreamBuilder<List<ShopCollection>>(
          stream: _collections,
          builder: (context, snapshot) {
            final all = snapshot.data ?? const <ShopCollection>[];
            // Only collections the user has created or saved to.
            final collections = all.where((c) => c.exists).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ShopCoverImage(shop: shop, width: 44, height: 44),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Save to collection',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                          ),
                          Text(
                            shop.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBrown))
                      : collections.isEmpty
                          ? const Center(
                              child: Text(
                                'No collections yet — create one below.',
                                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                              ),
                            )
                          : ListView.separated(
                              itemCount: collections.length,
                              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFEDEDED)),
                              itemBuilder: (context, index) {
                                final collection = collections[index];
                                final saved = collection.shopIds.contains(shop.id);
                                final count = collection.shopIds.length;
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 2),
                                  onTap: () => _toggle(collection, saved),
                                  leading: CollectionIconTile(icon: collection.icon, size: 44),
                                  title: Text(
                                    collection.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                                  ),
                                  subtitle: Text(
                                    count == 1 ? '1 café' : '$count cafés',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                                  ),
                                  trailing: Icon(
                                    saved ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                    color: saved ? AppColors.primaryBrown : AppColors.textGrey,
                                  ),
                                );
                              },
                            ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBrown,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _createWithShop(all),
                    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    label: const Text(
                      'New Collection',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
