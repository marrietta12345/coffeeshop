import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/shop_collection.dart';
import '../utils/collections_service.dart';
import '../utils/page_transitions.dart';
import '../utils/shop_lookup.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/shop_photo.dart';
import '../widgets/top_banner.dart';
import 'collections_page.dart';
import 'create_collection_page.dart';
import 'shop_detail_page.dart';

/// One collection's saved cafés — cover image, name, location and rating
/// for each. Live-updates as cafés are added/removed. Custom collections
/// also get an Edit (name/icon) and Delete menu.
class CollectionDetailPage extends StatelessWidget {
  final String collectionId;

  const CollectionDetailPage({super.key, required this.collectionId});

  Future<void> _remove(BuildContext context, CoffeeShop shop) async {
    try {
      await CollectionsService.removeShop(collectionId, shop.id);
      if (context.mounted) showTopBanner(context, 'Removed ${shop.name}', isSuccess: true);
    } catch (_) {
      if (context.mounted) showTopBanner(context, "Couldn't remove café. Please try again.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = CollectionCategory.byId(collectionId);

    return StreamBuilder<ShopCollection?>(
      stream: CollectionsService.collectionStream(collectionId),
      builder: (context, snapshot) {
        final collection = snapshot.data;

        // A custom collection that was deleted (e.g. from another device).
        if (collection == null && snapshot.connectionState == ConnectionState.active) {
          return const SettingsPageScaffold(
            title: 'Collection',
            child: SettingsEmptyState(
              icon: Icons.bookmark_remove_outlined,
              title: 'Collection not found',
              subtitle: 'It may have been deleted.',
            ),
          );
        }

        return SettingsPageScaffold(
          title: collection?.name ?? category?.name ?? 'Collection',
          action: collection != null ? _CollectionMenu(collection: collection) : null,
          child: collection == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBrown))
              : Column(
                  children: [
                    ...[
                      Row(
                        children: [
                          CollectionIconTile(icon: collection.icon, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category?.description ?? 'Your own collection.',
                                  style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.35),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  collection.shopIds.length == 1 ? '1 café saved' : '${collection.shopIds.length} cafés saved',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    Expanded(
                      child: collection.shopIds.isEmpty
                          ? const SettingsEmptyState(
                              icon: Icons.local_cafe_outlined,
                              title: 'No cafés here yet',
                              subtitle: 'Tap "Add Cafés" to start building this collection.',
                            )
                          : ListView.separated(
                              itemCount: collection.shopIds.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final shopId = collection.shopIds[index];
                                return ResolvedShopRow(
                                  key: ValueKey(shopId),
                                  shopId: shopId,
                                  useCoverImage: true,
                                  detailBuilder: (shop) =>
                                      shop.rating > 0 ? '★ ${shop.rating.toStringAsFixed(1)}' : 'No ratings yet',
                                  onTap: (shop) => Navigator.push(context, slideUpRoute(ShopDetailPage(shop: shop))),
                                  trailingBuilder: (shop) => IconButton(
                                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.textGrey),
                                    tooltip: 'Remove from collection',
                                    onPressed: () => _remove(context, shop),
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
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                          ),
                          builder: (_) => _AddCafesSheet(collectionId: collectionId),
                        ),
                        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        label: const Text(
                          'Add Cafés',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// Bottom sheet listing every café with an add/remove toggle. Changes
/// save immediately, so there's no separate "Done" step to forget.
class _AddCafesSheet extends StatefulWidget {
  final String collectionId;

  const _AddCafesSheet({required this.collectionId});

  @override
  State<_AddCafesSheet> createState() => _AddCafesSheetState();
}

class _AddCafesSheetState extends State<_AddCafesSheet> {
  late final Future<List<CoffeeShop>> _shopsFuture = fetchAllShops();
  late final Stream<ShopCollection?> _collectionStream = CollectionsService.collectionStream(widget.collectionId);
  String _query = '';

  Future<void> _toggle(CoffeeShop shop, bool isInCollection) async {
    try {
      if (isInCollection) {
        await CollectionsService.removeShop(widget.collectionId, shop.id);
      } else {
        await CollectionsService.addShop(widget.collectionId, shop.id);
      }
    } catch (_) {
      if (mounted) showTopBanner(context, "Couldn't update collection. Please try again.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
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
            const Text('Add Cafés', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search cafés',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textGrey),
                filled: true,
                fillColor: AppColors.inputFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<CoffeeShop>>(
                future: _shopsFuture,
                builder: (context, shopsSnapshot) {
                  if (!shopsSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primaryBrown));
                  }
                  final shops = shopsSnapshot.data!
                      .where((s) =>
                          _query.isEmpty ||
                          s.name.toLowerCase().contains(_query) ||
                          s.address.toLowerCase().contains(_query) ||
                          (s.mallName?.toLowerCase().contains(_query) ?? false))
                      .toList();

                  return StreamBuilder<ShopCollection?>(
                    stream: _collectionStream,
                    builder: (context, collectionSnapshot) {
                      final inCollection = collectionSnapshot.data?.shopIds.toSet() ?? <String>{};
                      if (shops.isEmpty) {
                        return const Center(
                          child: Text('No cafés match your search.', style: TextStyle(color: AppColors.textGrey)),
                        );
                      }
                      return ListView.separated(
                        itemCount: shops.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEDEDED)),
                        itemBuilder: (context, index) {
                          final shop = shops[index];
                          final added = inCollection.contains(shop.id);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            onTap: () => _toggle(shop, added),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: ShopCoverImage(shop: shop, width: 52, height: 39),
                            ),
                            title: Text(
                              shop.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                            ),
                            subtitle: Text(
                              shop.locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                            ),
                            trailing: Icon(
                              added ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                              color: added ? AppColors.primaryBrown : AppColors.textGrey,
                            ),
                          );
                        },
                      );
                    },
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

/// ⋮ menu on a collection's page: Edit name & icon (custom collections
/// only) and Delete (removes it from the user's list; a built-in category
/// just goes back to being a suggestion).
class _CollectionMenu extends StatelessWidget {
  final ShopCollection collection;

  const _CollectionMenu({required this.collection});

  Future<void> _edit(BuildContext context) async {
    final all = await CollectionsService.collectionsStream().first;
    if (!context.mounted) return;
    final saved = await openCreateCollection(context, allCollections: all, existing: collection);
    if (saved == true && context.mounted) showTopBanner(context, 'Collection updated!', isSuccess: true);
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete collection?'),
        content: Text(
          "\"${collection.name}\" will be removed. The cafés themselves won't be affected.",
          style: const TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD64545)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // Grab the navigator first: once deleted, this page rebuilds without
    // this menu, so its own context goes away.
    final navigator = Navigator.of(context);
    try {
      await CollectionsService.deleteCollection(collection.id);
      navigator.pop();
      if (navigator.context.mounted) {
        showTopBanner(navigator.context, '"${collection.name}" deleted', isSuccess: true);
      }
    } catch (_) {
      if (context.mounted) showTopBanner(context, "Couldn't delete collection. Please try again.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      onSelected: (value) {
        if (value == 'edit') _edit(context);
        if (value == 'delete') _delete(context);
      },
      itemBuilder: (context) => [
        if (collection.isCustom)
          const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 18, color: AppColors.textDark),
              SizedBox(width: 10),
              Text('Edit name & icon'),
            ]),
          ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFD64545)),
            SizedBox(width: 10),
            Text('Delete', style: TextStyle(color: Color(0xFFD64545))),
          ]),
        ),
      ],
    );
  }
}
