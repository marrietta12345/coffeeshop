import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/menu_item.dart';
import '../utils/menu_service.dart';
import '../utils/owner_shop_service.dart';
import '../widgets/owner_page_widgets.dart';

/// Owner "Popular Coffee" tab (formerly Best Sellers). Kafelo doesn't
/// process orders, so there are no sales figures — coffees are ranked by
/// real customer hearts on the menu, filterable by when they were given.
class OwnerPopularCoffeePage extends StatefulWidget {
  const OwnerPopularCoffeePage({super.key});

  @override
  State<OwnerPopularCoffeePage> createState() => _OwnerPopularCoffeePageState();
}

class _OwnerPopularCoffeePageState extends State<OwnerPopularCoffeePage> {
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
            if (shop == null) {
              return const Center(child: Text("We couldn't find your shop.", style: TextStyle(color: AppColors.textGrey)));
            }
            return _PopularBody(key: ValueKey(shop.id), shop: shop);
          },
        ),
      ),
    );
  }
}

class _PopularBody extends StatefulWidget {
  final CoffeeShop shop;

  const _PopularBody({super.key, required this.shop});

  @override
  State<_PopularBody> createState() => _PopularBodyState();
}

class _PopularBodyState extends State<_PopularBody> {
  late final Stream<List<MenuItem>> _menuStream = MenuService.menuStream(widget.shop.id);
  PopularityPeriod _period = PopularityPeriod.week;
  Future<List<PopularCoffee>>? _ranking;
  String? _rankingKey; // period + items + heart totals the ranking was built from

  /// Rebuilds the ranking when the period, the menu or any heart total changes.
  Future<List<PopularCoffee>> _rankingFor(List<MenuItem> items, {bool force = false}) {
    final key = '${_period.name}|${items.map((i) => '${i.id}:${i.likes}:${i.available}:${i.name}:${i.price}').join(',')}';
    if (force || _ranking == null || key != _rankingKey) {
      _rankingKey = key;
      _ranking = MenuService.popular(widget.shop.id, items, _period)..ignore();
    }
    return _ranking!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MenuItem>>(
      stream: _menuStream,
      builder: (context, menuSnap) {
        final items = menuSnap.data;
        return RefreshIndicator(
          color: AppColors.primaryBrown,
          onRefresh: () async {
            if (items == null) return;
            final future = _rankingFor(items, force: true);
            setState(() {});
            await future.then((_) {}, onError: (_) {});
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const OwnerPageHeader(
                title: 'Popular Coffee',
                subtitle: 'Ranked by customer hearts on your menu',
              ),
              const SizedBox(height: 16),
              OwnerSegmentedFilter<PopularityPeriod>(
                values: PopularityPeriod.values,
                selected: _period,
                labelOf: (p) => p.label,
                onSelected: (p) => setState(() => _period = p),
              ),
              const SizedBox(height: 16),
              if (menuSnap.hasError)
                const _Message("Couldn't load your menu. Pull down to refresh.")
              else if (items == null)
                const _Loading()
              else
                FutureBuilder<List<PopularCoffee>>(
                  future: _rankingFor(items),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) return const _Loading();
                    if (snap.hasError) return const _Message("Couldn't load popular coffee. Pull down to refresh.");
                    final ranking = snap.data!;
                    if (ranking.isEmpty) {
                      return const OwnerEmptyState(
                        icon: Icons.local_fire_department_rounded,
                        title: 'No popular coffee yet',
                        message: 'Popular coffee items will appear here as customers interact with your menu.',
                      );
                    }
                    final totalHearts = ranking.fold<int>(0, (sum, e) => sum + e.likes);
                    return Column(
                      children: [
                        _InsightCard(totalHearts: totalHearts, coffees: ranking.length, period: _period),
                        const SizedBox(height: 16),
                        for (var i = 0; i < ranking.length; i++) _PopularRow(rank: i + 1, entry: ranking[i]),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: AppColors.primaryBrown, strokeWidth: 2.5)),
      );
}

class _Message extends StatelessWidget {
  final String text;

  const _Message(this.text);

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
      );
}

/// "Coffee interaction insights" — totals for the chosen period.
class _InsightCard extends StatelessWidget {
  final int totalHearts;
  final int coffees;
  final PopularityPeriod period;

  const _InsightCard({required this.totalHearts, required this.coffees, required this.period});

  @override
  Widget build(BuildContext context) {
    final when = switch (period) {
      PopularityPeriod.week => 'this week',
      PopularityPeriod.month => 'this month',
      PopularityPeriod.allTime => 'so far',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF3E5641), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalHearts ${totalHearts == 1 ? 'heart' : 'hearts'} $when',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Customers hearted $coffees ${coffees == 1 ? 'coffee' : 'coffees'} on your menu',
                  style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PopularRow extends StatelessWidget {
  final int rank;
  final PopularCoffee entry;

  const _PopularRow({required this.rank, required this.entry});

  static const _medals = {1: Color(0xFFE5B53A), 2: Color(0xFFA7ADB4), 3: Color(0xFFCD8A4E)};

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final medal = _medals[rank];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: medal ?? AppColors.inputFill,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: medal != null ? Colors.white : AppColors.textGrey),
            ),
          ),
          const SizedBox(width: 12),
          CoffeeThumb(item: item, size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 3),
                Text(
                  '${item.category} · ${MenuItem.formatPrice(item.price)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
                if (!item.available) ...[
                  const SizedBox(height: 4),
                  const AvailabilityBadge(available: false),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              const Icon(Icons.favorite_rounded, size: 16, color: Color(0xFFE04B4B)),
              const SizedBox(height: 2),
              Text('${entry.likes}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              Text(entry.likes == 1 ? 'heart' : 'hearts', style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
            ],
          ),
        ],
      ),
    );
  }
}
