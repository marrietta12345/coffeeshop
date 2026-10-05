import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/operating_hours.dart';
import '../theme/app_colors.dart';
import '../utils/business_permit_service.dart';
import 'auth_text_field.dart';
import 'fitted_image.dart';
import 'shop_gallery.dart';
import 'top_banner.dart';

/// A file the owner picked but hasn't saved yet.
class PickedPermit {
  final Uint8List bytes;
  final String fileName;

  const PickedPermit({required this.bytes, required this.fileName});

  bool get isPdf => BusinessPermitService.extensionOf(fileName) == 'pdf';
}

/// Holds the Business Permit field's state on Edit Profile. Nothing is
/// uploaded or removed until the owner taps Save Changes ([commit]).
class BusinessPermitController extends ChangeNotifier {
  BusinessPermitController({required this.shopId});

  final String shopId;
  BusinessPermit? saved; // what's on the owner's profile now
  String? savedImageUrl; // signed link for the saved image's thumbnail
  PickedPermit? picked; // new file waiting for Save Changes
  bool removed = false; // owner tapped Remove on the saved permit
  bool loading = false;
  bool fetching = false; // copying the chosen file (a Drive file downloads first)

  bool get hasFile => picked != null || (saved != null && !removed);
  bool get hasChanges => picked != null || (removed && saved != null);

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      saved = await BusinessPermitService.fetch();
      if (saved != null && !saved!.isPdf) {
        savedImageUrl = await BusinessPermitService.signedUrl(saved!.path);
      }
    } catch (e) {
      debugPrint('Could not load business permit: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setFetching(bool value) {
    if (fetching == value) return;
    fetching = value;
    notifyListeners();
  }

  void pick(PickedPermit file) {
    picked = file;
    notifyListeners();
  }

  void remove() {
    picked = null;
    removed = true;
    notifyListeners();
  }

  /// Uploads a newly picked file (replacing the old one) or deletes the
  /// removed one. Does nothing when the field wasn't touched.
  Future<void> commit() async {
    final old = saved;
    if (picked != null) {
      saved = await BusinessPermitService.upload(bytes: picked!.bytes, fileName: picked!.fileName, shopId: shopId);
      if (old != null) await BusinessPermitService.deleteFile(old.path);
    } else if (removed && old != null) {
      await BusinessPermitService.remove(old);
      saved = null;
    }
    picked = null;
    removed = false;
  }
}

/// Edit Profile → Business Permit: optional photo or PDF of the café's
/// permit, with a preview and Replace / Remove once there is one. Only
/// the owner can see it — it never appears on the public café page.
class BusinessPermitSection extends StatelessWidget {
  final BusinessPermitController controller;

  const BusinessPermitSection({super.key, required this.controller});

  /// Opens the phone's file chooser — its side menu also lists Google
  /// Drive (and other cloud apps the owner has signed in to).
  Future<void> _choose(BuildContext context) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: BusinessPermitService.allowedExtensions,
        onFileLoading: (status) => controller.setFetching(status == FilePickerStatus.picking),
      );
      if (file == null) return;
      final size = file.lengthSync() ?? await file.length() ?? 0;
      final error = BusinessPermitService.validate(fileName: file.name, sizeBytes: size);
      if (error != null) {
        if (context.mounted) showTopBanner(context, error, isSuccess: false);
        return;
      }
      final bytes = await file.readAsBytes();
      controller.pick(PickedPermit(bytes: bytes, fileName: file.name));
    } catch (e) {
      debugPrint('Could not pick business permit: $e');
      if (context.mounted) showTopBanner(context, "Couldn't open that file. Please try another one.", isSuccess: false);
    } finally {
      controller.setFetching(false);
    }
  }

  Future<void> _open(BuildContext context) async {
    final permit = controller.saved;
    if (permit == null || controller.picked != null) return;
    try {
      final url = await BusinessPermitService.signedUrl(permit.path);
      if (!context.mounted) return;
      if (permit.isPdf) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        await openPhotoViewer(context, [url]);
      }
    } catch (e) {
      debugPrint('Could not open business permit: $e');
      if (context.mounted) showTopBanner(context, "Couldn't open your permit. Please try again.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuthSectionLabel('Business Permit'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryBrown.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Optional',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primaryBrown),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Choose a photo or PDF of your permit from your phone's files or Google Drive "
            '(JPG, PNG or PDF, up to 10 MB). Only you can see it.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textGrey),
          ),
          const SizedBox(height: 16),
          if (controller.loading)
            const Center(
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBrown)),
            )
          else if (controller.fetching)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBrown)),
                SizedBox(width: 10),
                Text('Getting your file…', style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
              ],
            )
          else if (controller.hasFile)
            _fileCard(context)
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _choose(context),
                icon: const Icon(Icons.upload_file_rounded, size: 20),
                label: const Text('Upload Business Permit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBrown,
                  side: const BorderSide(color: AppColors.primaryBrown),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fileCard(BuildContext context) {
    final picked = controller.picked;
    final saved = controller.saved;
    final isPdf = picked?.isPdf ?? saved!.isPdf;
    final fileName = picked?.fileName ?? saved!.fileName;
    final size = BusinessPermitService.formatSize(picked?.bytes.length ?? saved!.sizeBytes);
    final details = picked != null
        ? '${isPdf ? 'PDF' : 'Image'} · $size · Tap Save Changes to upload'
        : '${isPdf ? 'PDF' : 'Image'} · $size${saved!.uploadedAt == null ? '' : ' · Uploaded ${_date(saved.uploadedAt!)}'}';

    Widget thumbnail;
    if (isPdf) {
      thumbnail = const Center(child: Icon(Icons.picture_as_pdf_rounded, size: 30, color: AppColors.primaryBrown));
    } else if (picked != null) {
      thumbnail = FittedImage(image: MemoryImage(picked.bytes), width: 56, height: 56);
    } else if (controller.savedImageUrl != null) {
      thumbnail = FittedImage.network(controller.savedImageUrl!, width: 56, height: 56);
    } else {
      thumbnail = const Center(child: Icon(Icons.image_outlined, size: 28, color: AppColors.primaryBrown));
    }

    return Container(
      decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            onTap: picked == null ? () => _open(context) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(width: 56, height: 56, color: imageBackdrop, child: thumbnail),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 3),
                        Text(details, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                      ],
                    ),
                  ),
                  if (picked == null) const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.textGrey),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _choose(context),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Replace'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primaryBrown),
                ),
                TextButton.icon(
                  onPressed: controller.remove,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// "Oct 5, 2026" in Manila time.
  static String _date(DateTime date) {
    final manila = date.toUtc().add(OperatingHours.manilaOffset);
    return '${_months[manila.month - 1]} ${manila.day}, ${manila.year}';
  }
}
