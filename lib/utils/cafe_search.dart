import '../models/coffee_preferences.dart';
import '../models/coffee_shop.dart';

/// What a search suggestion refers to.
enum SuggestionKind { cafe, location, coffeeType, atmosphere, feature }

/// One autocomplete suggestion for the Explore search bar, built from
/// the real café list. [value] is what gets matched when it's picked
/// (a shop id for [SuggestionKind.cafe], an amenity key for features,
/// otherwise the label itself).
class SearchSuggestion {
  final SuggestionKind kind;
  final String label;
  final String value;
  final int cafeCount; // how many cafés it leads to
  final CoffeeShop? shop; // for café suggestions

  const SearchSuggestion({
    required this.kind,
    required this.label,
    required this.value,
    required this.cafeCount,
    this.shop,
  });
}

/// Café search for the Explore page — all matching is case-, accent- and
/// punctuation-insensitive, and works on partial input ("star" finds
/// "Star Coffee", "cafe" finds "Cafés").
class CafeSearch {
  CafeSearch._();

  static const int _maxCafes = 5;
  static const int _maxPerGroup = 3;

  /// Autocomplete suggestions for [query]: matching cafés first, then
  /// locations/malls, coffee types, atmospheres and features that at least
  /// one café actually has. Empty for an empty query.
  static List<SearchSuggestion> suggestions(String query, List<CoffeeShop> shops) {
    final q = normalize(query);
    if (q.isEmpty) return const [];

    // Cafés whose name matches, best match first.
    final cafeHits = <({CoffeeShop shop, int score})>[];
    for (final shop in shops) {
      final score = _nameScore(shop.name, q);
      if (score > 0) cafeHits.add((shop: shop, score: score));
    }
    cafeHits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : b.shop.rating.compareTo(a.shop.rating);
    });

    // Locations: mall names and address parts (street, city, ...).
    final locationCounts = <String, int>{};
    final locationLabels = <String, String>{};
    for (final shop in shops) {
      final places = <String>{
        if (shop.isInMall) shop.mallName!.trim(),
        ...shop.address.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty),
      };
      for (final place in places) {
        if (!normalize(place).contains(q)) continue;
        final key = normalize(place);
        locationLabels.putIfAbsent(key, () => place);
        locationCounts[key] = (locationCounts[key] ?? 0) + 1;
      }
    }
    final locations = locationCounts.keys.toList()..sort((a, b) => locationCounts[b]!.compareTo(locationCounts[a]!));

    return [
      for (final hit in cafeHits.take(_maxCafes))
        SearchSuggestion(
          kind: SuggestionKind.cafe,
          label: hit.shop.name,
          value: hit.shop.id,
          cafeCount: 1,
          shop: hit.shop,
        ),
      for (final key in locations.take(_maxPerGroup))
        SearchSuggestion(
          kind: SuggestionKind.location,
          label: locationLabels[key]!,
          value: locationLabels[key]!,
          cafeCount: locationCounts[key]!,
        ),
      ..._attributeSuggestions(
        q,
        shops,
        SuggestionKind.coffeeType,
        {for (final t in CoffeePreferences.coffeeTypeOptions) t: t},
      ),
      ..._attributeSuggestions(
        q,
        shops,
        SuggestionKind.atmosphere,
        {for (final a in CoffeePreferences.atmosphereOptions) a: a},
      ),
      ..._attributeSuggestions(q, shops, SuggestionKind.feature, CoffeePreferences.amenityLabels),
    ];
  }

  /// Coffee types / atmospheres / features ([options]: value → label)
  /// whose label matches [q] and that at least one café has.
  static List<SearchSuggestion> _attributeSuggestions(
    String q,
    List<CoffeeShop> shops,
    SuggestionKind kind,
    Map<String, String> options,
  ) {
    final results = <SearchSuggestion>[];
    for (final entry in options.entries) {
      if (!normalize(entry.value).contains(q)) continue;
      final suggestion = SearchSuggestion(kind: kind, label: entry.value, value: entry.key, cafeCount: 0);
      final count = shops.where((s) => matchesSuggestion(s, suggestion)).length;
      if (count == 0) continue; // only what real cafés actually offer
      results.add(SearchSuggestion(kind: kind, label: entry.value, value: entry.key, cafeCount: count));
    }
    results.sort((a, b) => b.cafeCount.compareTo(a.cafeCount));
    return results.take(_maxPerGroup).toList();
  }

  /// Whether [shop] belongs in the results for a picked [suggestion].
  static bool matchesSuggestion(CoffeeShop shop, SearchSuggestion suggestion) {
    final value = normalize(suggestion.value);
    switch (suggestion.kind) {
      case SuggestionKind.cafe:
        return shop.id == suggestion.value;
      case SuggestionKind.location:
        return normalize(shop.mallName ?? '').contains(value) || normalize(shop.address).contains(value);
      case SuggestionKind.coffeeType:
        if (shop.coffeeTypes.any((t) => normalize(t) == value)) return true;
        // Also served if it's on the menu ("Hazelnut Latte" → Latte),
        // except "Non-coffee", which isn't a drink name.
        return value != normalize('Non-coffee') && shop.menu.any((m) => normalize(m.name).contains(value));
      case SuggestionKind.atmosphere:
        return shop.atmospheres.any((a) => normalize(a) == value);
      case SuggestionKind.feature:
        return shop.amenities.contains(suggestion.value);
    }
  }

  /// Cafés for a picked suggestion, best rated first.
  static List<CoffeeShop> resultsForSuggestion(SearchSuggestion suggestion, List<CoffeeShop> shops) {
    return shops.where((s) => matchesSuggestion(s, suggestion)).toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
  }

  /// Free-text results (when the user presses search): every café that
  /// matches [query] by name, location/mall, coffee type, atmosphere,
  /// feature, or menu item — strongest match first, then rating.
  static List<CoffeeShop> search(String query, List<CoffeeShop> shops) {
    final q = normalize(query);
    if (q.isEmpty) return const [];
    final scored = <({CoffeeShop shop, int score})>[];
    for (final shop in shops) {
      final score = _shopScore(shop, q);
      if (score > 0) scored.add((shop: shop, score: score));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byRating = b.shop.rating.compareTo(a.shop.rating);
      return byRating != 0 ? byRating : a.shop.name.toLowerCase().compareTo(b.shop.name.toLowerCase());
    });
    return [for (final s in scored) s.shop];
  }

  static int _shopScore(CoffeeShop shop, String q) {
    final name = _nameScore(shop.name, q);
    if (name > 0) return name;
    if (normalize(shop.mallName ?? '').contains(q)) return 40;
    if (normalize(shop.address).contains(q)) return 30;
    final attributes = [
      ...shop.coffeeTypes,
      ...shop.atmospheres,
      for (final key in shop.amenities) CoffeePreferences.amenityLabels[key] ?? key,
    ];
    if (attributes.any((a) => normalize(a).contains(q))) return 25;
    if (shop.menu.any((m) => normalize(m.name).contains(q))) return 20;
    return 0;
  }

  /// 100 = name starts with the query, 80 = a word in it does, 60 = it
  /// appears anywhere in the name, 0 = no match.
  static int _nameScore(String name, String q) {
    final n = normalize(name);
    if (n.startsWith(q)) return 100;
    final words = name.split(RegExp(r'[\s\-&/]+')).map(normalize);
    if (words.any((w) => w.startsWith(q))) return 80;
    if (n.contains(q)) return 60;
    return 0;
  }

  static const Map<String, String> _accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ç': 'c',
  };

  /// Lowercase, accents removed, letters/digits only — so "Café", "cafe"
  /// and "CAFE" compare equal, as do "Wi-Fi" and "wifi".
  static String normalize(String value) {
    final lower = value.toLowerCase();
    final buffer = StringBuffer();
    for (final char in lower.split('')) {
      buffer.write(_accents[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
