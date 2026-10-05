/// Shop gallery building blocks: rounded photo tiles that show the whole
/// photo over a soft blur of itself, and the full-screen photo viewer.
library;

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// One rounded gallery photo: the whole image, centered over a blurred,
/// slightly dimmed copy of itself that fills the tile.
class GalleryTile extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  final String? moreLabel; // e.g. "+5" over the last preview tile

  const GalleryTile({super.key, required this.url, required this.onTap, this.moreLabel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: 'gallery:$url',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              BlurFilledPhoto(url: url),
              if (moreLabel != null)
                ColoredBox(
                  color: Colors.black.withOpacity(0.45),
                  child: Center(
                    child: Text(moreLabel!, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The whole photo (contain) over a soft blur of itself (cover).
class BlurFilledPhoto extends StatelessWidget {
  final String url;

  const BlurFilledPhoto({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final failed = Container(
      color: AppColors.primaryBrown.withOpacity(0.1),
      child: const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.primaryBrown)),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: AppColors.primaryBrown.withOpacity(0.08)),
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),
        ColoredBox(color: Colors.black.withOpacity(0.06)),
        Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
          errorBuilder: (_, __, ___) => failed,
        ),
      ],
    );
  }
}

/// Full-screen photo viewer: swipe between photos, pinch to zoom, see the
/// complete original image, close with ✕ or back.
Future<void> openPhotoViewer(BuildContext context, List<String> urls, {int initialIndex = 0}) {
  return Navigator.of(context).push(PageRouteBuilder(
    opaque: false,
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => PhotoViewerPage(urls: urls, initialIndex: initialIndex),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
  ));
}

class PhotoViewerPage extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const PhotoViewerPage({super.key, required this.urls, this.initialIndex = 0});

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  late final ScrollController _thumbs = ScrollController();

  @override
  void dispose() {
    _pages.dispose();
    _thumbs.dispose();
    super.dispose();
  }

  void _goTo(int i) => _pages.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  if (urls.length > 1)
                    Text('${_index + 1} / ${urls.length}', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: urls.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Hero(
                      tag: 'gallery:${urls[i]}',
                      child: Image.network(
                        urls[i],
                        fit: BoxFit.contain, // the complete original photo
                        loadingBuilder: (context, child, progress) => progress == null
                            ? child
                            : const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 40),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (urls.length > 1)
              SizedBox(
                height: 64,
                child: ListView.separated(
                  controller: _thumbs,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: urls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => _goTo(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: i == _index ? Colors.white : Colors.transparent, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Opacity(
                          opacity: i == _index ? 1 : 0.55,
                          child: ColoredBox(
                            color: Colors.white12,
                            child: Image.network(urls[i], fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
