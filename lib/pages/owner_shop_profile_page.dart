import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../widgets/open_status.dart';
import '../models/coffee_shop.dart';
import '../utils/owner_shop_service.dart';
import '../utils/supabase_image_service.dart';
import '../utils/page_transitions.dart';
import '../widgets/shop_photo.dart';
import '../widgets/top_banner.dart';
import 'owner_edit_profile_page.dart';
import 'owner_hours_page.dart';
import 'owner_gallery_page.dart';
import 'pick_shop_location_page.dart';
import 'welcome_page.dart';

/// "My Coffee Shop Profile" — the owner's view of their own live shop
/// listing, with real editing actions for profile info, location, hours,
/// and photo gallery.
class OwnerShopProfilePage extends StatelessWidget {
  const OwnerShopProfilePage({super.key});

  Future<void> _editLocation(BuildContext context, CoffeeShop shop) async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (context) => PickShopLocationPage(initialCenter: LatLng(shop.latitude, shop.longitude))),
    );
    if (result == null) return;

    String? newAddress;
    try {
      final placemarks = await placemarkFromCoordinates(result.latitude, result.longitude).timeout(const Duration(seconds: 8));
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.street, p.subLocality, p.locality, p.administrativeArea]
            .where((part) => part != null && part.trim().isNotEmpty)
            .toList();
        if (parts.isNotEmpty) newAddress = parts.join(', ');
      }
    } catch (_) {
      // Keep the existing address text if reverse geocoding fails.
    }

    try {
      await FirebaseFirestore.instance.collection('shops').doc(shop.id).set({
        'latitude': result.latitude,
        'longitude': result.longitude,
        if (newAddress != null) 'address': newAddress,
      }, SetOptions(merge: true));
      if (context.mounted) showTopBanner(context, 'Location updated!', isSuccess: true);
    } catch (e) {
      if (context.mounted) showTopBanner(context, "Couldn't save your new location.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<CoffeeShop?>(
        stream: OwnerShopService.myShopStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryBrown));
          }

          final shop = snapshot.data;
          if (shop == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text("We couldn't find your shop.", style: TextStyle(color: AppColors.textGrey)),
              ),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ShopPhoto(shop: shop, width: double.infinity, height: 190),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _WhitePillButton(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OwnerGalleryPage(shop: shop))),
                        ),
                      ),
                      Positioned(
                        bottom: -28,
                        left: 16,
                        child: _ShopLogoAvatar(shop: shop),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                shop.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
                              ),
                            ),
                            // Worked out from the schedule — no manual switch.
                            OpenStatusBadge(hours: shop.hours, tinted: true),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5A623)),
                            const SizedBox(width: 2),
                            Text(
                              shop.rating > 0 ? shop.rating.toStringAsFixed(1) : 'No ratings yet',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textGrey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                shop.locationLabel.isEmpty
                                    ? 'No address set'
                                    : [shop.locationLabel, ?shop.mallDetails].join('\n'),
                                style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _ProfileActionButton(
                              icon: Icons.edit_note_rounded,
                              label: 'Edit Profile',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OwnerEditProfilePage(shop: shop))),
                            ),
                            _ProfileActionButton(
                              icon: Icons.location_on_outlined,
                              label: 'Location',
                              onTap: () => _editLocation(context, shop),
                            ),
                            _ProfileActionButton(
                              icon: Icons.access_time_rounded,
                              label: 'Hours',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OwnerHoursPage(shop: shop))),
                            ),
                            _ProfileActionButton(
                              icon: Icons.photo_library_outlined,
                              label: 'Gallery',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OwnerGalleryPage(shop: shop))),
                            ),
                          ],
                        ),
                        if (shop.createdAt != null) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Joined on ${_formatDate(shop.createdAt!)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                          ),
                        ],
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFDEBEA),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              if (!context.mounted) return;
                              Navigator.of(context).pushAndRemoveUntil(
                                slideFadeRoute(const WelcomePage()),
                                (route) => false,
                              );
                            },
                            icon: const Icon(Icons.logout_rounded, color: Color(0xFFD64545), size: 18),
                            label: const Text(
                              'Logout',
                              style: TextStyle(color: Color(0xFFD64545), fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _WhitePillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _WhitePillButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.textDark),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          ],
        ),
      ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.inputFill),
            child: Icon(icon, size: 20, color: AppColors.primaryBrown),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
        ],
      ),
    );
  }
}

/// The circular shop-logo avatar overlapping the cover photo — shows the
/// shop's real uploaded logo (Supabase Storage) if one exists, otherwise
/// falls back to the bundled Kafelo mark. Tapping it lets the owner
/// upload/replace their logo directly, without needing a separate screen.
class _ShopLogoAvatar extends StatefulWidget {
  final CoffeeShop shop;

  const _ShopLogoAvatar({required this.shop});

  @override
  State<_ShopLogoAvatar> createState() => _ShopLogoAvatarState();
}

class _ShopLogoAvatarState extends State<_ShopLogoAvatar> {
  bool _isUploading = false;

  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final url = await SupabaseImageService.uploadImage(
        file: File(picked.path),
        folder: 'logos',
        shopId: widget.shop.id,
        fileName: 'logo.jpg', // fixed name + upsert: re-uploading replaces the old logo
      );
      await FirebaseFirestore.instance.collection('shops').doc(widget.shop.id).set(
        {'logoUrl': url},
        SetOptions(merge: true),
      );
      if (mounted) showTopBanner(context, 'Logo updated!', isSuccess: true);
    } catch (e) {
      if (mounted) showTopBanner(context, "Couldn't upload your logo. Please try again.", isSuccess: false);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoUrl = widget.shop.logoUrl;

    return GestureDetector(
      onTap: _isUploading ? null : _pickAndUploadLogo,
      child: Stack(
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryBrown.withOpacity(0.1)),
              clipBehavior: Clip.antiAlias,
              child: _isUploading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryBrown))
                  : (logoUrl != null && logoUrl.isNotEmpty)
                      ? Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Padding(padding: const EdgeInsets.all(10), child: Image.asset('lib/images/kafelo_logo.png')),
                        )
                      : Padding(padding: const EdgeInsets.all(10), child: Image.asset('lib/images/kafelo_logo.png')),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryBrown,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 10),
            ),
          ),
        ],
      ),
    );
  }
}