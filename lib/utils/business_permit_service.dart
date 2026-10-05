import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_service.dart';

/// The owner's uploaded business permit (an image or a PDF), as saved on
/// their private `users/{uid}` document under `businessPermit`.
///
/// The file itself is in the PRIVATE Supabase bucket `business-permits`
/// (never the public `shop-images` one): only its storage [path] is
/// saved, and the app opens it through a short-lived signed link.
class BusinessPermit {
  final String path; // e.g. "shop123/1730000000000_k3j9x2.pdf"
  final String fileName; // the owner's original file name
  final String contentType;
  final int sizeBytes;
  final String shopId;
  final DateTime? uploadedAt;

  const BusinessPermit({
    required this.path,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.shopId,
    this.uploadedAt,
  });

  bool get isPdf => contentType == 'application/pdf';

  static BusinessPermit? fromMap(Object? data) {
    if (data is! Map) return null;
    final path = data['path'];
    if (path is! String || path.isEmpty) return null;
    final uploadedAt = data['uploadedAt'];
    return BusinessPermit(
      path: path,
      fileName: (data['fileName'] as String?) ?? path.split('/').last,
      contentType: (data['contentType'] as String?) ?? '',
      sizeBytes: (data['sizeBytes'] as num?)?.toInt() ?? 0,
      shopId: (data['shopId'] as String?) ?? '',
      // A pending server timestamp reads as null — treat it as "now".
      uploadedAt: uploadedAt is Timestamp ? uploadedAt.toDate() : DateTime.now(),
    );
  }
}

class BusinessPermitService {
  BusinessPermitService._();

  static const String bucketName = 'business-permits';
  static const String field = 'businessPermit';
  static const int maxBytes = 10 * 1024 * 1024; // 10 MB
  static const List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];

  static StorageFileApi get _bucket => Supabase.instance.client.storage.from(bucketName);

  /// The lower-case extension of [fileName] (no dot), or '' if it has none.
  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  static String? contentTypeFor(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
    }
    return null;
  }

  /// Why a picked file can't be used, or null when it's fine.
  static String? validate({required String fileName, required int sizeBytes}) {
    if (contentTypeFor(extensionOf(fileName)) == null) {
      return 'Please choose a JPG, PNG or PDF file.';
    }
    if (sizeBytes <= 0) return "That file looks empty. Please choose another one.";
    if (sizeBytes > maxBytes) return 'That file is too large. The limit is 10 MB.';
    return null;
  }

  /// "340 KB", "1.2 MB".
  static String formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${max(1, (bytes / 1024).round())} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// The signed-in owner's saved permit, or null when there isn't one.
  static Future<BusinessPermit?> fetch() async {
    final profile = await UserProfileService.fetchProfile();
    return BusinessPermit.fromMap(profile[field]);
  }

  /// Uploads the file under a random, unguessable name in the shop's
  /// folder and saves it on the owner's profile. Returns the new permit.
  static Future<BusinessPermit> upload({
    required Uint8List bytes,
    required String fileName,
    required String shopId,
  }) async {
    final extension = extensionOf(fileName);
    final contentType = contentTypeFor(extension);
    if (contentType == null) throw ArgumentError('Unsupported file type: $fileName');

    final random = Random.secure();
    final token = List.generate(16, (_) => random.nextInt(36).toRadixString(36)).join();
    final path = '$shopId/${DateTime.now().millisecondsSinceEpoch}_$token.$extension';
    await _bucket.uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType));

    final permit = BusinessPermit(
      path: path,
      fileName: fileName,
      contentType: contentType,
      sizeBytes: bytes.length,
      shopId: shopId,
    );
    try {
      await UserProfileService.update({
        field: {
          'path': permit.path,
          'fileName': permit.fileName,
          'contentType': permit.contentType,
          'sizeBytes': permit.sizeBytes,
          'shopId': permit.shopId,
          'uploadedAt': FieldValue.serverTimestamp(),
        },
      });
    } catch (_) {
      // Don't leave an orphan file behind if the profile write failed.
      await _removeFile(path);
      rethrow;
    }
    return permit;
  }

  /// Removes the permit from the owner's profile and deletes the file.
  static Future<void> remove(BusinessPermit permit) async {
    await UserProfileService.update({field: FieldValue.delete()});
    await _removeFile(permit.path);
  }

  /// Deletes an old file after it was replaced; never fails the save.
  static Future<void> deleteFile(String path) => _removeFile(path);

  static Future<void> _removeFile(String path) async {
    try {
      await _bucket.remove([path]);
    } catch (_) {
      // The profile no longer points to it, so nobody can open it.
    }
  }

  /// A link that opens the private file for the next 10 minutes.
  static Future<String> signedUrl(String path) => _bucket.createSignedUrl(path, 600);
}

/*
 * ───────────────────────────── SUPABASE SETUP ─────────────────────────────
 *
 * 1. Storage → New bucket → name `business-permits`, leave "Public bucket"
 *    OFF (private). Optional: file size limit 10 MB; allowed MIME types
 *    image/jpeg, image/png, image/webp, application/pdf.
 *
 * 2. SQL Editor → run (the app signs in with Firebase, so Supabase sees
 *    requests as the anon role — same approach as `shop-images`):
 *
 *    create policy "Permits: upload"
 *      on storage.objects for insert to anon, authenticated
 *      with check (bucket_id = 'business-permits');
 *
 *    create policy "Permits: signed links"
 *      on storage.objects for select to anon, authenticated
 *      using (bucket_id = 'business-permits');
 *
 *    create policy "Permits: delete"
 *      on storage.objects for delete to anon, authenticated
 *      using (bucket_id = 'business-permits');
 *
 *    Files have no public URL; they open only through signed links that
 *    expire after 10 minutes, under random names stored on the owner's
 *    private Firestore profile. Like `shop-images`, Supabase can't check
 *    the Firebase user, so full per-owner enforcement would need a
 *    server function that verifies the Firebase ID token.
 */
