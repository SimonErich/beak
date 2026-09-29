import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'asset.beak.dart';

/// Which block shows an asset.
enum AssetCollection {
  /// A slide in the carousel.
  carousel,

  /// A photo in the gallery.
  gallery,

  /// A clip in the video block.
  video,

  /// A row in the file manager.
  file,
}

/// A photo, clip or document the aviary keeps.
@Resource()
final class Asset extends BeakSchema {
  /// The name shown under it.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// A caption for the carousel and the gallery.
  late final String? caption;

  /// Where the media is served from: a bundled asset path or a URL.
  late final String url;

  /// Which block shows it.
  @Column(defaultValue: AssetCollection.file, filterable: true)
  late final AssetCollection collection;

  /// Whether it is a folder in the file manager.
  late final bool isFolder;

  /// Its size in bytes.
  @Column(semantic: BeakSemantic.fileSize(), rules: [BeakMin(0)])
  late final int sizeInBytes;

  /// When it last changed.
  late final DateTime modifiedAt;

  /// The display order inside its collection.
  @Column(sortable: true, defaultValue: 0)
  late final int position;
}
