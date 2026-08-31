import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// All shop-related images (gallery photos, shop logos, best-seller item
/// photos) are stored in Supabase Storage — NOT Firebase Storage.
/// Firebase Auth and Firestore remain untouched; this is purely a
/// storage-backend swap for images.
///
/// Images live in a single `shop-images` bucket, organized by folder:
///   gallery/{shopId}/{fileName}
///   logos/{shopId}/{fileName}
///   best-sellers/{shopId}/{fileName}
///
/// Required Supabase setup (see setup notes at the bottom of this file):
///   1. Create a public bucket named `shop-images`.
///   2. Add Storage RLS policies restricting writes to the owning shop's
///      folder, while allowing public reads (customers can view images,
///      but only the owning business account can upload/delete theirs).
class SupabaseImageService {
  SupabaseImageService._();

  static const String bucketName = 'shop-images';

  static StorageFileApi get _bucket =>
      Supabase.instance.client.storage.from(bucketName);

  /// Uploads a single image file to `{folder}/{shopId}/{fileName}` and
  /// returns its public URL. `folder` should be one of: 'gallery',
  /// 'logos', 'best-sellers'.
  static Future<String> uploadImage({
    required File file,
    required String folder,
    required String shopId,
    required String fileName,
  }) async {
    final path = '$folder/$shopId/$fileName';
    await _bucket.upload(
      path,
      file,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );
    return _bucket.getPublicUrl(path);
  }

  /// Deletes an image given its full public URL (as returned by
  /// [uploadImage] or stored on a shop/menu-item document).
  static Future<void> deleteImageByUrl(String publicUrl) async {
    final path = _pathFromPublicUrl(publicUrl);
    if (path == null) return;
    await _bucket.remove([path]);
  }

  /// Deletes every image in a shop's folder for a given category —
  /// useful for cleaning up when a shop account is removed. Not wired
  /// into any UI yet since account deletion isn't a built feature.
  static Future<void> deleteAllInFolder({
    required String folder,
    required String shopId,
  }) async {
    final files = await _bucket.list(path: '$folder/$shopId');
    if (files.isEmpty) return;
    final paths = files.map((f) => '$folder/$shopId/${f.name}').toList();
    await _bucket.remove(paths);
  }

  /// Extracts the storage path (e.g. "gallery/abc123/photo.jpg") from a
  /// full Supabase public URL, so a stored URL can be turned back into
  /// something `remove()` accepts.
  static String? _pathFromPublicUrl(String publicUrl) {
    final marker = '/object/public/$bucketName/';
    final index = publicUrl.indexOf(marker);
    if (index == -1) return null;
    return publicUrl.substring(index + marker.length);
  }
}

/*
 * ───────────────────────────── SETUP NOTES ─────────────────────────────
 *
 * 1. In your Supabase project dashboard → Storage → create a new bucket
 *    named exactly `shop-images`. Mark it PUBLIC (so ShopPhoto's
 *    Image.network calls can load images without auth headers).
 *
 * 2. Add these Storage policies (Storage → Policies → shop-images), so
 *    only the owning business account can write to their own folder,
 *    while anyone (including anonymous customers) can read:
 *
 *    -- Public read access
 *    create policy "Public read access"
 *      on storage.objects for select
 *      using (bucket_id = 'shop-images');
 *
 *    -- Authenticated owners can upload only into their own shop folder.
 *    -- {shopId} here must match the Firestore shop document's id, and
 *    -- your app is responsible for only ever uploading into a path
 *    -- prefixed with the signed-in owner's own shopId.
 *    create policy "Owners can upload their own shop images"
 *      on storage.objects for insert
 *      with check (bucket_id = 'shop-images' and auth.role() = 'authenticated');
 *
 *    create policy "Owners can update their own shop images"
 *      on storage.objects for update
 *      using (bucket_id = 'shop-images' and auth.role() = 'authenticated');
 *
 *    create policy "Owners can delete their own shop images"
 *      on storage.objects for delete
 *      using (bucket_id = 'shop-images' and auth.role() = 'authenticated');
 *
 *    NOTE: Supabase Auth and Firebase Auth are separate systems. Since
 *    this app authenticates with Firebase Auth (not Supabase Auth),
 *    `auth.role() = 'authenticated'` above will NOT reflect your
 *    Firebase-signed-in user — Supabase has no knowledge of Firebase
 *    sessions. To properly restrict uploads to only the correct owner
 *    per-shop (not just "any authenticated Supabase user"), you have two
 *    practical options:
 *      a) Use Supabase's anon key with storage policies open to any
 *         request (simplest, but relies on your Flutter app code being
 *         the only thing calling uploadImage — enforce the "owner can
 *         only touch their own shopId folder" rule at the APP level, as
 *         this codebase already does by only ever calling uploadImage
 *         with the signed-in owner's own shop.id).
 *      b) Set up a Supabase Edge Function or server-side proxy that
 *         verifies the Firebase ID token before allowing an upload —
 *         more secure, but a meaningfully bigger integration than a
 *         storage-backend swap.
 *    This codebase uses option (a): app-level enforcement. Every upload
 *    call in owner_gallery_page.dart and owner_shop_profile_page.dart is
 *    already scoped to `widget.shop.id`, which is only ever the signed-in
 *    owner's own shop (verified via OwnerShopService, which queries
 *    Firestore for `ownerId == currentFirebaseUser.uid`). If you need
 *    real server-side enforcement against a malicious client bypassing
 *    the app, option (b) is required.
 *
 * 3. Add your Supabase project URL and anon key in main.dart (see the
 *    Supabase.initialize call) — find these in your Supabase dashboard
 *    under Project Settings → API.
 */