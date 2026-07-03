import 'dart:typed_data';

import 'package:meta/meta.dart';

/// An incoming file upload: the raw bytes plus the client-declared filename
/// and MIME type.
///
/// This is the typed input of `BeakUploadValidator` and every
/// `BeakStorageDriver.put` call — Beak never passes file content around as
/// loose tuples.
@immutable
final class BeakUpload {
  /// Creates an upload of [bytes] declared as [filename] and [mimeType].
  const BeakUpload({
    required this.filename,
    required this.mimeType,
    required this.bytes,
  });

  /// Client-declared file name, e.g. `photo.png`.
  final String filename;

  /// Client-declared MIME type, e.g. `image/png`.
  final String mimeType;

  /// The raw file content.
  final Uint8List bytes;

  /// Size of the upload in bytes.
  int get sizeInBytes => bytes.length;

  /// The lower-cased extension of [filename] without the leading dot, or
  /// `null` when the name carries no real suffix (`README`, `.env`,
  /// `trailing.`).
  String? get extension {
    final int dot = filename.lastIndexOf('.');
    if (dot <= 0 || dot == filename.length - 1) {
      return null;
    }
    return filename.substring(dot + 1).toLowerCase();
  }
}
