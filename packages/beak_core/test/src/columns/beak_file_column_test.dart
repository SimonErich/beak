import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const column = BeakFileColumn(
    key: 'manual',
    label: 'Manual',
    storagePath: 'products/manuals',
  );

  test('renders through the custom escape hatch in every context', () {
    for (final context in BeakContext.values) {
      expect(column.intentFor(context), BeakRenderIntent.custom);
    }
  });

  test('holds stored file keys as String values', () {
    expect(column.valueType, String);
  });

  test('accepts any type and size by default', () {
    expect(column.storagePath, 'products/manuals');
    expect(column.allowedTypes, isEmpty);
    expect(column.maxSizeInBytes, isNull);
  });

  test('stores upload restrictions', () {
    const restricted = BeakFileColumn(
      key: 'manual',
      label: 'Manual',
      storagePath: 'products/manuals',
      maxSizeInBytes: 10 * 1024 * 1024,
      allowedTypes: [BeakFileType.pdf],
    );
    expect(restricted.maxSizeInBytes, 10485760);
    expect(restricted.allowedTypes, const [BeakFileType.pdf]);
  });
}
