import 'package:beak_backend/beak_backend.dart';
import 'package:beak_serverpod_flutter/tunnel.dart';
import 'package:bookshop_beak/bookshop_beak.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:worm/worm.dart';

/// A fake of `client.beakAdmin.dispatch` for the admin's widget tests.
///
/// Behind [dispatch] runs Beak's **stock** Shelf pipeline (the same
/// middlewares and `beakApiRouter` that `BeakServerpodEngine` composes on the
/// server) over the bookshop registry and worm's [InMemoryAdapter], so the
/// panel talks real envelope v1 to real Beak handlers, with no Serverpod and
/// no database process. Every envelope it receives is kept in [requests].
///
/// Differences from the real server, on purpose:
/// - the principal is fixed (`bookshop.staff`) and there is no Serverpod
///   gate: the gate is tested in the server suite;
/// - serial ids are filled in by a small adapter decorator, as Postgres's
///   `bigserial` would.
final class FakeBookshopServer {
  FakeBookshopServer._(this.adapter, this._handler);

  /// Seeds two authors and three books.
  static Future<FakeBookshopServer> seeded() async {
    final registry = buildBeakRegistry();
    final adapter = _SerialIdAdapter(InMemoryAdapter());
    for (final model in registry.all) {
      await adapter.executeSchema(
        SchemaDescriptor.createTable(
          table: model.table,
          columns: [
            for (final column in model.columns)
              SchemaColumn(
                name: column.key,
                type: ColumnType.text,
                nullable: true,
              ),
          ],
        ),
      );
    }
    await const BeakCommitReceiptsMigration().up(adapter);
    Future<void> insert(String table, Map<String, Object?> values) =>
        adapter.insert(InsertDescriptor(table: table, values: values));
    await insert('author', {'id': 1, 'name': 'Tove Jansson'});
    await insert('author', {'id': 2, 'name': 'Ursula K. Le Guin'});
    for (final (id, title, isbn, authorId, price) in [
      (1, 'Comet in Moominland', '978-0-374-31526-0', 1, 1299),
      (2, 'Finn Family Moomintroll', '978-0-374-32308-1', 1, 1199),
      (3, 'A Wizard of Earthsea', '978-0-547-77374-2', 2, 1499),
    ]) {
      await insert('book', {
        'id': id,
        'title': title,
        'isbn': isbn,
        'format': BookFormat.paperback.name,
        'priceInCents': price,
        'stock': 20,
        'authorId': authorId,
      });
    }
    final shelf.Handler handler = const shelf.Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addMiddleware(beakAuthMiddleware(guard: const _StaffGuard()))
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: WormDataSource(registry, adapter: adapter),
            policy: bookshopFakePolicy,
          ),
        );
    return FakeBookshopServer._(adapter, handler);
  }

  /// The in-memory database, for assertions.
  final DatabaseAdapter adapter;

  final shelf.Handler _handler;

  /// Every envelope the panel sent, oldest first.
  final List<BeakWireRequest> requests = [];

  /// The fake `client.beakAdmin.dispatch`.
  Future<String> dispatch(String envelope) async {
    final wire = BeakWireRequest.decode(envelope);
    requests.add(wire);
    final response = await _handler(
      shelf.Request(
        wire.method,
        Uri.parse(
          'http://beak.tunnel${wire.path}'
          '${wire.query.isEmpty ? '' : '?${wire.query}'}',
        ),
        headers: wire.headers,
        body: wire.body,
      ),
    );
    return BeakWireResponse(
      status: response.statusCode,
      headers: {
        for (final MapEntry(:key, :value) in response.headers.entries)
          if (key != 'content-length') key: value,
      },
      body: await response.readAsString(),
    ).encode();
  }

  /// The rows of [table], as the fake database holds them.
  Future<List<Map<String, Object?>>> rows(String table) =>
      adapter.select(QueryDescriptor(table: table));

  /// The paths the panel called, in order (`POST /api/book/query`).
  List<String> get calls => [
    for (final request in requests) '${request.method} ${request.path}',
  ];
}

/// The bookshop policy of the fake: staff read and write both models.
final BeakPolicies bookshopFakePolicy = BeakPolicies(
  rules: [
    BeakModelRules(
      const AuthorModel(),
      read: BeakAccess.authenticated,
      write: BeakAccess.authenticated,
    ),
    BeakModelRules(
      const BookModel(),
      read: BeakAccess.authenticated,
      write: BeakAccess.authenticated,
    ),
  ],
);

final class _StaffGuard implements BeakAuthGuard {
  const _StaffGuard();

  @override
  Future<BeakPrincipal?> authenticate(shelf.Request request) async =>
      const BeakPrincipal(
        id: '0199a0e8-0000-7000-8000-000000000001',
        roles: {'beak.admin', 'bookshop.staff'},
      );
}

/// Fills in what Postgres's `bigserial` would: an `id` for rows inserted
/// without one.
final class _SerialIdAdapter extends DatabaseAdapter {
  _SerialIdAdapter(this.inner, [Map<String, int>? sequences])
    : _sequences = sequences ?? {},
      super(capabilities: inner.capabilities);

  final DatabaseAdapter inner;
  final Map<String, int> _sequences;

  static final Set<String> _serial = {
    const AuthorModel().table,
    const BookModel().table,
  };

  Map<String, Object?> _withId(String table, Map<String, Object?> row) {
    if (!_serial.contains(table)) return row;
    final values = {...row};
    final Object? given = values['id'];
    final int current = _sequences[table] ?? 0;
    if (given is int) {
      _sequences[table] = given > current ? given : current;
    } else if (given == null) {
      values['id'] = _sequences[table] = current + 1;
    }
    return values;
  }

  @override
  Future<void> connect() => inner.connect();

  @override
  Future<void> disconnect() => inner.disconnect();

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) =>
      inner.select(d);

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) =>
      inner.selectOne(d);

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor d) => inner.insert(
    InsertDescriptor(
      table: d.table,
      values: _withId(d.table, d.values),
      returning: d.returning,
    ),
  );

  @override
  Future<List<Map<String, Object?>>> insertMany(
    InsertManyDescriptor d,
  ) async => [
    for (final row in d.rows)
      await insert(
        InsertDescriptor(table: d.table, values: row, returning: d.returning),
      ),
  ];

  @override
  Future<int> update(UpdateDescriptor d) => inner.update(d);

  @override
  Future<int> delete(DeleteDescriptor d) => inner.delete(d);

  @override
  Future<int> count(AggregateDescriptor d) => inner.count(d);

  @override
  Future<Map<Object?, num>> aggregateGrouped(AggregateDescriptor d) =>
      inner.aggregateGrouped(d);

  @override
  Future<num?> sum(AggregateDescriptor d) => inner.sum(d);

  @override
  Future<double?> avg(AggregateDescriptor d) => inner.avg(d);

  @override
  Future<Object?> min(AggregateDescriptor d) => inner.min(d);

  @override
  Future<Object?> max(AggregateDescriptor d) => inner.max(d);

  @override
  Future<List<Map<String, Object?>>> rawQuery(String q, List<Object?> p) =>
      inner.rawQuery(q, p);

  @override
  Future<int> rawExecute(String s, List<Object?> p) => inner.rawExecute(s, p);

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action) =>
      inner.transaction((tx) => action(_SerialIdAdapter(tx, _sequences)));

  @override
  Future<void> executeSchema(SchemaDescriptor d) => inner.executeSchema(d);

  @override
  Future<Map<String, List<String>>> introspectSchema() =>
      inner.introspectSchema();

  @override
  Stream<Map<String, Object?>> stream(QueryDescriptor d) => inner.stream(d);

  @override
  String compileToString(Object d) => inner.compileToString(d);
}
