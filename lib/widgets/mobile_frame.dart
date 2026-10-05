import 'package:flutter/material.dart';

/// App-wide mobile layout guard (wrapped around every screen, dialog and
/// sheet via MaterialApp.builder):
///
/// * Text follows the phone's font-size setting, but is capped at
///   [maxTextScale] so very large system fonts can't break layouts.
/// * On screens wider than [maxContentWidth] (a phone in landscape, a
///   tablet/iPad) the app is shown as a centered column of that width on a
///   neutral background, so photos and cards keep phone proportions
///   instead of stretching across the screen. Phones in portrait are
///   unaffected.
class MobileFrame extends StatelessWidget {
  final Widget child;

  const MobileFrame({super.key, required this.child});

  static const double maxContentWidth = 600;
  static const double maxTextScale = 1.3;
  static const Color _sideColor = Color(0xFFE9E4DF);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final textScaler = media.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: maxTextScale);
    final width = media.size.width;

    if (width <= maxContentWidth) {
      return MediaQuery(data: media.copyWith(textScaler: textScaler), child: child);
    }

    // Wide screen: a phone-width column. Its MediaQuery reports the column's
    // width (so layouts that size from the screen still fit), and drops the
    // side insets that the gutters now cover.
    EdgeInsets noSides(EdgeInsets e) => e.copyWith(left: 0, right: 0);
    return ColoredBox(
      color: _sideColor,
      child: Center(
        child: SizedBox(
          width: maxContentWidth,
          child: MediaQuery(
            data: media.copyWith(
              textScaler: textScaler,
              size: Size(maxContentWidth, media.size.height),
              padding: noSides(media.padding),
              viewPadding: noSides(media.viewPadding),
              viewInsets: noSides(media.viewInsets),
            ),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}
