import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import 'fitted_image.dart';

/// The single place every screen renders a shop's photo — shown whole
/// inside its box (never stretched or cropped; see FittedImage). If the
/// shop hasn't uploaded that photo, this shows an honest branded
/// placeholder — NOT a random stock photo.
class ShopPhoto extends StatelessWidget {
  final CoffeeShop shop;
  final int index;
  final double width;
  final double height;

  const ShopPhoto({
    super.key,
    required this.shop,
    this.index = 0,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    // Real uploaded photo takes priority.
    if (index < shop.photoUrls.length) {
      return FittedImage.network(
        shop.photoUrls[index],
        width: width,
        height: height,
        fallback: _NoPhotoPlaceholder(width: width, height: height),
      );
    }

    return _NoPhotoPlaceholder(width: width, height: height);
  }
}

/// A café's cover image for visual lists (Collections): its uploaded
/// banner, else its first gallery photo, else its logo — whatever the
/// shop already has — falling back to the branded placeholder. Nothing
/// new needs to be uploaded.
class ShopCoverImage extends StatelessWidget {
  final CoffeeShop shop;
  final double width;
  final double height;

  const ShopCoverImage({super.key, required this.shop, required this.width, required this.height});

  String? get _coverUrl {
    for (final url in [shop.bannerUrl, if (shop.photoUrls.isNotEmpty) shop.photoUrls.first, shop.logoUrl]) {
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = _coverUrl;
    if (url == null) return _NoPhotoPlaceholder(width: width, height: height);
    return FittedImage.network(
      url,
      width: width,
      height: height,
      fallback: _NoPhotoPlaceholder(width: width, height: height),
    );
  }
}

/// The café's header banner (cover photo): the banner the owner set, or —
/// if they haven't set one — their first uploaded photo; the branded
/// placeholder when there are no photos at all. It FILLS the whole header
/// box (BoxFit.cover): scaled evenly, never stretched or squashed; only the
/// edges that don't fit the 16:9 box are trimmed.
///
/// The banner is kept out of the Shop Gallery — see [galleryFor].
class ShopBanner extends StatelessWidget {
  final CoffeeShop shop;
  final double width;
  final double height;

  const ShopBanner({super.key, required this.shop, required this.width, required this.height});

  /// The image used as the café's banner, if any.
  static String? urlFor(CoffeeShop shop) {
    for (final url in [shop.bannerUrl, if (shop.photoUrls.isNotEmpty) shop.photoUrls.first]) {
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  /// The Shop Gallery: the owner's other photos, in their saved order —
  /// never the banner, so no photo shows twice.
  static List<String> galleryFor(CoffeeShop shop) {
    final banner = urlFor(shop);
    return shop.photoUrls.where((url) => url.isNotEmpty && url != banner).toList();
  }

  @override
  Widget build(BuildContext context) {
    final url = urlFor(shop);
    final placeholder = _NoPhotoPlaceholder(width: width, height: height);
    if (url == null) return placeholder;
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : Container(width: width, height: height, color: AppColors.primaryBrown.withOpacity(0.08)),
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}

/// Branded "no photo" placeholder — the Kafelo logo on a soft brown tint,
/// clearly reading as "nothing uploaded yet" rather than looking like a
/// real (but random) photo of the shop.
class _NoPhotoPlaceholder extends StatelessWidget {
  final double width;
  final double height;

  const _NoPhotoPlaceholder({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.primaryBrown.withOpacity(0.08),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all((width.isFinite ? width : 80) * 0.28),
          child: Image.asset(
            'lib/images/kafelo_logo.png',
            color: AppColors.primaryBrown.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}