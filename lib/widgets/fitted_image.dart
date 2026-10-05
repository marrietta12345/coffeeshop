import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Kafelo's image rule: the CONTAINER has a fixed size; the photo inside
/// keeps its own proportions and is shown whole (BoxFit.contain) — never
/// stretched, never cropped. Any space left over is a soft neutral
/// backdrop, so different photo shapes still give identical cards.
///
/// Exception — coffee (menu) photos FILL their 4:3 box (BoxFit.cover,
/// centered), like food apps: a clean, uniform menu. The owner sees the
/// exact framing before saving, and customers can tap the Coffee Details
/// photo to see it whole.
///
/// Standard containers:
///   café header / banner    16:9
///   coffee & café images     4:3   (menu, details, thumbnails)
///   review photos            fixed thumbnail box, photo kept whole
///   avatars & logos          1:1   (round)
class ImageRatios {
  ImageRatios._();

  static const double banner = 16 / 9;
  static const double coffee = 4 / 3;
  static const double thumbnail = 4 / 3;
  static const double square = 1;
}

/// Soft warm neutral behind photos that don't fill their container.
const Color imageBackdrop = Color(0xFFF5F0EB);

/// [image] shown whole inside a [width] × [height] box (either may be
/// infinite to fill the parent) on the [imageBackdrop].
class FittedImage extends StatelessWidget {
  final ImageProvider image;
  final double? width;
  final double? height;
  final Widget? fallback; // shown if the image fails to load
  final BoxFit fit; // contain = whole photo; cover = fills the box (coffee photos)

  const FittedImage({super.key, required this.image, this.width, this.height, this.fallback, this.fit = BoxFit.contain});

  /// A network photo (Supabase Storage URL).
  FittedImage.network(String url, {super.key, this.width, this.height, this.fallback, this.fit = BoxFit.contain})
      : image = NetworkImage(url);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: imageBackdrop,
      child: Image(
        image: image,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBrown)),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            fallback ?? const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textGrey)),
      ),
    );
  }
}

/// "Use this photo?" — shows a just-picked photo inside the exact
/// container it will be displayed in ([aspectRatio]), kept whole and not
/// cropped. Resolves to true on Use Image.
Future<bool> confirmPhoto(
  BuildContext context, {
  required ImageProvider image,
  required double aspectRatio,
  String title = 'Use this photo?',
  BoxFit fit = BoxFit.contain,
}) async {
  final use = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text(
              fit == BoxFit.cover
                  ? 'This is how it will look on your menu. The photo fills the frame, so the edges may be trimmed — '
                      'square or landscape photos look best.'
                  : 'This is how it will look. Your whole photo is kept — nothing is cropped or stretched.',
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.4),
            ),
            const SizedBox(height: 14),
            // The real display box, kept small enough to fit short (landscape) screens.
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: FittedImage(image: image, width: double.infinity, height: double.infinity, fit: fit),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      minimumSize: const Size.fromHeight(46),
                      side: const BorderSide(color: Color(0xFFE5E0DB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBrown,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Use Image', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return use == true;
}
