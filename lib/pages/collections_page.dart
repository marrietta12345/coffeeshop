import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/shop_collection.dart';
import '../utils/collections_service.dart';
import '../utils/page_transitions.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/top_banner.dart';
import 'collection_detail_page.dart';
import 'create_collection_page.dart';

/// The user's collections — only the ones they've actually created or
/// saved cafés to (built-in categories they've started, plus custom
/// collections with their own name and icon). Each card shows the icon,
/// name, and how many cafés are saved in it, with a clear "Create
/// Collection" option. (Favorites is a separate feature — see
/// SavedShopsPage.)
class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final Stream<List<ShopCollection>> _collections = CollectionsService.collectionsStream();
  List<ShopCollection> _latest = const [];

  Future<void> _createCustom() async {
    final created = await openCreateCollection(context, allCollections: _latest);
    if (created == true && mounted) showTopBanner(context, 'Collection created!', isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: 'My Collections',
      action: IconButton(
        icon: const Icon(Icons.add_rounded, color: AppColors.primaryBrown),
        tooltip: 'Create Collection',
        onPressed: _createCustom,
      ),
      child: StreamBuilder<List<ShopCollection>>(
        stream: _collections,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('Collections: could not load: ${snapshot.error}');
            return const SettingsEmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load your collections",
              subtitle: 'Check your connection and try again.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryBrown));
          }
          _latest = snapshot.data!;
          // Only collections the user has created or saved to.
          final collections = _latest.where((c) => c.exists).toList();

          if (collections.isEmpty) {
            return SettingsEmptyState(
              icon: Icons.bookmarks_outlined,
              title: 'No collections yet',
              subtitle: 'Create a collection to organize cafés your way — like "Best Matcha" or "Want to Visit".',
              action: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrown,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _createCustom,
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                label: const Text('Create Collection', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            );
          }

          return ListView(
            children: [
              for (final c in collections) ...[_CollectionRow(collection: c), const SizedBox(height: 12)],
              _CreateCollectionRow(onTap: _createCustom),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

class _CollectionRow extends StatelessWidget {
  final ShopCollection collection;

  const _CollectionRow({required this.collection});

  @override
  Widget build(BuildContext context) {
    final count = collection.shopIds.length;
    return GestureDetector(
      onTap: () => Navigator.push(context, slideFadeRoute(CollectionDetailPage(collectionId: collection.id))),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            CollectionIconTile(icon: collection.icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    count == 1 ? '1 café' : '$count cafés',
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
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

/// "+ Add Collection" row — same shape as a collection card, with an
/// outlined look so it reads as an action.
class _CreateCollectionRow extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateCollectionRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryBrown.withOpacity(0.35), width: 1.4),
        ),
        child: const Row(
          children: [
            CollectionIconTile(icon: Icons.add_rounded),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Collection',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryBrown),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Choose a name and an icon',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey),
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

/// The brown-tinted rounded tile holding a category's icon — shared by
/// the collections list, a collection's page, and the save sheet.
class CollectionIconTile extends StatelessWidget {
  final IconData icon;
  final double size;

  const CollectionIconTile({super.key, required this.icon, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryBrown.withOpacity(0.12),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Icon(icon, color: AppColors.primaryBrown, size: size * 0.46),
    );
  }
}
