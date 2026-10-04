import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/shop_collection.dart';

void main() {
  test('there are exactly the 8 requested categories, in order', () {
    expect(CollectionCategory.all.map((c) => c.name).toList(), [
      'Want to Visit',
      'Best Study Spots',
      'Cozy Cafés',
      'Work & Productivity',
      'Best for Hangouts',
      'Hidden Gems',
      'Instagrammable Spots',
      'Late-Night Cafés',
    ]);
  });

  test('My Favorites is not a collection category', () {
    expect(CollectionCategory.all.any((c) => c.name.toLowerCase().contains('favorite')), isFalse);
  });

  test('category ids are unique and valid Firestore document ids', () {
    final ids = CollectionCategory.all.map((c) => c.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(RegExp(r'^[a-z_]+$').hasMatch(id), isTrue, reason: id);
    }
  });

  test('looking a category up by id', () {
    expect(CollectionCategory.byId('hidden_gems')!.name, 'Hidden Gems');
    expect(CollectionCategory.byId('my_favorites'), isNull);
  });

  group('Custom collections', () {
    test('icon choices have unique keys and include the default', () {
      final keys = CollectionIconOption.all.map((o) => o.key).toList();
      expect(keys.toSet().length, keys.length);
      expect(keys, contains(CollectionIconOption.defaultKey));
    });

    test('unknown or missing icon keys fall back to the bookmark icon', () {
      expect(CollectionIconOption.iconFor('not-a-key'), Icons.bookmark_rounded);
      expect(CollectionIconOption.iconFor(null), Icons.bookmark_rounded);
      expect(CollectionIconOption.iconFor('leaf'), Icons.eco_rounded);
    });

    test('a collection is custom unless its id is a built-in category', () {
      const custom = ShopCollection(id: 'aB3xYz', name: 'Best Matcha', iconKey: 'leaf');
      expect(custom.isCustom, isTrue);
      expect(custom.icon, Icons.eco_rounded);

      const builtIn = ShopCollection(id: 'cozy_cafes', name: 'Cozy Cafés');
      expect(builtIn.isCustom, isFalse);
      expect(builtIn.icon, Icons.weekend_rounded);
    });
  });

  group('Only created collections are shown', () {
    test('an unstarted built-in category is marked as not existing', () {
      final c = ShopCollection.empty(CollectionCategory.byId('want_to_visit')!);
      expect(c.exists, isFalse);
      expect(c.shopIds, isEmpty);
    });

    test('every built-in category icon is also a pickable icon', () {
      for (final category in CollectionCategory.all) {
        expect(CollectionIconOption.iconFor(category.iconKey), category.icon, reason: category.name);
      }
    });
  });
}
