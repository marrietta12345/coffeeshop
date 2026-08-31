import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../utils/owner_shop_service.dart';
import '../utils/supabase_image_service.dart';
import '../widgets/top_banner.dart';

/// Real photo gallery management — pick photos from the device, upload
/// them to Supabase Storage, and save the resulting URLs onto the shop's
/// Firestore document (Firestore/Firebase Auth remain unchanged; only
/// the image storage backend is Supabase). This is what actually
/// replaces the "no photo" placeholder everywhere else in the app once
/// photos exist here.
class OwnerGalleryPage extends StatefulWidget {
  final CoffeeShop shop;

  const OwnerGalleryPage({super.key, required this.shop});

  @override
  State<OwnerGalleryPage> createState() => _OwnerGalleryPageState();
}

class _OwnerGalleryPageState extends State<OwnerGalleryPage> {
  bool _isUploading = false;

  Future<void> _addPhotos() async {
    final picker = ImagePicker();
    final List<XFile> picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;

    setState(() => _isUploading = true);

    final List<String> uploadedUrls = [];
    for (final file in picked) {
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${uploadedUrls.length}.jpg';
        final url = await SupabaseImageService.uploadImage(
          file: File(file.path),
          folder: 'gallery',
          shopId: widget.shop.id,
          fileName: fileName,
        );
        uploadedUrls.add(url);
      } catch (e) {
        if (mounted) {
          showTopBanner(context, 'One photo failed to upload. The rest were saved.', isSuccess: false);
        }
      }
    }

    if (uploadedUrls.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('shops').doc(widget.shop.id).set(
          {'photoUrls': FieldValue.arrayUnion(uploadedUrls)},
          SetOptions(merge: true),
        );
        if (mounted) showTopBanner(context, '${uploadedUrls.length} photo(s) added!', isSuccess: true);
      } catch (e) {
        if (mounted) showTopBanner(context, "Photos uploaded but couldn't save to your gallery.", isSuccess: false);
      }
    }

    if (mounted) setState(() => _isUploading = false);
  }

  Future<void> _deletePhoto(String url) async {
    try {
      await FirebaseFirestore.instance.collection('shops').doc(widget.shop.id).set(
        {'photoUrls': FieldValue.arrayRemove([url])},
        SetOptions(merge: true),
      );
      // Best-effort Storage cleanup — don't block on this.
      SupabaseImageService.deleteImageByUrl(url).catchError((_) {});
      if (mounted) showTopBanner(context, 'Photo removed.', isSuccess: true);
    } catch (e) {
      if (mounted) showTopBanner(context, "Couldn't remove that photo.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text('Shop Gallery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  ),
                  if (_isUploading)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryBrown)),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primaryBrown),
                      onPressed: _addPhotos,
                    ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<CoffeeShop?>(
                stream: OwnerShopService.myShopStream(),
                builder: (context, snapshot) {
                  final shop = snapshot.data ?? widget.shop;
                  if (shop.photoUrls.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library_outlined, size: 48, color: AppColors.textGrey.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            const Text('No photos yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap the + icon above to add photos of your shop.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: shop.photoUrls.length,
                    itemBuilder: (context, index) {
                      final url = shop.photoUrls[index];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              url,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: AppColors.primaryBrown.withOpacity(0.15),
                                child: const Icon(Icons.broken_image_outlined, color: AppColors.primaryBrown),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _deletePhoto(url),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}