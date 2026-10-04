import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// One of the fixed Collection categories every user has. The [id] is
/// also the Firestore document id under `users/{uid}/collections/`.
class CollectionCategory {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String iconKey; // matching CollectionIconOption key

  const CollectionCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.iconKey,
  });

  static const List<CollectionCategory> all = [
    CollectionCategory(
      id: 'want_to_visit',
      name: 'Want to Visit',
      description: 'Cafés you plan to visit.',
      icon: Icons.location_on_rounded,
      iconKey: 'pin',
    ),
    CollectionCategory(
      id: 'best_study_spots',
      name: 'Best Study Spots',
      description: 'Cafés made for studying and schoolwork.',
      icon: Icons.menu_book_rounded,
      iconKey: 'book',
    ),
    CollectionCategory(
      id: 'cozy_cafes',
      name: 'Cozy Cafés',
      description: 'Comfortable, relaxing, and cozy cafés.',
      icon: Icons.weekend_rounded,
      iconKey: 'sofa',
    ),
    CollectionCategory(
      id: 'work_productivity',
      name: 'Work & Productivity',
      description: 'Cafés for working, assignments, and getting things done.',
      icon: Icons.laptop_mac_rounded,
      iconKey: 'laptop',
    ),
    CollectionCategory(
      id: 'best_for_hangouts',
      name: 'Best for Hangouts',
      description: 'Cafés for meeting and spending time with friends.',
      icon: Icons.groups_rounded,
      iconKey: 'people',
    ),
    CollectionCategory(
      id: 'hidden_gems',
      name: 'Hidden Gems',
      description: 'Lesser-known, underrated cafés worth discovering.',
      icon: Icons.diamond_rounded,
      iconKey: 'gem',
    ),
    CollectionCategory(
      id: 'instagrammable_spots',
      name: 'Instagrammable Spots',
      description: 'Aesthetic interiors and great photo spots.',
      icon: Icons.photo_camera_rounded,
      iconKey: 'camera',
    ),
    CollectionCategory(
      id: 'late_night_cafes',
      name: 'Late-Night Cafés',
      description: 'Cafés for evening and nighttime visits.',
      icon: Icons.dark_mode_rounded,
      iconKey: 'moon',
    ),
  ];

  static CollectionCategory? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// Icons a user can pick for a custom collection. Stored by [key] so the
/// saved value stays stable even if the icon set grows.
class CollectionIconOption {
  final String key;
  final IconData icon;

  const CollectionIconOption(this.key, this.icon);

  static const List<CollectionIconOption> all = [
    CollectionIconOption('bookmark', Icons.bookmark_rounded),
    CollectionIconOption('pin', Icons.location_on_rounded),
    CollectionIconOption('book', Icons.menu_book_rounded),
    CollectionIconOption('sofa', Icons.weekend_rounded),
    CollectionIconOption('laptop', Icons.laptop_mac_rounded),
    CollectionIconOption('people', Icons.groups_rounded),
    CollectionIconOption('gem', Icons.diamond_rounded),
    CollectionIconOption('camera', Icons.photo_camera_rounded),
    CollectionIconOption('moon', Icons.dark_mode_rounded),
    CollectionIconOption('coffee', Icons.coffee_rounded),
    CollectionIconOption('cafe', Icons.local_cafe_rounded),
    CollectionIconOption('tea', Icons.emoji_food_beverage_rounded),
    CollectionIconOption('leaf', Icons.eco_rounded),
    CollectionIconOption('quiet', Icons.volume_off_rounded),
    CollectionIconOption('school', Icons.school_rounded),
    CollectionIconOption('savings', Icons.savings_rounded),
    CollectionIconOption('heart', Icons.favorite_rounded),
    CollectionIconOption('star', Icons.star_rounded),
    CollectionIconOption('cake', Icons.cake_rounded),
    CollectionIconOption('icecream', Icons.icecream_rounded),
    CollectionIconOption('music', Icons.music_note_rounded),
    CollectionIconOption('wifi', Icons.wifi_rounded),
    CollectionIconOption('pets', Icons.pets_rounded),
    CollectionIconOption('nature', Icons.park_rounded),
    CollectionIconOption('flower', Icons.local_florist_rounded),
    CollectionIconOption('sparkle', Icons.auto_awesome_rounded),
    CollectionIconOption('car', Icons.directions_car_rounded),
  ];

  static const String defaultKey = 'bookmark';

  static IconData iconFor(String? key) {
    for (final option in all) {
      if (option.key == key) return option.icon;
    }
    return Icons.bookmark_rounded;
  }
}

/// The cafés saved in one collection, stored at
/// `users/{uid}/collections/{id}`:
///  * a built-in category — id is the category id; it has a document
///    only once the user creates it or saves a café to it ([exists]);
///  * a custom collection the user created — auto id, with its own
///    `name` and `icon` key.
class ShopCollection {
  final String id;
  final String name;
  final List<String> shopIds;
  final String? iconKey; // custom collections only
  final DateTime? createdAt;
  final bool exists; // false = built-in category the user hasn't started

  const ShopCollection({
    required this.id,
    required this.name,
    this.shopIds = const [],
    this.iconKey,
    this.createdAt,
    this.exists = true,
  });

  CollectionCategory? get category => CollectionCategory.byId(id);

  bool get isCustom => category == null;

  IconData get icon => category?.icon ?? CollectionIconOption.iconFor(iconKey);

  factory ShopCollection.empty(CollectionCategory category) =>
      ShopCollection(id: category.id, name: category.name, exists: false);

  factory ShopCollection.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ShopCollection(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Untitled',
      shopIds: (data['shopIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      iconKey: data['icon'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
