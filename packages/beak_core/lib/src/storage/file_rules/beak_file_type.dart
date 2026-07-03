/// A known upload/file type, pairing a canonical MIME type with the file
/// extensions it is recognized by.
enum BeakFileType {
  /// JPEG raster image.
  jpeg('image/jpeg', ['jpg', 'jpeg']),

  /// PNG raster image.
  png('image/png', ['png']),

  /// WebP raster image.
  webp('image/webp', ['webp']),

  /// GIF raster image.
  gif('image/gif', ['gif']),

  /// SVG vector image.
  svg('image/svg+xml', ['svg']),

  /// PDF document.
  pdf('application/pdf', ['pdf']),

  /// Comma-separated values document.
  csv('text/csv', ['csv']),

  /// JSON document.
  json('application/json', ['json']),

  /// ZIP archive.
  zip('application/zip', ['zip']),

  /// MP4 video.
  mp4('video/mp4', ['mp4']),

  /// MP3 audio.
  mp3('audio/mpeg', ['mp3']);

  const BeakFileType(this.mimeType, this.extensions);

  /// Canonical MIME type, e.g. `image/png`.
  final String mimeType;

  /// Lower-case file extensions (without the leading dot) recognized as this
  /// type.
  final List<String> extensions;

  /// Whether this type belongs to the `image/` MIME family.
  bool get isImage => mimeType.startsWith('image/');

  /// The default set of raster image types accepted by image columns.
  ///
  /// [svg] is deliberately excluded (it can carry scripts and cannot be
  /// transformed like a raster); add it explicitly where needed.
  static const List<BeakFileType> images = [jpeg, png, webp, gif];
}
