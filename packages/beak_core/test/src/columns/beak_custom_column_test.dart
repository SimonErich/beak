import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/runtime_values.dart';

void main() {
  const tag = BeakColumnTag('row_actions');
  const column = BeakCustomColumn(key: 'actions', label: 'Actions', tag: tag);

  test('renders through the custom escape hatch in every context', () {
    for (final context in BeakContext.values) {
      expect(column.intentFor(context), BeakRenderIntent.custom);
    }
  });

  test('carries opaque values for the registered builder', () {
    expect(column.valueType, Object);
  });

  test('exposes its renderer tag', () {
    expect(column.tag, tag);
  });

  group('BeakColumnTag', () {
    test('tags with the same value are equal', () {
      final rebuilt = BeakColumnTag(runtimeValue('row_actions'));
      expect(rebuilt, tag);
      expect(rebuilt.hashCode, tag.hashCode);
    });

    test('tags with different values differ', () {
      expect(const BeakColumnTag('other'), isNot(tag));
    });

    test('tags never equal other types', () {
      expect(tag == runtimeValue<Object>('row_actions'), isFalse);
    });

    test('prints its value for debugging', () {
      expect(tag.toString(), contains('row_actions'));
    });
  });
}
