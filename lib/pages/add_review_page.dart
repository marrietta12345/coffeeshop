import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/fitted_image.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/review.dart';
import '../utils/review_service.dart';
import '../widgets/top_banner.dart';

/// Full-page "Write a Review" flow — replaces the old bottom sheet.
/// Styled to match the rest of the app's auth-style header (dark top +
/// white rounded card) so it feels like part of the same brand, not a
/// bolted-on popup.
///
/// Saves the review (and optional photo) for [shop] itself, then pops
/// `true`; pops null if the person just goes back. If they've already
/// reviewed this shop, [existing] pre-fills the form and posting updates
/// that review.
class AddReviewPage extends StatefulWidget {
  final CoffeeShop shop;
  final Review? existing;

  const AddReviewPage({super.key, required this.shop, this.existing});

  @override
  State<AddReviewPage> createState() => _AddReviewPageState();
}

class _AddReviewPageState extends State<AddReviewPage> {
  double _rating = 5;
  final _textController = TextEditingController();
  File? _photo; // newly picked photo
  bool _keepExistingPhoto = false; // keep the photo from an earlier review
  bool _isPosting = false;

  bool get _photoAttached => _photo != null || _keepExistingPhoto;

  static const _ratingLabels = {
    1: 'Poor',
    2: 'Fair',
    3: 'Good',
    4: 'Great',
    5: 'Excellent',
  };

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _rating = existing.rating.clamp(1, 5).toDouble();
      _textController.text = existing.text;
      _keepExistingPhoto = existing.hasPhoto;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
    if (picked == null || !mounted) return;
    setState(() {
      _photo = File(picked.path);
      _keepExistingPhoto = false;
    });
  }

  void _removePhoto() {
    setState(() {
      _photo = null;
      _keepExistingPhoto = false;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _isPosting = true);
    try {
      await ReviewService.submitReview(
        shop: widget.shop,
        rating: _rating,
        text: _textController.text.trim(),
        photo: _photo,
        keepExistingPhoto: _keepExistingPhoto,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Posting review failed: $e');
      if (!mounted) return;
      setState(() => _isPosting = false);
      showTopBanner(context, "Couldn't post your review. Please try again.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _textController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Write a Review',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBrown.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Image.asset('lib/images/kafelo_logo.png'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.shop.name,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark),
                                ),
                                const Text(
                                  'Share your experience',
                                  style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Center(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                final starValue = index + 1;
                                return GestureDetector(
                                  onTap: () => setState(() => _rating = starValue.toDouble()),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(
                                      _rating >= starValue ? Icons.star_rounded : Icons.star_border_rounded,
                                      color: const Color(0xFFF5A623),
                                      size: 42,
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _ratingLabels[_rating.round()] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBrown,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Your review',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _textController,
                        maxLines: 6,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'What did you like (or not)? Mention the drinks, service, vibe...',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                          filled: true,
                          fillColor: AppColors.inputFill,
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: _isPosting ? null : _pickPhoto,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          decoration: BoxDecoration(
                            color: _photoAttached ? AppColors.primaryBrown.withOpacity(0.1) : AppColors.inputFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _photoAttached ? AppColors.primaryBrown : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.camera_alt_outlined,
                                size: 20,
                                color: _photoAttached ? AppColors.primaryBrown : AppColors.textGrey,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _photoAttached ? 'Photo attached' : 'Add a photo (optional)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _photoAttached ? AppColors.primaryBrown : AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_photoAttached) ...[
                        const SizedBox(height: 10),
                        _PhotoPreview(
                          photo: _photo,
                          photoUrl: _keepExistingPhoto ? widget.existing?.photoUrl : null,
                          onRemove: _isPosting ? null : _removePhoto,
                        ),
                      ],
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBrown,
                            disabledBackgroundColor: AppColors.primaryBrown.withOpacity(0.35),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: canSubmit && !_isPosting ? _submit : null,
                          child: _isPosting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : const Text(
                                  'Post Review',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
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

/// Preview of the attached photo with a small remove (×) button.
class _PhotoPreview extends StatelessWidget {
  final File? photo;
  final String? photoUrl;
  final VoidCallback? onRemove;

  const _PhotoPreview({this.photo, this.photoUrl, this.onRemove});

  @override
  Widget build(BuildContext context) {
    // The whole photo, never cropped or stretched.
    final Widget image = photo != null
        ? FittedImage(image: FileImage(photo!), width: double.infinity, height: 160)
        : FittedImage.network(photoUrl ?? '', width: double.infinity, height: 160);

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: double.infinity, height: 160, child: image),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
