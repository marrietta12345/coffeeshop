import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/menu_item.dart';
import 'fitted_image.dart';

/// Displays a menu item's photo — the real uploaded image (Supabase
/// Storage) shown whole and centered in its (square) box, never cropped or
/// stretched; a faint Kafelo logo while it loads (then the photo fades
/// in); or a clean "No drink image available" tile when it has none
/// (never a stand-in photo).
class MenuItemImage extends StatelessWidget {
  final MenuItem item;
  final CoffeeShop shop;
  final int fallbackIndex;
  final double width;
  final double height;

  const MenuItemImage({
    super.key,
    required this.item,
    required this.shop,
    required this.fallbackIndex,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return FittedImage.network(
        item.imageUrl!,
        width: width,
        height: height,
        loading: KafeloLogoTile(width: width, height: height),
        fallback: _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => NoDrinkImage(width: width, height: height);
}

/// The faint Kafelo emblem on the warm backdrop — shown while a drink
/// photo loads, and (with a caption) when a drink has no photo.
class KafeloLogoTile extends StatelessWidget {
  final double width;
  final double height;
  final String? caption;

  const KafeloLogoTile({super.key, required this.width, required this.height, this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: imageBackdrop,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;
          // Captions only where they're readable (not on small thumbnails).
          final showCaption = caption != null && side.isFinite && side >= 110;
          final logoSize = side.isFinite ? (side * (showCaption ? 0.42 : 0.62)).clamp(20.0, 150.0) : 60.0;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'lib/images/kafelo_logo.png',
                  width: logoSize,
                  height: logoSize,
                  color: AppColors.primaryBrown.withValues(alpha: 0.35),
                ),
                if (showCaption) ...[
                  const SizedBox(height: 4),
                  Text(
                    caption!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Placeholder for a coffee without a photo: the faint Kafelo logo, plus
/// "No drink image available" when the box is big enough to read it.
class NoDrinkImage extends StatelessWidget {
  final double width;
  final double height;

  const NoDrinkImage({super.key, required this.width, required this.height});

  @override
  Widget build(BuildContext context) =>
      KafeloLogoTile(width: width, height: height, caption: 'No drink image available');
}
