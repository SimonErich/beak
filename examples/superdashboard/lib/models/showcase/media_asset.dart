import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// The presentation surface a media asset feeds.
enum MediaCollection {
  /// The image gallery / lightbox.
  gallery,

  /// The content carousel.
  carousel,

  /// The video showcase.
  video,
}

/// Typed columns of the media-assets resource — seeded content for the
/// gallery, lightbox, carousel, and video UI-kit showcases (so even those
/// demos are data-driven, not hardcoded).
abstract final class MediaAssetColumns {
  /// Which showcase surface this asset feeds.
  static const collection = BeakEnumColumn<MediaCollection>(
    key: 'collection',
    label: 'Collection',
    values: MediaCollection.values,
    defaultValue: MediaCollection.gallery,
    filterable: true,
    badgeColors: {
      MediaCollection.gallery: BeakColor.primary,
      MediaCollection.carousel: BeakColor.info,
      MediaCollection.video: BeakColor.warning,
    },
  );

  /// Asset title.
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(120)],
  );

  /// Caption / description.
  static const caption = BeakStringColumn(
    key: 'caption',
    label: 'Caption',
    rules: [BeakMaxLength(200)],
  );

  /// The media URL.
  static const url = BeakStringColumn(
    key: 'url',
    label: 'URL',
    rules: [BeakRequired()],
  );

  /// Ordering within a collection.
  static const sortIndex = BeakIntColumn(
    key: 'sort_index',
    label: 'Order',
    min: 0,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    collection,
    title,
    caption,
    url,
    sortIndex,
  ];
}

/// The media-assets resource — seeded gallery/carousel/video content.
final class MediaAssetModel extends BeakModel {
  /// Creates the media-assets model.
  const MediaAssetModel();

  @override
  String get table => 'media_assets';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => MediaAssetColumns.values;

  @override
  List<BeakRelationship> get relationships => const [];
}
