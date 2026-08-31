import 'package:cloud_firestore/cloud_firestore.dart';
import 'menu_item.dart';
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
  final DateTime? createdAt;
  final String? phoneNumber;
  final String? website;
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
    this.photoCount = 6,
    this.photoUrls = const [],
    this.logoUrl,
    this.bannerUrl,
    this.viewCount = 0,
    this.favoritesCount = 0,
    this.createdAt,
    this.phoneNumber,
    this.website,
    this.menu = const [],
    this.reviews = const [],
  });

  /// Builds a shop from a `shops/{id}` Firestore document — used for
  /// shops owners create through Business Sign Up / their dashboard,
  /// as opposed to the bundled mock data.
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
      // Real owner-created shops have no photos until they upload their
      // own — don't show random stock placeholder images for them like
      // the bundled mock demo shops use.
      photoCount: (data['photoCount'] as num?)?.toInt() ?? 0,
      photoUrls: (data['photoUrls'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      logoUrl: data['logoUrl'] as String?,
      bannerUrl: data['bannerUrl'] as String?,
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      favoritesCount: (data['favoritesCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      phoneNumber: data['phoneNumber'] as String?,
      website: data['website'] as String?,
      // New owner-created shops don't have menu/reviews yet — those get
      // added once shop management + reviews are wired to Firestore too.
      menu: const [],
      reviews: const [],
    );
  }

  String get categoryLabel {
    switch (category) {
      case ShopCategory.coffee:
        return 'Coffee shop';
      case ShopCategory.other:
        return 'Cafe';
    }
  }

  /// How many photos this shop actually has to display — real uploaded
  /// photos if any exist, otherwise the bundled demo photoCount (mock
  /// shops only) or 0 (real shops with nothing uploaded yet).
  int get effectivePhotoCount => photoUrls.isNotEmpty ? photoUrls.length : photoCount;

  /// A deterministic, free placeholder photo for this shop — same shop
  /// always gets the same picture. Used only for the bundled mock demo
  /// shops; real shops use `photoUrls` once they've uploaded photos.
  String coverPhotoUrl([int index = 0]) => 'https://picsum.photos/seed/$id-photo$index/600/450';
}