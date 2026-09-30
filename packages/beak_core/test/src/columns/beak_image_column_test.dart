import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const column = BeakImageColumn(
    key: 'cover',
    label: 'Cover',
    storagePath: 'products/covers',
  );

  test('renders thumbnails in tables and full images elsewhere', () {
    expect(column.intentFor(BeakContext.table), BeakRenderIntent.thumbnail);
    expect(column.intentFor(BeakContext.form), BeakRenderIntent.image);
    expect(column.intentFor(BeakContext.detail), BeakRenderIntent.image);
  });

  test('has no built-in filter rendering', () {
    expect(column.intentFor(BeakContext.filter), BeakRenderIntent.custom);
  });

  test('holds stored file keys as String values', () {
    expect(column.valueType, String);
  });

  test('defaults to raster image types and an empty pipeline', () {
    expect(column.storagePath, 'products/covers');
    expect(column.allowedTypes, BeakFileType.images);
    expect(column.transforms, isEmpty);
    expect(column.maxSizeInBytes, isNull);
    expect(column.maxDimensions, isNull);
    expect(column.aspectRatio, isNull);
  });

  test('stores the full upload configuration', () {
    const configured = BeakImageColumn(
      key: 'cover',
      label: 'Cover',
      storagePath: 'products/covers',
      maxSizeInBytes: 5 * 1024 * 1024,
      allowedTypes: [BeakFileType.png, BeakFileType.webp],
      maxDimensions: BeakDimensions(widthInPixels: 4096, heightInPixels: 4096),
      aspectRatio: 16 / 9,
      transforms: [
        BeakImageTransform.resize(widthInPixels: 1600),
        BeakImageTransform.webp(quality: 85),
      ],
    );
    expect(configured.maxSizeInBytes, 5242880);
    expect(configured.allowedTypes, const [
      BeakFileType.png,
      BeakFileType.webp,
    ]);
    expect(
      configured.maxDimensions,
      const BeakDimensions(widthInPixels: 4096, heightInPixels: 4096),
    );
    expect(configured.aspectRatio, closeTo(16 / 9, 1e-9));
    expect(configured.transforms, hasLength(2));
  });
}
