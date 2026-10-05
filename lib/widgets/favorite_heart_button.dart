import 'package:flutter/material.dart';
import '../models/coffee_shop.dart';
import '../utils/saved_shops_service.dart';
import '../utils/shop_stats_service.dart';
import '../utils/shop_activity_service.dart';
import 'top_banner.dart';

/// A heart toggle that saves/unsaves a shop to the signed-in user's
/// Saved Shops — manages its own saved-state and Firestore write, so any
/// screen can drop this in without wiring up favorite logic itself.
class FavoriteHeartButton extends StatefulWidget {
  final CoffeeShop shop;
  final double size;

  const FavoriteHeartButton({super.key, required this.shop, this.size = 36});

  @override
  State<FavoriteHeartButton> createState() => _FavoriteHeartButtonState();
}

class _FavoriteHeartButtonState extends State<FavoriteHeartButton> {
  bool _isSaved = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final saved = await SavedShopsService.isSaved(widget.shop.id);
    if (mounted) setState(() {
      _isSaved = saved;
      _isLoading = false;
    });
  }

  Future<void> _toggle() async {
    // Optimistic UI update — flips immediately, corrects if the write fails.
    final previous = _isSaved;
    setState(() => _isSaved = !_isSaved);

    try {
      final nowSaved = await SavedShopsService.toggleSaved(widget.shop.id, widget.shop.name);
      if (!mounted) return;
      setState(() => _isSaved = nowSaved);

      // Only shops with an owner have a live shops/{id} doc to update.
      if (widget.shop.ownerId != null) {
        ShopStatsService.adjustFavoritesCount(widget.shop.id, nowSaved ? 1 : -1);
        ShopActivityService.setFavorited(widget.shop.id, nowSaved);
      }

      showTopBanner(
        context,
        nowSaved ? 'Saved to your favorites!' : 'Removed from favorites.',
        isSuccess: true,
        duration: const Duration(seconds: 1, milliseconds: 400),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaved = previous);
      showTopBanner(context, "Couldn't update favorites. Please try again.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _toggle,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: _isLoading
            ? Padding(
                padding: EdgeInsets.all(widget.size * 0.28),
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                _isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isSaved ? const Color(0xFFE04B4B) : Colors.grey.shade600,
                size: widget.size * 0.5,
              ),
      ),
    );
  }
}