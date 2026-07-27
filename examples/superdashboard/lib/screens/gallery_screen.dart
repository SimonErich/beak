import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:superdashboard/models/models.dart';
import 'package:obers_ui/obers_ui.dart';

/// A typed `collection == value` predicate over the media-assets table.
BeakFilter _inCollection(MediaCollection collection) => BeakFieldFilter(
  column: MediaAssetColumns.collection,
  operator: BeakOperator.eq,
  value: BeakValue.of(collection.name),
);

/// The media showcase — the seeded `media_assets` rendered two ways: a
/// content carousel (the `carousel` collection) above an image gallery /
/// lightbox (the `gallery` collection). Every slide and thumbnail is seeded.
BeakScreen buildGalleryScreen() => BeakScreen(
  path: '/gallery',
  title: 'Gallery',
  icon: const BeakIconToken(OiIcons.image),
  section: 'Showcase',
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [
      BeakCardBlock(
        title: 'Carousel',
        child: BeakCarouselBlock(
          query: BeakQuerySpec(
            table: 'media_assets',
            filter: _inCollection(MediaCollection.carousel),
            sorts: const [BeakSort('sort_index')],
          ),
          imageUrlField: MediaAssetColumns.url,
          captionField: MediaAssetColumns.caption,
        ),
      ),
      BeakCardBlock(
        title: 'Image gallery',
        child: BeakGalleryBlock(
          query: BeakQuerySpec(
            table: 'media_assets',
            filter: _inCollection(MediaCollection.gallery),
            sorts: const [BeakSort('sort_index')],
          ),
          imageUrlField: MediaAssetColumns.url,
          captionField: MediaAssetColumns.title,
        ),
      ),
      BeakCardBlock(
        title: 'Video',
        child: BeakVideoBlock(
          title: 'Featured video',
          query: BeakQuerySpec(
            table: 'media_assets',
            filter: _inCollection(MediaCollection.video),
            sorts: const [BeakSort('sort_index')],
          ),
          urlField: MediaAssetColumns.url,
        ),
      ),
    ],
  ),
);
