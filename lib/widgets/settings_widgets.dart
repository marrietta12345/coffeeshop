import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../utils/shop_lookup.dart';
import 'shop_photo.dart';

/// The dark rounded menu row from the Profile tab — shared by the Profile
/// tab and Account Settings so both menus look identical.
class ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const ProfileMenuTile({super.key, required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryBrown, size: 20),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

/// The customer-side sub-page layout (same as Saved Shops): dark header
/// with a back arrow and title, then a white sheet with rounded top
/// corners holding the content. [action] sits at the right of the header.
class SettingsPageScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  const SettingsPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: padding,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A brown text button for the dark header (e.g. "Edit", "Cancel").
class SettingsHeaderButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const SettingsHeaderButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(color: AppColors.primaryBrown, fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// A grey rounded row with an icon, title, optional subtitle and a
/// switch — same container treatment as the owner Hours rows.
class SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBrown, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.35)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primaryBrown,
            thumbColor: const WidgetStatePropertyAll(Colors.white),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

/// Icon + muted title/subtitle placeholder for empty lists, matching the
/// Saved Shops empty state.
class SettingsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const SettingsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textGrey.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.4),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// A café row (photo, name, location) in the same style as Saved Shops.
/// [detail] adds an optional extra muted line (e.g. last visited date).
/// [trailing] defaults to a chevron.
class ShopListRow extends StatelessWidget {
  final CoffeeShop shop;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? detail;
  final bool useCoverImage; // banner/photo/logo cover instead of gallery photo

  const ShopListRow({
    super.key,
    required this.shop,
    this.onTap,
    this.trailing,
    this.detail,
    this.useCoverImage = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: useCoverImage
                  ? ShopCoverImage(shop: shop, width: 56, height: 56)
                  : ShopPhoto(shop: shop, width: 56, height: 56),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          shop.locationLabel.isEmpty ? 'No address yet' : shop.locationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                        ),
                      ),
                    ],
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.primaryBrown, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}

/// Loads a shop by id and renders it as a [ShopListRow] — the pattern
/// every stored-id list (visited, collections) needs. The lookup runs
/// once per row, so live-list rebuilds don't re-fetch or flicker.
class ResolvedShopRow extends StatefulWidget {
  final String shopId;
  final void Function(CoffeeShop shop)? onTap;
  final Widget Function(CoffeeShop shop)? trailingBuilder;
  final String? detail;
  final String Function(CoffeeShop shop)? detailBuilder; // overrides [detail]
  final bool useCoverImage;

  const ResolvedShopRow({
    super.key,
    required this.shopId,
    this.onTap,
    this.trailingBuilder,
    this.detail,
    this.detailBuilder,
    this.useCoverImage = false,
  });

  @override
  State<ResolvedShopRow> createState() => _ResolvedShopRowState();
}

class _ResolvedShopRowState extends State<ResolvedShopRow> {
  late Future<CoffeeShop?> _future;

  @override
  void initState() {
    super.initState();
    _future = resolveShop(widget.shopId);
  }

  @override
  void didUpdateWidget(ResolvedShopRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) _future = resolveShop(widget.shopId);
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final trailingBuilder = widget.trailingBuilder;
    return FutureBuilder<CoffeeShop?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBrown)),
          );
        }
        final shop = snapshot.data;
        if (shop == null) return const SizedBox.shrink();
        return ShopListRow(
          shop: shop,
          onTap: onTap == null ? null : () => onTap(shop),
          trailing: trailingBuilder?.call(shop),
          detail: widget.detailBuilder?.call(shop) ?? widget.detail,
          useCoverImage: widget.useCoverImage,
        );
      },
    );
  }
}
