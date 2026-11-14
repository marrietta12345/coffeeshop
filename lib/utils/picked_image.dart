import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/painting.dart' show ImageProvider, MemoryImage;
import 'package:image_picker/image_picker.dart' show XFile;

/// A photo the user picked, kept as bytes so it works the same on
/// Android, iPhone and the web (browsers have no file paths).
class PickedImage {
  final Uint8List bytes;
  final String contentType;

  PickedImage(this.bytes, {this.contentType = 'image/jpeg'});

  /// Reads a photo from the image picker.
  static Future<PickedImage> fromXFile(XFile file) async {
    return PickedImage(await file.readAsBytes(), contentType: contentTypeOf(file.mimeType, file.name));
  }

  /// Preview of the photo before it is uploaded.
  late final ImageProvider provider = MemoryImage(bytes);

  /// The image type, from the picker's MIME type or else the file name.
  static String contentTypeOf(String? mimeType, String fileName) {
    if (mimeType != null && mimeType.startsWith('image/')) return mimeType;
    final name = fileName.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
