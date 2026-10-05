import 'package:cloud_firestore/cloud_firestore.dart';
import 'menu_item.dart';
import 'operating_hours.dart';
import 'review.dart';

enum ShopCategory { coffee, other }

class CoffeeShop {
  final String id;
  final String? ownerId;
  final String name;
  final String description;
  final String address;
  final String openTime;
  final String closeTime;
  final double latitude;
  final double longitude;
  final double rating;
  final ShopCategory category;
  final bool isOpenNow;
  final int photoCount;
  final List<String> photoUrls;
  final String? logoUrl;
  final String? bannerUrl;
  final int viewCount;
  final int favoritesCount;
  final int reviewCount; // number of customer reviews (kept by ReviewService)
  final DateTime? createdAt;
  final String? phoneNumber;
  final String? website;
  // Optional social links (Online Presence), full https URLs.
  final String? facebookUrl;
  final String? instagramUrl;
  final String? tiktokUrl;
  // 'mall' or 'standalone' (from Business Sign Up's Location Type). Older
  // cafés may not have it — then a mall name means it's inside a mall.
  final String? locationType;
  // Set only for cafés located inside a mall. The mall is a shared
  // location (malls/{mallId}); the café stays its own business.
  final String? mallId; // key of the malls/{mallId} record
  final String? mallName;
  final String? mallFloor; // e.g. "2nd Floor", or a custom one like "10th Floor"
  final String? mallUnit; // optional, e.g. "204" or "Unit 204"
  final String? mallLandmark; // e.g. "Near the cinema entrance"
  // What the café offers, set by its owner — matched against customers'
  // Coffee Preferences for "Recommended for You". Values use the same
  // option names as CoffeePreferences.
  final List<String> coffeeTypes;
  final List<String> atmospheres;
  final List<String> amenities; // CoffeePreferences amenity keys
  // Weekly schedule + temporary closure — drives Open Now / Closed Now.
  final OperatingHours hours;
  final List<MenuItem> menu;
  final List<Review> reviews;

  const CoffeeShop({
    required this.id,
    this.ownerId,
    required this.name,
    required this.description,
    required this.address,
    required this.openTime,
    required this.closeTime,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.category,
    this.isOpenNow = true,
    this.photoCount = 0,
    this.photoUrls = const [],
    this.logoUrl,
    this.bannerUrl,
    this.viewCount = 0,
    this.favoritesCount = 0,
    this.reviewCount = 0,
    this.createdAt,
    this.phoneNumber,
    this.website,
    this.facebookUrl,
    this.instagramUrl,
    this.tiktokUrl,
    this.locationType,
    this.mallId,
    this.mallName,
    this.mallFloor,
    this.mallUnit,
    this.mallLandmark,
    this.coffeeTypes = const [],
    this.atmospheres = const [],
    this.amenities = const [],
    this.hours = const OperatingHours(),
    this.menu = const [],
    this.reviews = const [],
  });

  /// Builds a shop from a `shops/{id}` Firestore document — used for
  /// shops owners create through Business Sign Up / their dashboard.
  factory CoffeeShop.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CoffeeShop(
      id: doc.id,
      ownerId: data['ownerId'] as String?,
      name: (data['name'] as String?) ?? 'Unnamed Shop',
      description: (data['description'] as String?) ?? '',
      address: (data['address'] as String?) ?? '',
      openTime: (data['openTime'] as String?) ?? '8 AM',
      closeTime: (data['closeTime'] as String?) ?? '8 PM',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      category: ShopCategory.coffee,
      isOpenNow: (data['isOpenNow'] as bool?) ?? true,
      // Shops have no photos until they upload their own — never show
      // random stock placeholder images.
      photoCount: (data['photoCount'] as num?)?.toInt() ?? 0,
      photoUrls: (data['photoUrls'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      logoUrl: data['logoUrl'] as String?,
      bannerUrl: data['bannerUrl'] as String?,
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      favoritesCount: (data['favoritesCount'] as num?)?.toInt() ?? 0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      phoneNumber: data['phoneNumber'] as String?,
      website: data['website'] as String?,
      facebookUrl: data['facebookUrl'] as String?,
      instagramUrl: data['instagramUrl'] as String?,
      tiktokUrl: data['tiktokUrl'] as String?,
      locationType: data['locationType'] as String?,
      mallId: data['mallId'] as String?,
      mallName: data['mallName'] as String?,
      mallFloor: data['mallFloor'] as String?,
      mallUnit: data['mallUnit'] as String?,
      mallLandmark: data['mallLandmark'] as String?,
      coffeeTypes: _stringList(data['coffeeTypes']),
      atmospheres: _stringList(data['atmospheres']),
      amenities: _stringList(data['amenities']),
      hours: OperatingHours.fromFirestore(data),
      // New owner-created shops don't have menu/reviews yet — those get
      // added once shop management + reviews are wired to Firestore too.
      menu: const [],
      reviews: const [],
    );
  }

  static List<String> _stringList(Object? value) =>
      (value as List?)?.map((e) => e.toString()).toList() ?? const [];

  bool get isInMall => locationType != 'standalone' && (mallName?.trim().isNotEmpty ?? false);

  /// The location line shown across the app. Cafés inside a mall read
  /// "Inside Gaisano Mall, Butuan City" (mall + the city from the
  /// address); every other café shows its address exactly as before.
  String get locationLabel {
    if (!isInMall) return address;
    final mall = mallName!.trim();
    final parts = address.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? 'Inside $mall' : 'Inside $mall, ${parts.last}';
  }

  /// Floor, unit and landmark inside the mall on one line, e.g. "2nd Floor
  /// · Unit 204 · Near the Food Court" (for cards and the map) — null when
  /// the café isn't in a mall or none of them is set.
  String? get mallDetails {
    if (!isInMall) return null;
    final details = [mallFloor, unitLabel, mallLandmark]
        .map((d) => d?.trim() ?? '')
        .where((d) => d.isNotEmpty)
        .toList();
    return details.isEmpty ? null : details.join(' · ');
  }

  /// Floor and unit, e.g. "2nd Floor · Unit 204" (café details page).
  String? get mallFloorAndUnit {
    if (!isInMall) return null;
    final parts = [mallFloor?.trim() ?? '', unitLabel ?? ''].where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// The unit as customers read it: "204" → "Unit 204"; "Stall 3B" or
  /// "Kiosk 2" stay as typed. Null when there's no unit.
  String? get unitLabel => formatUnit(mallUnit);

  static String? formatUnit(String? unit) {
    final value = unit?.trim() ?? '';
    if (value.isEmpty) return null;
    if (RegExp(r'^[A-Za-z]{2,}').hasMatch(value) && !RegExp(r'^[A-Za-z]{1,2}-?\d').hasMatch(value)) return value;
    return 'Unit $value';
  }

  String get categoryLabel {
    switch (category) {
      case ShopCategory.coffee:
        return 'Coffee shop';
      case ShopCategory.other:
        return 'Cafe';
    }
  }

  /// How many photos this shop actually has to display — its real
  /// uploaded photos, or the stored photoCount (0 when nothing has been
  /// uploaded yet).
  int get effectivePhotoCount => photoUrls.isNotEmpty ? photoUrls.length : photoCount;
}