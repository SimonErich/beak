import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

/// Adapts local image resources to the pinned Obers image component.
///
/// Obers treats non-network sources as assets. A scoped bundle supplies only the
/// exact data URI's bytes; unrelated assets and manifests keep their host bundle.
class BeakResolvedImage extends HookWidget {
  /// Displays a network URL, asset path or local image data URI through [OiImage].
  const BeakResolvedImage({
    required this.src,
    required this.alt,
    this.widthInPixels,
    this.heightInPixels,
    this.fit,
    this.errorWidget,
    super.key,
  });

  /// Resolved image resource, including an in-memory draft data URI.
  final String src;

  /// Accessible description passed to the Obers component.
  final String alt;

  /// Optional logical width, in logical pixels.
  final double? widthInPixels;

  /// Optional logical height, in logical pixels.
  final double? heightInPixels;

  /// How the image fits its available bounds.
  final BoxFit? fit;

  /// Fallback for an invalid resource or an image decoding failure.
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final parent = DefaultAssetBundle.of(context);
    final bytes = useMemoized(() => _imageBytes(src), [src]);
    final bundle = useMemoized(
      () => bytes == null ? null : _DataImageBundle(parent, src, bytes),
      [parent, src, bytes],
    );
    final fallback =
        errorWidget ?? const OiIcon.decorative(icon: OiIcons.image);
    if (src.startsWith('data:') && bundle == null) return fallback;
    final image = OiImage(
      src: src,
      alt: alt,
      width: widthInPixels,
      height: heightInPixels,
      fit: fit,
      errorWidget: fallback,
    );
    return bundle == null
        ? image
        : DefaultAssetBundle(bundle: bundle, child: image);
  }

  static Uint8List? _imageBytes(String src) {
    if (!src.startsWith('data:')) return null;
    try {
      final data = UriData.parse(src);
      return data.mimeType.toLowerCase().startsWith('image/')
          ? data.contentAsBytes()
          : null;
    } on FormatException {
      return null;
    }
  }
}

final class _DataImageBundle extends CachingAssetBundle {
  _DataImageBundle(this.parent, this.source, this.bytes);

  final AssetBundle parent;
  final String source;
  final Uint8List bytes;

  @override
  Future<ByteData> load(String key) => key == source
      ? Future.value(ByteData.sublistView(bytes))
      : parent.load(key);
}
