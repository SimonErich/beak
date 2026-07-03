import 'package:meta/meta.dart';

import '../../common/json_support.dart';

/// Pixel dimensions of an image or thumbnail rendition.
@immutable
final class BeakDimensions {
  /// Creates dimensions of [widthInPixels] by [heightInPixels].
  const BeakDimensions({
    required this.widthInPixels,
    required this.heightInPixels,
  }) : assert(widthInPixels > 0, 'widthInPixels must be positive'),
       assert(heightInPixels > 0, 'heightInPixels must be positive');

  /// Creates square dimensions of [sizeInPixels] per side.
  const BeakDimensions.square(int sizeInPixels)
    : this(widthInPixels: sizeInPixels, heightInPixels: sizeInPixels);

  /// Decodes [json] (produced by [toJson]).
  ///
  /// Throws a `BeakConfigurationException` on malformed input.
  static BeakDimensions fromJson(Map<String, Object?> json) => BeakDimensions(
    widthInPixels: requireJsonInt(json, 'widthInPixels', 'BeakDimensions'),
    heightInPixels: requireJsonInt(json, 'heightInPixels', 'BeakDimensions'),
  );

  /// Horizontal size in pixels.
  final int widthInPixels;

  /// Vertical size in pixels.
  final int heightInPixels;

  /// These dimensions as a plain JSON-encodable object.
  Map<String, Object?> toJson() => {
    'widthInPixels': widthInPixels,
    'heightInPixels': heightInPixels,
  };

  @override
  bool operator ==(Object other) =>
      other is BeakDimensions &&
      other.widthInPixels == widthInPixels &&
      other.heightInPixels == heightInPixels;

  @override
  int get hashCode => Object.hash(widthInPixels, heightInPixels);

  @override
  String toString() => 'BeakDimensions(${widthInPixels}x$heightInPixels)';
}
