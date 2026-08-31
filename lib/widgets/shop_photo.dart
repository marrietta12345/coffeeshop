import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';

/// The single place every screen renders a shop's photo. If the shop
/// hasn't uploaded any real photos yet (photoCount == 0, true for every
/// newly-created owner shop until a real upload feature exists), this
/// shows an honest branded placeholder — NOT a random stock photo — so
/// customers never see an image the shop never actually provided.
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

    // No real photos — for mock demo shops only, show the seeded
    // placeholder photo. Real shops with nothing uploaded get the
    // honest "no photo" placeholder instead.
    if (shop.photoUrls.isEmpty && shop.ownerId == null && index < shop.photoCount) {
      return Image.network(
        shop.coverPhotoUrl(index),
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