import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/fitted_image.dart';
import '../theme/app_colors.dart';
import '../models/menu_item.dart';
import '../models/review.dart';
import '../utils/coffee_review_service.dart';
import '../widgets/owner_page_widgets.dart' show confirmDelete;
import '../widgets/top_banner.dart';

/// What happened on the coffee review form.
enum CoffeeReviewResult { saved, deleted }

/// Write (or edit, with [existing]) the signed-in customer's review of one
/// coffee: 1–5 stars, an optional comment and an optional photo. Same look
/// as the café "Write a Review" page. Pops with a [CoffeeReviewResult].
class CoffeeReviewFormPage extends StatefulWidget {
  final MenuItem coffee;
  final Review? existing;

  const CoffeeReviewFormPage({super.key, required this.coffee, this.existing});

  @override
  State<CoffeeReviewFormPage> createState() => _CoffeeReviewFormPageState();
}

class _CoffeeReviewFormPageState extends State<CoffeeReviewFormPage> {
  late int _rating = (widget.existing?.rating.round() ?? 5).clamp(1, 5);
  late final TextEditingController _text = TextEditingController(text: widget.existing?.text ?? '');
  File? _photo; // newly picked
  late bool _keepExistingPhoto = widget.existing?.hasPhoto ?? false;
  bool _busy = false;

  bool get _isEditing => widget.existing != null;
  bool get _photoAttached => _photo != null || _keepExistingPhoto;

  static const _ratingLabels = {1: 'Poor', 2: 'Fair', 3: 'Good', 4: 'Great', 5: 'Excellent'};

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
      if (picked == null || !mounted) return;
      setState(() {
        _photo = File(picked.path);
        _keepExistingPhoto = false;
      });
    } catch (e) {
      debugPrint('Picking review photo failed: $e');
      if (mounted) showTopBanner(context, "Couldn't open your photos. Please try again.", isSuccess: false);
    }
  }

  void _removePhoto() => setState(() {
        _photo = null;
        _keepExistingPhoto = false;
      });

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await CoffeeReviewService.submitReview(
        coffee: widget.coffee,
        rating: _rating,
        text: _text.text,
        photo: _photo,
        keepExistingPhoto: _keepExistingPhoto,
      );
      if (mounted) Navigator.pop(context, CoffeeReviewResult.saved);
    } catch (e) {
      debugPrint('Posting coffee review failed: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      showTopBanner(context, "Couldn't post your review. Please try again.", isSuccess: false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete Review?',
      message: 'Your review of ${widget.coffee.name} will be removed.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await CoffeeReviewService.deleteMyReview(widget.existing!);
      if (mounted) Navigator.pop(context, CoffeeReviewResult.deleted);
    } catch (e) {
      debugPrint('Deleting coffee review failed: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      showTopBanner(context, "Couldn't delete your review. Please try again.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _isEditing ? 'Edit Review' : 'Write a Review',
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: widget.coffee.hasImage
                                ? FittedImage.network(widget.coffee.imageUrl!, width: 48, height: 36, fallback: _cupTile())
                                : _cupTile(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.coffee.name,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark),
                                ),
                                const Text('Coffee Review', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Center(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var star = 1; star <= 5; star++)
                                  GestureDetector(
                                    onTap: _busy ? null : () => setState(() => _rating = star),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Icon(
                                        _rating >= star ? Icons.star_rounded : Icons.star_border_rounded,
                                        color: const Color(0xFFF5A623),
                                        size: 42,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _ratingLabels[_rating]!,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryBrown, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text('Comment (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _text,
                        maxLines: 5,
                        maxLength: 1000,
                        enabled: !_busy,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Share your thoughts about this coffee...',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                          filled: true,
                          fillColor: AppColors.inputFill,
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _busy ? null : _pickPhoto,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          decoration: BoxDecoration(
                            color: _photoAttached ? AppColors.primaryBrown.withOpacity(0.1) : AppColors.inputFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _photoAttached ? AppColors.primaryBrown : Colors.transparent),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.camera_alt_outlined, size: 20, color: _photoAttached ? AppColors.primaryBrown : AppColors.textGrey),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _photoAttached ? 'Replace photo' : 'Add a photo of your coffee (optional)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _photoAttached ? AppColors.primaryBrown : AppColors.textGrey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_photoAttached) ...[
                        const SizedBox(height: 10),
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: double.infinity,
                                height: 160,
                                child: _photo != null
                                    ? FittedImage(image: FileImage(_photo!), width: double.infinity, height: 160)
                                    : FittedImage.network(widget.existing!.photoUrl!, width: double.infinity, height: 160),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: _busy ? null : _removePhoto,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBrown,
                            disabledBackgroundColor: AppColors.primaryBrown.withOpacity(0.35),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : Text(
                                  _isEditing ? 'Update Review' : 'Post Review',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                        ),
                      ),
                      if (_isEditing) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed: _busy ? null : _delete,
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            label: const Text('Delete Review', style: TextStyle(fontWeight: FontWeight.w700)),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD64545)),
                          ),
                        ),
                      ],
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

  Widget _cupTile() => Container(
        width: 48,
        height: 36,
        color: AppColors.primaryBrown.withOpacity(0.12),
        child: const Icon(Icons.local_cafe_rounded, color: AppColors.primaryBrown, size: 22),
      );
}
