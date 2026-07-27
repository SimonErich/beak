import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'media_asset.beak.dart';

/// The presentation surface a media asset feeds.
enum MediaCollection {
  /// The image gallery / lightbox.
  gallery,

  /// The content carousel.
  carousel,

  /// The video showcase.
  video,
}

/// The media-assets resource — seeded gallery/carousel/video content.
@Resource()
final class MediaAsset extends BeakSchema {
  /// Which showcase surface this asset feeds.
  @Column(filterable: true, defaultValue: MediaCollection.gallery)
  @Badges({
    MediaCollection.gallery: BeakColor.primary,
    MediaCollection.carousel: BeakColor.info,
    MediaCollection.video: BeakColor.warning,
  })
  late final MediaCollection? collection;

  /// Asset title.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(120)])
  late final String title;

  /// Caption / description.
  @Column(rules: [BeakMaxLength(200)])
  late final String? caption;

  /// The media URL.
  @Column(label: 'URL')
  late final String url;

  /// Ordering within a collection.
  @Column(label: 'Order', min: 0, sortable: true)
  late final int? sortIndex;
}
