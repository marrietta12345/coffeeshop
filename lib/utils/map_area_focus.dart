import 'package:flutter/foundation.dart';
import '../models/coffee_shop.dart';
import 'cafe_search.dart';

/// A place picked in Explore search ("Bayanihan", "Near FSUU") to show on
/// the map: only its cafés are pinned and the map zooms to fit them.
class MapArea {
  final String label;
  final SuggestionKind kind;
  final List<CoffeeShop> shops;

  const MapArea({required this.label, required this.kind, required this.shops});

  Set<String> get shopIds => {for (final s in shops) s.id};
}

/// Hands a picked place from the Explore tab to the Map tab (and makes the
/// bottom navigation switch to the Map).
class MapAreaFocus {
  MapAreaFocus._();

  static final ValueNotifier<MapArea?> current = ValueNotifier<MapArea?>(null);

  static void show(MapArea area) => current.value = area;

  static void clear() => current.value = null;
}
