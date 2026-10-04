/// A Coffee Explorer's discovery preferences, stored as a map under
/// `users/{uid}.coffeePreferences`. Kept deliberately simple (plain
/// strings + bools) so recommendation / filtering logic can read it later
/// without any extra mapping.
class CoffeePreferences {
  final Set<String> coffeeTypes;
  final Set<String> atmospheres;
  final bool studyFriendly;
  final bool outdoorSeating;
  final bool wifi;
  final bool petFriendly;

  const CoffeePreferences({
    this.coffeeTypes = const {},
    this.atmospheres = const {},
    this.studyFriendly = false,
    this.outdoorSeating = false,
    this.wifi = false,
    this.petFriendly = false,
  });

  static const List<String> coffeeTypeOptions = [
    'Espresso',
    'Latte',
    'Cappuccino',
    'Americano',
    'Cold Brew',
    'Pour-over',
    'Non-coffee',
  ];

  static const List<String> atmosphereOptions = [
    'Cozy',
    'Quiet',
    'Lively',
    'Modern',
    'Rustic',
    'Minimalist',
  ];

  // Must-have keys — also how cafés store them in `shops/{id}.amenities`.
  static const String studyFriendlyKey = 'studyFriendly';
  static const String outdoorSeatingKey = 'outdoorSeating';
  static const String wifiKey = 'wifi';
  static const String petFriendlyKey = 'petFriendly';

  /// Must-have key → label shown in the app.
  static const Map<String, String> amenityLabels = {
    studyFriendlyKey: 'Study-friendly',
    outdoorSeatingKey: 'Outdoor seating',
    wifiKey: 'Wi-Fi',
    petFriendlyKey: 'Pet-friendly',
  };

  /// The must-haves this user switched on.
  Set<String> get selectedAmenities => {
        if (studyFriendly) studyFriendlyKey,
        if (outdoorSeating) outdoorSeatingKey,
        if (wifi) wifiKey,
        if (petFriendly) petFriendlyKey,
      };

  /// Whether the user has chosen anything at all — with nothing chosen
  /// there's nothing to personalize recommendations with.
  bool get hasAny => coffeeTypes.isNotEmpty || atmospheres.isNotEmpty || selectedAmenities.isNotEmpty;

  factory CoffeePreferences.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const CoffeePreferences();
    Set<String> stringSet(Object? value) =>
        (value as List?)?.map((e) => e.toString()).toSet() ?? <String>{};
    return CoffeePreferences(
      coffeeTypes: stringSet(data['coffeeTypes']),
      atmospheres: stringSet(data['atmospheres']),
      studyFriendly: (data['studyFriendly'] as bool?) ?? false,
      outdoorSeating: (data['outdoorSeating'] as bool?) ?? false,
      wifi: (data['wifi'] as bool?) ?? false,
      petFriendly: (data['petFriendly'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'coffeeTypes': coffeeTypes.toList(),
        'atmospheres': atmospheres.toList(),
        'studyFriendly': studyFriendly,
        'outdoorSeating': outdoorSeating,
        'wifi': wifi,
        'petFriendly': petFriendly,
      };
}
