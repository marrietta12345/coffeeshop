import 'dart:ui' show Offset;
import 'package:latlong2/latlong.dart';
import '../models/coffee_shop.dart';

/// Keeps every café's pin tappable when several share (almost) the same
/// GPS spot — e.g. cafés on the same floor of a mall. Each café keeps its
/// own saved coordinates; only the pins are drawn a little apart on
/// screen, side by side (wrapping into rows), around that spot.
class MapPinSpread {
  MapPinSpread._();

  /// Cafés closer than this many meters count as the same spot.
  static const double overlapMeters = 15;

  /// Horizontal / vertical pixel gap between spread pins.
  static const double gapX = 38;
  static const double gapY = 46;
  static const int perRow = 4;

  static const Distance _distance = Distance();

  /// Pixel offset for each café id. Cafés alone at their spot get
  /// Offset.zero; a group of n is laid out side by side, centered on the
  /// spot, with extra rows stacked above it — in a stable order (by id) so
  /// pins don't jump around.
  static Map<String, Offset> offsets(List<CoffeeShop> shops) {
    final result = <String, Offset>{};
    final groups = <List<CoffeeShop>>[];
    for (final shop in [...shops]..sort((a, b) => a.id.compareTo(b.id))) {
      final point = LatLng(shop.latitude, shop.longitude);
      List<CoffeeShop>? group;
      for (final g in groups) {
        final anchor = g.first;
        if (_distance.as(LengthUnit.Meter, point, LatLng(anchor.latitude, anchor.longitude)) < overlapMeters) {
          group = g;
          break;
        }
      }
      if (group == null) {
        groups.add([shop]);
      } else {
        group.add(shop);
      }
    }
    for (final group in groups) {
      final n = group.length;
      final rows = (n / perRow).ceil();
      for (var i = 0; i < n; i++) {
        final row = i ~/ perRow;
        final inRow = row == rows - 1 ? n - row * perRow : perRow;
        final col = i % perRow;
        result[group[i].id] = n == 1
            ? Offset.zero
            : Offset((col - (inRow - 1) / 2) * gapX, -row * gapY);
      }
    }
    return result;
  }
}
