/// The two legacy-schema shapes that only a real Postgres can prove: a serial
/// integer primary key the database assigns (create relies on `RETURNING`),
/// and a native enum column (a label must be writable, not only readable).
@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

enum _TicketState { open, closed }

final class _TicketModel extends BeakModel {
  const _TicketModel();

  static const BeakColumn _id = BeakIntColumn(key: 'id', label: 'Id');

  @override
  String get table => 'e2e_legacy_tickets';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const [
    _id,
    BeakStringColumn(key: 'title', label: 'Title'),
    BeakEnumColumn<_TicketState>(
      key: 'state',
      label: 'State',
      values: _TicketState.values,
    ),
  ];
}

final Uri _databaseUrl = Uri.parse(
  Platform.environment['DATABASE_URL'] ??
      'postgres://beak:beak@localhost:25432/beak',
);

Future<bool> _reachable() async {
  try {
    final socket = await Socket.connect(
      _databaseUrl.host,
      _databaseUrl.port,
      timeout: const Duration(seconds: 3),
    );
    await socket.close();
    return true;
  } on Object {
    return false;
  }
}

void main() {
  late bool reachable;
  DatabaseAdapter? adapter;
  late Handler handler;

  setUpAll(() async {
    reachable = await _reachable();
  });

  setUp(() async {
    if (!reachable) {
      markTestSkipped(
        'Postgres is unreachable at ${_databaseUrl.host}:${_databaseUrl.port}.',
      );
      return;
    }
    final connected = adapterFromUrl(_databaseUrl);
    await connected.connect();
    adapter = connected;
    await Worm.initialize(
      config: const WormConfig(),
      adapters: <String, DatabaseAdapter>{'default': connected},
    );
    await connected.rawExecute(
      'DROP TABLE IF EXISTS e2e_legacy_tickets',
      const [],
    );
    await connected.rawExecute(
      'DROP TYPE IF EXISTS e2e_ticket_state',
      const [],
    );
    await connected.rawExecute(
      "CREATE TYPE e2e_ticket_state AS ENUM ('open', 'closed')",
      const [],
    );
    await connected.rawExecute(
      'CREATE TABLE e2e_legacy_tickets ('
      'id serial PRIMARY KEY, '
      'title varchar(255), '
      "state e2e_ticket_state NOT NULL DEFAULT 'open')",
      const [],
    );
    await const BeakCommitReceiptsMigration().up(connected);
    final registry = BeakModelRegistry()..register(const _TicketModel());
    handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: WormDataSource(registry, adapter: connected),
          ),
        );
  });

  tearDown(() async {
    final connected = adapter;
    if (connected == null) return;
    await connected.rawExecute(
      'DROP TABLE IF EXISTS e2e_legacy_tickets',
      const [],
    );
    await connected.rawExecute(
      'DROP TYPE IF EXISTS e2e_ticket_state',
      const [],
    );
    await Worm.reset();
    adapter = null;
  });

  Future<Response> call(String method, String path, {Object? body}) async =>
      handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          body: body == null ? null : jsonEncode(body),
        ),
      );

  Future<BeakRecord> recordOf(Response response, int status) async {
    final text = await response.readAsString();
    expect(response.statusCode, status, reason: text);
    return switch (jsonDecode(text)) {
      final Map<String, Object?> json => BeakRecord.fromJson(json),
      final Object? other => fail('Expected a JSON object, got $other.'),
    };
  }

  test('create takes a serial integer key from RETURNING', () async {
    final first = await recordOf(
      await call('POST', '/api/e2e_legacy_tickets', body: {'title': 'One'}),
      201,
    );
    final second = await recordOf(
      await call('POST', '/api/e2e_legacy_tickets', body: {'title': 'Two'}),
      201,
    );

    expect(first['id']?.raw, isA<int>());
    expect(second['id']?.raw, (first['id']?.raw as int) + 1);
    final fetched = await recordOf(
      await call('GET', '/api/e2e_legacy_tickets/${first['id']?.raw}'),
      200,
    );
    expect(fetched['title']?.raw, 'One');
    expect(
      (await call(
        'DELETE',
        '/api/e2e_legacy_tickets/${first['id']?.raw}',
      )).statusCode,
      204,
    );
  });

  test('a label can be written into and read from a native enum', () async {
    final created = await recordOf(
      await call(
        'POST',
        '/api/e2e_legacy_tickets',
        body: {'title': 'Enum', 'state': 'closed'},
      ),
      201,
    );
    expect(created['state']?.raw, 'closed');

    final id = created['id']?.raw;
    final reopened = await recordOf(
      await call(
        'PATCH',
        '/api/e2e_legacy_tickets/$id',
        body: {'state': 'open'},
      ),
      200,
    );
    expect(reopened['state']?.raw, 'open');

    final filtered = await call(
      'POST',
      '/api/e2e_legacy_tickets/query',
      body: const _TicketModel().query().toJson(),
    );
    expect(filtered.statusCode, 200, reason: await filtered.readAsString());
  });

  test('a graph commit writes a native enum and a serial key', () async {
    final operation = BeakSaveOperation(
      id: 'c',
      kind: BeakSaveOperationKind.create,
      target: const BeakRecordRef.draft('e2e_legacy_tickets', 'draft-1'),
      values: BeakRecord.fromRow({'title': 'Committed', 'state': 'closed'}),
    );
    final plan = BeakSavePlan(
      saveId: 'e2e-legacy-1',
      root: operation.target,
      operations: [operation],
    );
    final response = await call('POST', '/api/commits', body: plan.toJson());
    final result = BeakSaveResult.fromJson(switch (jsonDecode(
      await response.readAsString(),
    )) {
      final Map<String, Object?> json => json,
      final Object? other => fail('Expected a JSON object, got $other.'),
    });

    expect(result.complete, isTrue, reason: '${result.outcomes.first.error}');
    expect(result.outcomes.single.resolvedId, isA<int>());
    expect(result.outcomes.single.record?['state']?.raw, 'closed');
  });
}
