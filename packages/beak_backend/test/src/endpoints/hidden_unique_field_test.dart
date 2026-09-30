/// A unique column that a caller may not read is still checked for
/// uniqueness on their writes: the check asks about the whole table, so it
/// must not be refused for a column the caller cannot see.
library;

import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

final class _Item extends BeakModel {
  const _Item();

  static const sku = BeakScalarField<String>(
    model: _Item(),
    column: _skuColumn,
  );

  static const BeakColumn _skuColumn = BeakStringColumn(
    key: 'sku',
    label: 'SKU',
    unique: true,
  );

  @override
  String get table => 'items';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
    _skuColumn,
  ];
}

void main() {
  late Handler handler;
  late WormDataSource source;
  late String staffToken;
  const staffOnly = BeakAccess.role('staff');

  setUp(() async {
    Worm.seedRandom(42);
    final adapter = InMemoryAdapter();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(
        table: 'items',
        columns: [
          SchemaColumn(name: 'id', type: ColumnType.text, isPrimaryKey: true),
          SchemaColumn(name: 'name', type: ColumnType.text),
          SchemaColumn(name: 'sku', type: ColumnType.text),
        ],
      ),
    );
    final registry = BeakModelRegistry()..register(const _Item());
    source = WormDataSource(registry, adapter: adapter);
    await source.create(
      'items',
      BeakRecord.fromRow({'id': 'one', 'name': 'One', 'sku': 'A-1'}),
    );
    final store = InMemoryTokenSessionStore();
    staffToken = await store.createSession(
      const BeakPrincipal(id: 'sam', roles: {'staff'}),
    );
    handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addMiddleware(beakAuthMiddleware(guard: TokenSessionAuthGuard(store)))
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: source,
            policy: BeakPolicies(
              rules: [
                BeakModelRules(
                  const _Item(),
                  read: staffOnly,
                  write: staffOnly,
                  hiddenFields: {_Item.sku: staffOnly},
                ),
              ],
            ),
          ),
        );
  });

  tearDown(Worm.reset);

  Future<Response> send(String method, String path, Object body) async =>
      handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          headers: {'authorization': 'Bearer $staffToken'},
          body: jsonEncode(body),
        ),
      );

  test('an item can be renamed without seeing its unique code', () async {
    final response = await send('PATCH', '/api/items/one', {'name': 'Renamed'});

    expect(response.statusCode, 200, reason: await response.readAsString());
    expect((await source.getOne('items', 'one'))?['name']?.raw, 'Renamed');
  });

  test('an item can be created and validated without its code', () async {
    final created = await send('POST', '/api/items', {'name': 'Two'});
    expect(created.statusCode, 201, reason: await created.readAsString());

    final validated = await send('POST', '/api/items/validate', {
      'table': 'items',
      'recordId': 'one',
      'record': BeakRecord.fromRow({'name': 'Again'}).toJson(),
    });
    expect(validated.statusCode, 200, reason: await validated.readAsString());
  });
}
