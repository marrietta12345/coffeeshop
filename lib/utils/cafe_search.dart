import '../models/coffee_preferences.dart';
import '../models/coffee_shop.dart';

/// What a search suggestion refers to. [location] is a neighborhood or
/// street, [mall] a mall, [landmark] a place cafés are near ("Near FSUU").
enum SuggestionKind { cafe, location, mall, landmark, coffeeType, atmosphere, feature }

/// One autocomplete suggestion for the Explore search bar, built from
/// the real café list. [value] is what gets matched when it's picked
/// (a shop id for [SuggestionKind.cafe], an amenity key for features, a
/// place key for places, otherwise the label itself).
class SearchSuggestion {
  final SuggestionKind kind;
  final String label;
  final String value;
  final int cafeCount; // how many cafés it leads to
  final CoffeeShop? shop; // for café suggestions
  final List<CoffeeShop> shops; // for places: the cafés there

  const SearchSuggestion({
    required this.kind,
    required this.label,
    required this.value,
    required this.cafeCount,
    this.shop,
    this.shops = const [],
  });

  bool get isPlace => kind == SuggestionKind.location || kind == SuggestionKind.mall || kind == SuggestionKind.landmark;
}

/// A place a café is in or near, cleaned up from its address:
/// "Brgy. Dagohoy (near TESDA)" → area "Dagohoy" + landmark "Near TESDA".
class CafePlace {
  final SuggestionKind kind;
  final String name; // what's matched against what the user types
  final String label; // what's shown

  const CafePlace(this.kind, this.name, this.label);

  static const Map<String, String> _abbreviations = {
    'st': 'street', 'ave': 'avenue', 'av': 'avenue', 'blvd': 'boulevard', 'rd': 'road',
    'subd': 'subdivision', 'bldg': 'building', 'ext': 'extension',
  };
  static const Set<String> _streetTypes = {'drive', 'road', 'avenue', 'boulevard', 'extension'};

  /// Same place, same key: "Guingona Subd." = "Guingona Subdivision",
  /// "Pili Drive St." = "Pili Drive".
  String get key {
    final words = [
      for (final w in name.split(RegExp(r'\s+')).map(CafeSearch.normalize).where((w) => w.isNotEmpty))
        _abbreviations[w] ?? w,
    ];
    if (words.length > 1 && words.last == 'street' && _streetTypes.contains(words[words.length - 2])) {
      words.removeLast();
    }
    return words.join();
  }
}

/// Café search for the Explore page — all matching is case-, accent- and
/// punctuation-insensitive, and works on partial input ("star" finds
/// "Star Coffee", "cafe" finds "Cafés").
class CafeSearch {
  CafeSearch._();

  static const int _maxCafes = 5;
  static const int _maxPerGroup = 3;
  static const int _maxPlaces = 4;

  /// The whole city (every café is in it), so never a useful filter.
  static const Set<String> _notPlaces = {
    'butuan', 'butuancity', 'agusandelnorte', 'caraga', 'philippines', '8600', 'butuancity8600',
  };

  /// "near X", "in front of X", "inside X"... → a landmark X.
  static final RegExp _landmarkCue = RegExp(
    r'^(near|in front of|infront of|beside|inside|at the back of|back of|behind|across from|across|opposite|opposite of|next to|above|below)\s+(.+)$',
    caseSensitive: false,
  );

  /// Places [shop] is in or near: its mall, clean neighborhood/street
  /// names, and the landmarks in its address.
  static List<CafePlace> placesOf(CoffeeShop shop) {
    final places = <String, CafePlace>{};
    void add(CafePlace place) {
      if (place.key.length < 2 || _notPlaces.contains(place.key)) return;
      places.putIfAbsent('${place.kind.name}:${place.key}', () => place);
    }

    void addLandmark(String cue, String raw) {
      var name = raw.trim().replaceAll(RegExp(r'[.\s]+$'), '');
      name = name.replaceFirst(RegExp(r'^the\s+', caseSensitive: false), '');
      // Only real, named places ("FSUU", "SM City Butuan") — not "the
      // entrance gate".
      if (name.isEmpty || !RegExp(r'^[A-Z0-9]').hasMatch(name)) return;
      final inside = cue.toLowerCase() == 'inside';
      add(CafePlace(SuggestionKind.landmark, name, '${inside ? 'Inside' : 'Near'} $name'));
    }

    if (shop.isInMall) add(CafePlace(SuggestionKind.mall, shop.mallName!.trim(), shop.mallName!.trim()));

    // Landmarks in brackets: "(near TESDA)", "(in front of SM City Butuan)".
    var address = shop.address;
    for (final m in RegExp(r'\(([^)]*)\)').allMatches(shop.address)) {
      var cued = false;
      for (final piece in m.group(1)!.split(',')) {
        final cue = _landmarkCue.firstMatch(piece.trim());
        if (cue != null) {
          cued = true;
          addLandmark(cue.group(1)!, cue.group(2)!);
        }
      }
      if (cued) address = address.replaceFirst(m.group(0)!, '');
    }

    for (var part in address.split(',')) {
      part = part.trim();
      if (part.isEmpty) continue;
      final cue = _landmarkCue.firstMatch(part);
      if (cue != null) {
        addLandmark(cue.group(1)!, cue.group(2)!);
        continue;
      }
      for (final piece in part.split(RegExp(r'\s+(?:corner|cor\.?)\s+', caseSensitive: false))) {
        final area = _cleanArea(piece);
        if (area != null) add(CafePlace(SuggestionKind.location, area, area));
      }
    }
    return places.values.toList();
  }

  /// "Brgy. Dagohoy" → "Dagohoy", "Imadejas Pob. (Bgy. 24)" → "Imadejas",
  /// "516 T. Sanchez St." → "T. Sanchez St."; null for things that aren't
  /// a place people search ("Purok 4", "Level 2", "Unit 4").
  static String? _cleanArea(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'\((?:bgy|brgy|barangay)\.?[^)]*\)', caseSensitive: false), '');
    if (RegExp(r'^(\d+(st|nd|rd|th)\s+floor|ground floor|level\s+\d+|unit\b|triangle\s+\d|bldg\b|stall\b)',
            caseSensitive: false)
        .hasMatch(s)) {
      return null;
    }
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceFirst(RegExp(r'^(?:brgy|bgy|barangay)\.?\s+', caseSensitive: false), '');
    s = s.replaceFirst(RegExp(r'^entrance of\s+', caseSensitive: false), '');
    s = s.replaceFirst(RegExp(r'^\d+\s+'), '');
    s = s.replaceFirst(RegExp(r'^(?:purok|prk|p)[\s.-]*\d+[a-z]?\b\s*', caseSensitive: false), '');
    s = s.replaceFirst(RegExp(r'\s+pob(?:\.|lacion)?$', caseSensitive: false), '').trim();
    if (s.length < 3 || !RegExp(r'[A-Za-z]{3}').hasMatch(s)) return null;
    return s;
  }

  /// Whether [text] has a word that starts with [q] (already normalized),
  /// across word boundaries: "jc aq" matches "J.C. Aquino Ave.", "b"
  /// matches "Bayanihan" but not "Montalban".
  static bool startsAtWord(String text, String q) => matchRange(text, q) != null;

  /// Where [q] (normalized) matches the start of a word in [text], as
  /// (start, end) character positions in [text] — for bolding the typed
  /// letters. Null when it doesn't match.
  static (int, int)? matchRange(String text, String q) {
    if (q.isEmpty) return null;
    bool isAlnum(String c) => normalize(c).isNotEmpty;
    for (var i = 0; i < text.length; i++) {
      if (!isAlnum(text[i]) || (i > 0 && isAlnum(text[i - 1]))) continue;
      var k = 0;
      var j = i;
      while (j < text.length && k < q.length) {
        final c = normalize(text[j]);
        if (c.isEmpty) {
          j++;
          continue;
        }
        if (c != q[k]) break;
        k++;
        j++;
      }
      if (k == q.length) return (i, j);
    }
    return null;
  }

  /// Autocomplete suggestions for [query]: matching cafés first, then
  /// places (malls, landmarks, neighborhoods), coffee types, atmospheres
  /// and features that at least one café actually has. Everything matches
  /// from the start of a word. Empty for an empty query.
  static List<SearchSuggestion> suggestions(String query, List<CoffeeShop> shops) {
    final q = normalize(query);
    if (q.isEmpty) return const [];

    // Cafés whose name (or a word in it) starts with the query.
    final cafeHits = <({CoffeeShop shop, int score})>[];
    for (final shop in shops) {
      final score = _nameScore(shop.name, q);
      if (score >= 80) cafeHits.add((shop: shop, score: score));
    }
    cafeHits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : b.shop.rating.compareTo(a.shop.rating);
    });

    // Places, with the cafés in or near each one.
    final placeShops = <String, List<CoffeeShop>>{};
    final placeInfo = <String, CafePlace>{};
    for (final shop in shops) {
      for (final place in placesOf(shop)) {
        if (!startsAtWord(place.name, q)) continue;
        final id = '${place.kind.name}:${place.key}';
        placeInfo.putIfAbsent(id, () => place);
        (placeShops[id] ??= []).add(shop);
      }
    }
    // A place every café is in doesn't narrow anything down.
    placeShops.removeWhere((_, list) => shops.length > 1 && list.length >= shops.length);
    final places = placeShops.keys.toList()
      ..sort((a, b) {
        final byCount = placeShops[b]!.length.compareTo(placeShops[a]!.length);
        return byCount != 0 ? byCount : placeInfo[a]!.label.compareTo(placeInfo[b]!.label);
      });

    return [
      for (final hit in cafeHits.take(_maxCafes))
        SearchSuggestion(
          kind: SuggestionKind.cafe,
          label: hit.shop.name,
          value: hit.shop.id,
          cafeCount: 1,
          shop: hit.shop,
        ),
      for (final id in places.take(_maxPlaces))
        SearchSuggestion(
          kind: placeInfo[id]!.kind,
          label: placeInfo[id]!.label,
          value: placeInfo[id]!.key,
          cafeCount: placeShops[id]!.length,
          shops: placeShops[id]!,
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
      if (!startsAtWord(entry.value, q)) continue;
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
      case SuggestionKind.mall:
      case SuggestionKind.landmark:
        return placesOf(shop).any((p) => p.kind == suggestion.kind && p.key == value);
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
    if (shop.isInMall && normalize(shop.mallFloor ?? '').contains(q)) return 35;
    if (normalize(shop.address).contains(q)) return 30;
    if (shop.isInMall &&
        (normalize(shop.mallLandmark ?? '').contains(q) || normalize(shop.unitLabel ?? '').contains(q))) {
      return 28;
    }
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
