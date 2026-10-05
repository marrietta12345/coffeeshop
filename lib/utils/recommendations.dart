import '../models/coffee_preferences.dart';
import '../models/coffee_shop.dart';

/// One recommended café and why: the user's preferences it matched.
class Recommendation {
  final CoffeeShop shop;
  final List<String> matched; // labels, e.g. ['Latte', 'Cozy', 'Wi-Fi']
  final int selectedCount; // how many preferences the user selected

  const Recommendation({required this.shop, required this.matched, required this.selectedCount});

  int get score => matched.length;

  /// "83% Match for You" = matched ÷ the user's selected preferences.
  int get percent => matchPercent(matched.length, selectedCount);
}

/// Matched ÷ selected, as a whole percentage (0 when nothing is selected).
int matchPercent(int matched, int selected) => selected == 0 ? 0 : (matched * 100 / selected).round();

/// Ranks [shops] against the user's Coffee Preferences for "Recommended
/// for You", highest match % first. A café earns one point per
/// preference it satisfies (match % = points ÷ the user's selected
/// preferences, so for one user, more points = higher %):
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
    final match = _compare(prefs, shop, shop.menu.map((m) => m.name));
    if (match.matched.isNotEmpty) {
      results.add(Recommendation(shop: shop, matched: match.matched, selectedCount: match.selectedCount));
    }
  }

  results.sort((a, b) {
    final byScore = b.percent.compareTo(a.percent);
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

/// How one café fits the user's Coffee Preferences ("Your Match" on its
/// page): [matched] are the preferences it meets; [notListed] the ones it
/// doesn't list. Worked out fresh from the current data every time —
/// never stored.
class VibeMatch {
  final List<String> matched;
  final List<String> notListed;

  const VibeMatch({required this.matched, required this.notListed});

  int get selectedCount => matched.length + notListed.length;

  /// Share of the user's selected preferences this café meets, 0–100.
  int get percent => matchPercent(matched.length, selectedCount);
}

/// The match between [prefs] and [shop]'s Café Features — the same
/// calculation as Recommended for You, so a café shows the same % in both.
/// Null (nothing shown) when the user hasn't selected preferences or the
/// café matches none of them: no "0% Match", no made-up numbers.
VibeMatch? vibeMatchFor(CoffeePreferences prefs, CoffeeShop shop) {
  if (!prefs.hasAny) return null;
  final match = _compare(prefs, shop, shop.menu.map((m) => m.name));
  return match.matched.isEmpty ? null : match;
}

/// Each of the user's preferences, split into met / not listed by [shop].
VibeMatch _compare(CoffeePreferences prefs, CoffeeShop shop, Iterable<String> menuNames) {
  final shopTypes = shop.coffeeTypes.map(_normalize).toSet();
  final menu = menuNames.map(_normalize).toList();
  final shopMoods = shop.atmospheres.map(_normalize).toSet();
  final shopAmenities = shop.amenities.toSet();
  final matched = <String>[];
  final notListed = <String>[];
  void check(bool wanted, bool has, String label) {
    if (!wanted) return;
    (has ? matched : notListed).add(label);
  }

  for (final type in CoffeePreferences.coffeeTypeOptions) {
    check(prefs.coffeeTypes.contains(type), _servesType(type, shopTypes, menu), type);
  }
  for (final mood in CoffeePreferences.atmosphereOptions) {
    check(prefs.atmospheres.contains(mood), shopMoods.contains(_normalize(mood)), mood);
  }
  for (final entry in CoffeePreferences.amenityLabels.entries) {
    check(prefs.selectedAmenities.contains(entry.key), shopAmenities.contains(entry.key), entry.value);
  }
  return VibeMatch(matched: matched, notListed: notListed);
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
