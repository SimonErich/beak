import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

const BeakStringColumn _name = BeakStringColumn(key: 'name', label: 'Name');

/// A minimal registrable model for [table].
final class _StubModel extends BeakModel {
  const _StubModel(this.table);

  @override
  final String table;

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [_name];
}

void main() {
  late BeakModelRegistry registry;

  setUp(() {
    registry = BeakModelRegistry();
  });

  test('register + byTable round-trips a model', () {
    const model = _StubModel('products');
    registry.register(model);
    expect(registry.byTable('products'), same(model));
  });

  test('byTable returns null for an unknown table', () {
    expect(registry.byTable('missing'), isNull);
  });

  test('byTableOrThrow returns the registered model', () {
    const model = _StubModel('products');
    registry.register(model);
    expect(registry.byTableOrThrow('products'), same(model));
  });

  test('byTableOrThrow throws BeakConfigurationException for an unknown '
      'table', () {
    expect(
      () => registry.byTableOrThrow('missing'),
      throwsA(
        isA<BeakConfigurationException>().having(
          (exception) => exception.message,
          'message',
          contains('missing'),
        ),
      ),
    );
  });

  test('registering the same table twice throws '
      'BeakConfigurationException', () {
    registry.register(const _StubModel('products'));
    expect(
      () => registry.register(const _StubModel('products')),
      throwsA(
        isA<BeakConfigurationException>().having(
          (exception) => exception.message,
          'message',
          contains('products'),
        ),
      ),
    );
  });

  test('all lists models in registration order', () {
    const first = _StubModel('products');
    const second = _StubModel('orders');
    registry
      ..register(first)
      ..register(second);
    expect(registry.all, const [first, second]);
  });

  test('all is unmodifiable', () {
    registry.register(const _StubModel('products'));
    expect(() => registry.all.clear(), throwsUnsupportedError);
  });
}
