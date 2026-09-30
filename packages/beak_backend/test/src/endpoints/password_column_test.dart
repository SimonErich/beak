/// A password column is write-only over HTTP: its stored value is never
/// returned, and it cannot be used to filter, sort or aggregate, because a
/// `startsWith` filter on a hash would reveal it one character at a time.
library;

import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

final class _Account extends BeakModel {
  const _Account();

  @override
  String get table => 'accounts';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
    BeakStringColumn(
      key: 'secret',
      label: 'Secret',
      semantic: BeakSemantic.password(),
    ),
  ];
}

void main() {
  late Handler handler;
  late String token;

  setUp(() async {
    Worm.seedRandom(42);
    final adapter = InMemoryAdapter();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(
        table: 'accounts',
        columns: [
          SchemaColumn(name: 'id', type: ColumnType.text, isPrimaryKey: true),
          SchemaColumn(name: 'name', type: ColumnType.text),
          SchemaColumn(name: 'secret', type: ColumnType.text),
        ],
      ),
    );
    final registry = BeakModelRegistry()..register(const _Account());
    final source = WormDataSource(registry, adapter: adapter);
    await source.create(
      'accounts',
      BeakRecord.fromRow({'id': 'a', 'name': 'Ann', 'secret': r'$2b$hash'}),
    );
    final store = InMemoryTokenSessionStore();
    token = await store.createSession(
      const BeakPrincipal(id: 'sam', roles: {'staff'}),
    );
    const staff = BeakAccess.role('staff');
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
                BeakModelRules(const _Account(), read: staff, write: staff),
              ],
            ),
          ),
        );
  });

  tearDown(Worm.reset);

  Future<Response> send(String method, String path, [Object? body]) async =>
      handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          headers: {'authorization': 'Bearer $token'},
          body: body == null ? null : jsonEncode(body),
        ),
      );

  Map<String, Object?> queryBody(Map<String, Object?> extra) => {
    'table': 'accounts',
    ...extra,
  };

  test('a read by id leaves the stored password out', () async {
    final response = await send('GET', '/api/accounts/a');
    final text = await response.readAsString();

    expect(response.statusCode, 200, reason: text);
    expect(text, contains('Ann'));
    expect(text, isNot(contains('hash')));
  });

  test('a query leaves the stored password out', () async {
    final response = await send('POST', '/api/accounts/query', queryBody({}));
    final text = await response.readAsString();

    expect(response.statusCode, 200, reason: text);
    expect(text, contains('Ann'));
    expect(text, isNot(contains('hash')));
  });

  test('a filter on the password is refused', () async {
    final response = await send(
      'POST',
      '/api/accounts/query',
      queryBody({
        'filter': const BeakFieldFilter.forKey(
          'secret',
          BeakOperator.startsWith,
          BeakStringValue(r'$2b'),
        ).toJson(),
      }),
    );

    expect(response.statusCode, 422, reason: await response.readAsString());
  });

  test('a sort by the password is refused', () async {
    final response = await send(
      'POST',
      '/api/accounts/query',
      queryBody({
        'sorts': [const BeakSort('secret').toJson()],
      }),
    );

    expect(response.statusCode, 422, reason: await response.readAsString());
  });

  test('a create response leaves the password it was given out', () async {
    final response = await send('POST', '/api/accounts', {
      'name': 'Bo',
      'secret': 'plain-text-secret',
    });
    final text = await response.readAsString();

    expect(response.statusCode, 201, reason: text);
    expect(text, isNot(contains('plain-text-secret')));
  });

  test('capabilities still offer the password field to a form', () async {
    final response = await send('GET', '/api/accounts/capabilities');
    final json = jsonDecode(await response.readAsString()) as Map;

    expect(json['readableFields'], contains('secret'));
    expect(json['writableFields'], contains('secret'));
  });
}
