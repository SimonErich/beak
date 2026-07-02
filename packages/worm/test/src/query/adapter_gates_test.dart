/// `.sql()` and `.mongo()` adapter-context gates raise
/// `AdapterMismatchException` against the wrong adapter
/// family, with both adapter names in the message.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/adapter_capabilities.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/exception/adapter_mismatch_exception.dart';
import 'package:worm/src/query/adapter_dialect.dart';
import 'package:worm/src/query/aggregate_descriptor.dart';
import 'package:worm/src/query/delete_descriptor.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/query_builder.dart';
import 'package:worm/src/query/query_context.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/query/update_descriptor.dart';

import '_fixtures.dart';

/// Stand-in adapter that declares the Mongo family via
/// [DatabaseAdapter.adapterType].
final class FakeMongoAdapter extends _DelegatingAdapter {
  FakeMongoAdapter() : super(InMemoryAdapter());

  @override
  AdapterType get adapterType => AdapterType.mongodb;
}

/// Stand-in adapter that declares the SQL family via
/// [DatabaseAdapter.adapterType].
final class FakePostgresAdapter extends _DelegatingAdapter {
  FakePostgresAdapter() : super(InMemoryAdapter());

  @override
  AdapterType get adapterType => AdapterType.sql;
}

/// Adapter that does not declare any specific family —
/// keeps the default [AdapterType.custom].
final class FakeCustomAdapter extends _DelegatingAdapter {
  FakeCustomAdapter() : super(InMemoryAdapter());
}

void main() {
  group('QueryBuilder.sql() gate', () {
    test('throws AdapterMismatchException against InMemoryAdapter', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(userContext(adapter));
      AdapterMismatchException? caught;
      try {
        qb.sql<void>((_) {});
      } on AdapterMismatchException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      if (caught case final AdapterMismatchException ex) {
        expect(ex.expectedAdapter, 'worm_postgres');
        expect(ex.actualAdapter, 'InMemoryAdapter');
        expect(ex.message, contains('worm_postgres'));
        expect(ex.message, contains('InMemoryAdapter'));
        expect(
          ex.toString(),
          allOf(contains('worm_postgres'), contains('InMemoryAdapter')),
        );
      }
    });

    test('throws AdapterMismatchException against worm_mongodb', () async {
      final adapter = FakeMongoAdapter();
      await adapter.connect();
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(table: 'users'),
      );
      final qb = QueryBuilder<TestUser>.from(
        QueryContext<TestUser>(
          adapter: adapter,
          table: 'users',
          hydrate: TestUser.fromRow,
        ),
      );
      expect(
        () => qb.sql<void>((_) {}),
        throwsA(
          isA<AdapterMismatchException>()
              .having((e) => e.expectedAdapter, 'expected', 'worm_postgres')
              .having((e) => e.actualAdapter, 'actual', 'FakeMongoAdapter')
              .having(
                (e) => e.message,
                'message',
                allOf(contains('worm_postgres'), contains('FakeMongoAdapter')),
              ),
        ),
      );
    });

    test('succeeds against a Postgres-like adapter', () async {
      final adapter = FakePostgresAdapter();
      await adapter.connect();
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(table: 'users'),
      );
      final qb = QueryBuilder<TestUser>.from(
        QueryContext<TestUser>(
          adapter: adapter,
          table: 'users',
          hydrate: TestUser.fromRow,
        ),
      );
      // Returns whatever the callback returns.
      final tag = qb.sql<String>((sql) => 'OK:${sql.builder.descriptor.table}');
      expect(tag, 'OK:users');
    });
  });

  group('QueryBuilder.mongo() gate', () {
    test('throws AdapterMismatchException against InMemoryAdapter', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(userContext(adapter));
      expect(
        () => qb.mongo<void>((_) {}),
        throwsA(
          isA<AdapterMismatchException>()
              .having((e) => e.expectedAdapter, 'expected', 'worm_mongodb')
              .having((e) => e.actualAdapter, 'actual', 'InMemoryAdapter'),
        ),
      );
    });

    test('succeeds against a Mongo-like adapter', () async {
      final adapter = FakeMongoAdapter();
      await adapter.connect();
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(table: 'users'),
      );
      final qb = QueryBuilder<TestUser>.from(
        QueryContext<TestUser>(
          adapter: adapter,
          table: 'users',
          hydrate: TestUser.fromRow,
        ),
      );
      final tag = qb.mongo<String>(
        (mongo) => 'OK:${mongo.builder.descriptor.table}',
      );
      expect(tag, 'OK:users');
    });
  });

  group('AdapterType identification', () {
    test('DatabaseAdapter.adapterType defaults to AdapterType.custom', () {
      expect(FakeCustomAdapter().adapterType, AdapterType.custom);
    });

    test('InMemoryAdapter.adapterType is AdapterType.inMemory', () {
      expect(InMemoryAdapter().adapterType, AdapterType.inMemory);
    });

    test(
      '.sql() against a default custom adapter throws AdapterMismatchException',
      () async {
        final adapter = FakeCustomAdapter();
        await adapter.connect();
        final qb = QueryBuilder<TestUser>.from(
          QueryContext<TestUser>(
            adapter: adapter,
            table: 'users',
            hydrate: TestUser.fromRow,
          ),
        );
        expect(
          () => qb.sql<void>((_) {}),
          throwsA(isA<AdapterMismatchException>()),
        );
      },
    );

    test('.mongo() against a default custom adapter throws '
        'AdapterMismatchException', () async {
      final adapter = FakeCustomAdapter();
      await adapter.connect();
      final qb = QueryBuilder<TestUser>.from(
        QueryContext<TestUser>(
          adapter: adapter,
          table: 'users',
          hydrate: TestUser.fromRow,
        ),
      );
      expect(
        () => qb.mongo<void>((_) {}),
        throwsA(isA<AdapterMismatchException>()),
      );
    });
  });
}

abstract base class _DelegatingAdapter extends DatabaseAdapter {
  _DelegatingAdapter(this._inner)
    : super(capabilities: const AdapterCapabilities());

  final DatabaseAdapter _inner;

  @override
  Future<void> connect() => _inner.connect();

  @override
  Future<void> disconnect() => _inner.disconnect();

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) =>
      _inner.select(d);

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) =>
      _inner.selectOne(d);

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor d) => _inner.insert(d);

  @override
  Future<List<Map<String, Object?>>> insertMany(InsertManyDescriptor d) =>
      _inner.insertMany(d);

  @override
  Future<int> update(UpdateDescriptor d) => _inner.update(d);

  @override
  Future<int> delete(DeleteDescriptor d) => _inner.delete(d);

  @override
  Future<int> count(AggregateDescriptor d) => _inner.count(d);

  @override
  Future<num?> sum(AggregateDescriptor d) => _inner.sum(d);

  @override
  Future<double?> avg(AggregateDescriptor d) => _inner.avg(d);

  @override
  Future<Object?> min(AggregateDescriptor d) => _inner.min(d);

  @override
  Future<Object?> max(AggregateDescriptor d) => _inner.max(d);

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String query,
    List<Object?> parameters,
  ) => _inner.rawQuery(query, parameters);

  @override
  Future<int> rawExecute(String statement, List<Object?> parameters) =>
      _inner.rawExecute(statement, parameters);

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action) =>
      _inner.transaction(action);

  @override
  Future<void> executeSchema(SchemaDescriptor d) => _inner.executeSchema(d);

  @override
  Future<Map<String, List<String>>> introspectSchema() =>
      _inner.introspectSchema();

  @override
  Stream<Map<String, Object?>> stream(QueryDescriptor d) => _inner.stream(d);

  @override
  String compileToString(Object descriptor) =>
      _inner.compileToString(descriptor);
}
