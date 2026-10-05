import 'package:cloud_firestore/cloud_firestore.dart';

/// Coffee-only menu categories. The first six reuse the spelling of the
/// existing Coffee Preferences coffee types (see coffee_preferences.dart)
/// so menus and preferences match; Kafelo menus hold coffee only — no
/// tea, food, pastries or other non-coffee items.
class CoffeeCategory {
  CoffeeCategory._();

  static const List<String> all = [
    'Espresso',
    'Latte',
    'Cappuccino',
    'Americano',
    'Cold Brew',
    'Pour-over',
    'Mocha',
    'Macchiato',
    'Spanish Latte',
    'Iced Coffee',
    'Hot Coffee',
    'Other Coffee',
  ];

  /// [items] grouped by category, in the order above (categories with no
  /// coffee left out). Within a category: featured first, then newest.
  static List<(String, List<MenuItem>)> group(List<MenuItem> items) {
    return [
      for (final category in all)
        if (items.any((i) => i.category == category))
          (category, items.where((i) => i.category == category).toList()..sort(_menuOrder)),
    ];
  }

  /// Categories that have at least one coffee, in menu order.
  static List<String> used(List<MenuItem> items) => [for (final c in all) if (items.any((i) => i.category == c)) c];

  static int _menuOrder(MenuItem a, MenuItem b) {
    if (a.featured != b.featured) return a.featured ? -1 : 1;
    return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
  }
}

/// A coffee on a shop's menu, stored at `shops/{shopId}/menu/{itemId}`.
/// `likes` is the number of customers who hearted it (one heart per
/// customer, see MenuService) — the real interaction behind Popular Coffee.
class MenuItem {
  final String id;
  final String shopId;
  final String name;
  final String description;
  final double price;
  final double? originalPrice; // set when the item is on sale/discounted
  final String category; // one of CoffeeCategory.all
  final bool available; // false = temporarily unavailable, still listed
  final bool bestSeller; // set by the owner — not computed from sales
  final bool featured; // shown at the top of the shop's menu
  final int likes;
  final String? imageUrl; // real uploaded photo (Supabase Storage), if any
  final DateTime? createdAt;

  const MenuItem({
    this.id = '',
    this.shopId = '',
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    this.category = 'Other Coffee',
    this.available = true,
    this.bestSeller = false,
    this.featured = false,
    this.likes = 0,
    this.imageUrl,
    this.createdAt,
  });

  bool get hasImage => imageUrl?.isNotEmpty ?? false;

  /// How long a coffee shows the "New" badge after it's added.
  static const Duration newFor = Duration(days: 14);

  /// Added within the last [newFor].
  bool isNewAt(DateTime now) => createdAt != null && now.difference(createdAt!) < newFor;

  factory MenuItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final category = data['category'] as String?;
    return MenuItem(
      id: doc.id,
      shopId: doc.reference.parent.parent?.id ?? '',
      name: (data['name'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      category: CoffeeCategory.all.contains(category) ? category! : 'Other Coffee',
      available: (data['available'] as bool?) ?? true,
      bestSeller: (data['bestSeller'] as bool?) ?? false,
      featured: (data['featured'] as bool?) ?? false,
      likes: (data['likeCount'] as num?)?.toInt() ?? 0,
      imageUrl: data['imageUrl'] as String?,
      // A just-saved item's server timestamp reads as null until saved.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// "₱120" or "₱120.50".
  static String formatPrice(double price) =>
      price == price.roundToDouble() ? '₱${price.toStringAsFixed(0)}' : '₱${price.toStringAsFixed(2)}';
}
