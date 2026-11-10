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

/// A model whose permissions name a command its behavior never declares.
final class _GrantsUnknownCommand extends BeakModel {
  const _GrantsUnknownCommand();

  @override
  String get table => 'orders';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [_name];

  @override
  BeakPermissions get permissions =>
      const BeakPermissions(actions: {'archive': BeakAccess.anyone});
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

  test('of registers every model it is given', () {
    const first = _StubModel('products');
    const second = _StubModel('orders');

    final built = BeakModelRegistry.of(const [first, second]);

    expect(built.all, const [first, second]);
    expect(built.byTable('orders'), same(second));
  });

  test('of refuses two models that share a table', () {
    expect(
      () => BeakModelRegistry.of(const [
        _StubModel('products'),
        _StubModel('products'),
      ]),
      throwsA(isA<BeakConfigurationException>()),
    );
  });

  test('a permission for a command the behavior does not declare is '
      'refused', () {
    expect(
      () => registry.register(const _GrantsUnknownCommand()),
      throwsA(
        isA<BeakConfigurationException>().having(
          (exception) => exception.message,
          'message',
          allOf(contains('"archive"'), contains('does not declare')),
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
