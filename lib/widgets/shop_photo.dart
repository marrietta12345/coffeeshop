import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';

/// The single place every screen renders a shop's photo. If the shop
/// hasn't uploaded that photo, this shows an honest branded placeholder —
/// NOT a random stock photo — so customers never see an image the shop
/// never actually provided.
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
      return Image.network(
        shop.photoUrls[index],
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width,
            height: height,
            color: AppColors.primaryBrown.withOpacity(0.1),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBrown),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _NoPhotoPlaceholder(width: width, height: height),
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
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(width: width, height: height, color: AppColors.primaryBrown.withOpacity(0.1));
      },
      errorBuilder: (context, error, stackTrace) => _NoPhotoPlaceholder(width: width, height: height),
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