import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/menu_item.dart';
import '../utils/menu_service.dart';
import '../utils/page_transitions.dart';
import '../widgets/best_seller_tile.dart';
import '../widgets/top_banner.dart';
import 'coffee_detail_page.dart';

/// Opens a coffee's details from outside its café page (Explore's Best
/// Sellers). Hearts work as on the café page; owners can't heart or
/// review their own café's coffee.
Future<void> openCafeCoffee(BuildContext context, CoffeeShop shop, MenuItem item) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final ownCafe = shop.ownerId != null && shop.ownerId == uid;
  Set<String> liked;
  try {
    liked = await MenuService.likedItemIds(shop.id, [item]);
  } catch (e) {
    debugPrint('Best Sellers: could not check hearts: $e');
    liked = {};
  }
  if (!context.mounted) return;
  await Navigator.push(
    context,
    slideUpRoute(CoffeeDetailPage(
      shop: shop,
      item: item,
      isLiked: () => liked.contains(item.id),
      onToggleLike: ownCafe
          ? null
          : () async {
              final nowLiked = await MenuService.toggleLike(item);
              nowLiked ? liked.add(item.id) : liked.remove(item.id);
            },
      canReview: !ownCafe,
    )),
  );
}

/// Explore → Best Sellers → "View all": every café's best sellers —
/// café-marked Best Sellers first, then the most-hearted coffees
/// (see [MenuService.rankBestSellers]).
class AllBestSellersPage extends StatefulWidget {
  final List<CoffeeShop> shops;

  const AllBestSellersPage({super.key, required this.shops});

  @override
  State<AllBestSellersPage> createState() => _AllBestSellersPageState();
}

class _AllBestSellersPageState extends State<AllBestSellersPage> {
  List<CafeCoffee>? _coffees; // null while loading

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final coffees = MenuService.rankBestSellers(await MenuService.cafeMenus(widget.shops));
    if (mounted) setState(() => _coffees = coffees);
  }

  Future<void> _open(CafeCoffee coffee) async {
    try {
      await openCafeCoffee(context, coffee.shop, coffee.item);
    } catch (e) {
      debugPrint('Best Sellers: could not open coffee: $e');
      if (mounted) showTopBanner(context, "Couldn't open this coffee. Please try again.", isSuccess: false);
    }
    _load(); // hearts may have changed
  }

  @override
  Widget build(BuildContext context) {
    final coffees = _coffees;
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
                  const Text(
                    'Best Sellers',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                ],
              ),
            ),
            Expanded(
              child: coffees == null
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBrown))
                  : coffees.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'No best sellers yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textGrey),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primaryBrown,
                          onRefresh: _load,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: coffees.length,
                            itemBuilder: (context, index) => BestSellerTile(
                              item: coffees[index].item,
                              shop: coffees[index].shop,
                              onTap: () => _open(coffees[index]),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
