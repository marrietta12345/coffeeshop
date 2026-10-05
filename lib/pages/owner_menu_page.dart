import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/menu_item.dart';
import '../utils/menu_service.dart';
import '../utils/owner_shop_service.dart';
import '../utils/page_transitions.dart';
import '../widgets/coffee_badges.dart';
import '../widgets/owner_page_widgets.dart';
import '../widgets/top_banner.dart';
import 'owner_coffee_form_page.dart';

/// Owner "Menu" tab — manage the shop's coffee: add, edit, delete and
/// switch items between Available / Unavailable. Coffee only.
class OwnerMenuPage extends StatefulWidget {
  const OwnerMenuPage({super.key});

  @override
  State<OwnerMenuPage> createState() => _OwnerMenuPageState();
}

class _OwnerMenuPageState extends State<OwnerMenuPage> {
  final Stream<CoffeeShop?> _shopStream = OwnerShopService.myShopStream();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ownerPageBackground,
      child: SafeArea(
        child: StreamBuilder<CoffeeShop?>(
          stream: _shopStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primaryBrown));
            }
            final shop = snapshot.data;
            if (shop == null) return const _NoShop();
            return _MenuBody(key: ValueKey(shop.id), shop: shop);
          },
        ),
      ),
    );
  }
}

class _NoShop extends StatelessWidget {
  const _NoShop();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text("We couldn't find your shop. Please contact support.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGrey)),
        ),
      );
}

class _MenuBody extends StatefulWidget {
  final CoffeeShop shop;

  const _MenuBody({super.key, required this.shop});

  @override
  State<_MenuBody> createState() => _MenuBodyState();
}

class _MenuBodyState extends State<_MenuBody> {
  late final Stream<List<MenuItem>> _menuStream = MenuService.menuStream(widget.shop.id);
  List<MenuItem> _items = const [];
  String? _category; // category chip filter; null = All
  final Set<String> _busy = {}; // items with a pending availability change

  Future<void> _openForm({MenuItem? existing}) async {
    final saved = await Navigator.push<bool>(
      context,
      slideUpRoute(OwnerCoffeeFormPage(shop: widget.shop, existing: existing, menu: _items)),
    );
    if (saved == true && mounted) {
      showTopBanner(context, existing == null ? 'Coffee added to your menu!' : 'Changes saved!', isSuccess: true);
    }
  }

  Future<void> _setAvailable(MenuItem item, bool available) async {
    setState(() => _busy.add(item.id));
    try {
      await MenuService.setAvailable(widget.shop.id, item.id, available);
    } catch (e) {
      debugPrint('Availability update failed: $e');
      if (mounted) showTopBanner(context, "Couldn't update availability. Please try again.", isSuccess: false);
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  Future<void> _delete(MenuItem item) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete Coffee?',
      message: 'Are you sure you want to delete this coffee item?',
    );
    if (!confirmed || !mounted) return;
    try {
      await MenuService.deleteItem(item);
      if (mounted) showTopBanner(context, '${item.name} was deleted.', isSuccess: true);
    } catch (e) {
      debugPrint('Deleting coffee failed: $e');
      if (mounted) showTopBanner(context, "Couldn't delete this coffee. Please try again.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MenuItem>>(
      stream: _menuStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Couldn't load your menu.", style: TextStyle(color: AppColors.textGrey)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryBrown));
        }
        _items = snapshot.data!;
        final unavailable = _items.where((i) => !i.available).length;
        final categories = CoffeeCategory.used(_items);
        final category = categories.contains(_category) ? _category : null; // its last coffee may be gone

        Widget card(MenuItem item) => _CoffeeCard(
              item: item,
              busy: _busy.contains(item.id),
              onAvailableChanged: (v) => _setAvailable(item, v),
              onEdit: () => _openForm(existing: item),
              onDelete: () => _delete(item),
            );

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            OwnerPageHeader(
              title: 'Menu',
              subtitle: _items.isEmpty
                  ? 'Manage the coffee your café offers'
                  : '${_items.length} ${_items.length == 1 ? 'coffee' : 'coffees'}'
                      '${unavailable > 0 ? ' · $unavailable unavailable' : ''}',
              trailing: _items.isEmpty ? null : OwnerPillButton(icon: Icons.add_rounded, label: 'Add Coffee', onPressed: () => _openForm()),
            ),
            const SizedBox(height: 20),
            if (_items.isEmpty)
              OwnerEmptyState(
                icon: Icons.local_cafe_rounded,
                title: 'Your coffee menu is empty',
                message: 'Add your first coffee item to start showcasing your menu.',
                action: OwnerPillButton(icon: Icons.add_rounded, label: 'Add Coffee', onPressed: () => _openForm()),
              )
            else ...[
              CoffeeCategoryChips(
                categories: categories,
                selected: category,
                onSelected: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: 18),
              // All: grouped by category. A chip: just that category.
              for (final (name, items) in CoffeeCategory.group(_items))
                if (category == null || category == name) ...[
                  if (category == null) ...[
                    CoffeeSectionTitle(name, count: items.length),
                    const SizedBox(height: 10),
                  ],
                  for (final item in items) card(item),
                  const SizedBox(height: 8),
                ],
            ],
          ],
        );
      },
    );
  }
}

class _CoffeeCard extends StatelessWidget {
  final MenuItem item;
  final bool busy;
  final ValueChanged<bool> onAvailableChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CoffeeCard({
    required this.item,
    required this.busy,
    required this.onAvailableChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoffeeThumb(item: item),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: item.available ? AppColors.textDark : AppColors.textGrey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          MenuItem.formatPrice(item.price),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryBrown),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        CoffeeCategoryTag(category: item.category),
                        AvailabilityBadge(available: item.available),
                        for (final badge in coffeeBadges(item, includeUnavailable: false)) CoffeeBadge(badge, solid: false),
                      ],
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.35),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFFF0ECE8)),
          Row(
            children: [
              SizedBox(
                height: 40,
                child: FittedBox(
                  child: Switch(
                    value: item.available,
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF2E9E5B),
                    onChanged: busy ? null : onAvailableChanged,
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  'Available',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryBrown,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD64545),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
