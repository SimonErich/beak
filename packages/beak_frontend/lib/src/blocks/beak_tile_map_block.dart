part of 'beak_block.dart';

/// A data-bound raster tile map: each record with a latitude/longitude
/// becomes a pin on a slippy `OiTileMap` (OpenStreetMap tiles by default).
final class BeakTileMapBlock extends BeakBlock {
  /// Creates a tile map titled [title], pinning the rows of [query].
  const BeakTileMapBlock({
    required this.title,
    required this.query,
    required this.latitudeField,
    required this.longitudeField,
    this.labelField,
    this.centerLatitude,
    this.centerLongitude,
    this.zoom = 3,
    this.tileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.heightInPixels = 360,
    super.span,
  });

  /// The card heading.
  final String title;

  /// The query supplying the marker rows.
  final BeakQuerySpec query;

  /// The column holding each marker's latitude.
  final BeakColumn latitudeField;

  /// The column holding each marker's longitude.
  final BeakColumn longitudeField;

  /// The column labelling each marker, if any.
  final BeakColumn? labelField;

  /// The starting center latitude; defaults to the first marker.
  final double? centerLatitude;

  /// The starting center longitude; defaults to the first marker.
  final double? centerLongitude;

  /// The starting zoom level.
  final int zoom;

  /// The `{z}/{x}/{y}` tile URL template.
  final String tileUrlTemplate;

  /// The map height in pixels.
  final double heightInPixels;
}
