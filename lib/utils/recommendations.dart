import '../models/coffee_preferences.dart';
import '../models/coffee_shop.dart';

/// One recommended café and why: the user's preferences it matched.
class Recommendation {
  final CoffeeShop shop;
  final List<String> matched; // labels, e.g. ['Latte', 'Cozy', 'Wi-Fi']

  const Recommendation({required this.shop, required this.matched});

  int get score => matched.length;
}

/// Ranks [shops] against the user's Coffee Preferences for "Recommended
/// for You". A café earns one point per preference it satisfies:
///  * each selected coffee type it serves — listed in its features, or
///    found in one of its menu item names (e.g. "Hazelnut Latte" → Latte);
///  * each selected atmosphere it has;
///  * each switched-on must-have it offers.
/// Cafés matching nothing are left out (no misleading picks); the rest are
/// ordered by most matches, then rating, then [distanceMeters] if given.
/// Returns an empty list when the user hasn't chosen any preferences.
List<Recommendation> recommendCafes(
  CoffeePreferences prefs,
  List<CoffeeShop> shops, {
  double Function(CoffeeShop shop)? distanceMeters,
}) {
  if (!prefs.hasAny) return const [];

  final results = <Recommendation>[];
  for (final shop in shops) {
    final shopTypes = shop.coffeeTypes.map(_normalize).toSet();
    final menuNames = shop.menu.map((m) => _normalize(m.name)).toList();
    final shopMoods = shop.atmospheres.map(_normalize).toSet();
    final shopAmenities = shop.amenities.toSet();

    final matched = <String>[
      for (final type in CoffeePreferences.coffeeTypeOptions)
        if (prefs.coffeeTypes.contains(type) && _servesType(type, shopTypes, menuNames)) type,
      for (final mood in CoffeePreferences.atmosphereOptions)
        if (prefs.atmospheres.contains(mood) && shopMoods.contains(_normalize(mood))) mood,
      for (final entry in CoffeePreferences.amenityLabels.entries)
        if (prefs.selectedAmenities.contains(entry.key) && shopAmenities.contains(entry.key)) entry.value,
    ];
    if (matched.isNotEmpty) results.add(Recommendation(shop: shop, matched: matched));
  }

  results.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final byRating = b.shop.rating.compareTo(a.shop.rating);
    if (byRating != 0) return byRating;
    if (distanceMeters != null) {
      final byDistance = distanceMeters(a.shop).compareTo(distanceMeters(b.shop));
      if (byDistance != 0) return byDistance;
    }
    return a.shop.name.toLowerCase().compareTo(b.shop.name.toLowerCase());
  });
  return results;
}

bool _servesType(String type, Set<String> shopTypes, List<String> menuNames) {
  final key = _normalize(type);
  if (shopTypes.contains(key)) return true;
  // "Non-coffee" isn't a drink name, so only the café's own features count.
  if (key == _normalize('Non-coffee')) return false;
  return menuNames.any((name) => name.contains(key));
}

/// Case/spacing/punctuation-insensitive form, so "Pour-over",
/// "Pour Over" and "pourover" all compare equal.
String _normalize(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
