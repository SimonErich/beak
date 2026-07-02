/// Live-database smoke tests for [MongoAdapter].
///
/// Gated by `MONGO_URI`. Skipped gracefully when the env
/// var is absent. Also includes unit tests that don't need a DB:
/// the rawQuery/rawExecute behaviour and the AdapterCapabilities
/// computation.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_mongodb/worm_mongodb.dart';

PredicateTree _leaf({
  required String field,
  required Operator op,
  Object? value,
}) => LeafNode(Predicate(fieldName: field, operator: op, value: value));

void main() {
  group('MongoAdapter (no DB)', () {
    test(
      'rawQuery throws AdapterMismatchException with descriptive message',
      () {
        final adapter = MongoAdapter(
          connection: MongoConnection.fromUri('mongodb://localhost/x'),
        );
        expect(
          () => adapter.rawQuery('select 1', const <Object?>[]),
          throwsA(
            isA<AdapterMismatchException>()
                .having((e) => e.message, 'message', isNotEmpty)
                .having(
                  (e) => e.actualAdapter,
                  'actualAdapter',
                  'MongoAdapter',
                ),
          ),
        );
      },
    );

    test('rawExecute throws AdapterMismatchException', () {
      final adapter = MongoAdapter(
        connection: MongoConnection.fromUri('mongodb://localhost/x'),
      );
      expect(
        () => adapter.rawExecute('drop table x', const <Object?>[]),
        throwsA(isA<AdapterMismatchException>()),
      );
    });

    test(
      'capabilities default to supportsTransactions: false (standalone)',
      () {
        final adapter = MongoAdapter(
          connection: MongoConnection.fromUri('mongodb://localhost/x'),
        );
        expect(adapter.capabilities.supportsTransactions, isFalse);
        expect(adapter.capabilities.supportsStreaming, isTrue);
        expect(adapter.capabilities.supportsAggregations, isTrue);
        expect(adapter.capabilities.supportsSchemaIntrospection, isTrue);
        expect(adapter.capabilities.supportsRawQuery, isFalse);
        expect(adapter.capabilities.supportsJoins, isFalse);
        expect(adapter.capabilities.supportsPreparedStatements, isFalse);
        // insert()/insertMany() populate the stored document via
        // _projectReturning, so the adapter materially supports
        // RETURNING-style projection even without a SQL RETURNING
        // clause.
        expect(adapter.capabilities.supportsReturning, isTrue);
      },
    );

    test('transaction() always throws — the driver has no '
        'transaction support', () async {
      final adapter = MongoAdapter(
        connection: MongoConnection.fromUri('mongodb://localhost/x'),
      );
      expect(adapter.capabilities.supportsTransactions, isFalse);
      expect(
        () => adapter.transaction((_) async => null),
        throwsA(isA<TransactionException>()),
      );
    });

    test('compileToString returns a non-empty find string', () {
      final adapter = MongoAdapter(
        connection: MongoConnection.fromUri('mongodb://localhost/x'),
      );
      final rendered = adapter.compileToString(
        const QueryDescriptor(table: 'users'),
      );
      expect(rendered, contains('db.users.find'));
    });
  });

  final url = Platform.environment['MONGO_URI'];
  if (url == null || url.isEmpty) {
    test(
      'MongoAdapter integration suite skipped — MONGO_URI unset',
      () {},
      skip:
          'Set MONGO_URI (mongodb://host:port/db) to run live '
          'integration tests.',
    );
    return;
  }

  group('MongoAdapter integration', () {
    late MongoAdapter adapter;

    setUp(() async {
      adapter = MongoAdapter(connection: MongoConnection.fromUri(url));
      await adapter.connect();
      await adapter.executeSchema(
        const SchemaDescriptor.dropTable(table: 'widgets', ifExists: true),
      );
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(table: 'widgets'),
      );
    });

    tearDown(() async {
      await adapter.executeSchema(
        const SchemaDescriptor.dropTable(table: 'widgets', ifExists: true),
      );
      await adapter.disconnect();
    });

    test('insert returns a row with "id" key (not "_id")', () async {
      final inserted = await adapter.insert(
        const InsertDescriptor(
          table: 'widgets',
          values: <String, Object?>{'id': 1, 'label': 'A'},
        ),
      );
      expect(inserted.containsKey('id'), isTrue);
      expect(inserted.containsKey('_id'), isFalse);
      expect(inserted['id'], 1);
      expect(inserted['label'], 'A');
    });

    test('select rows expose "id" key (not "_id")', () async {
      await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'widgets',
          rows: <Map<String, Object?>>[
            <String, Object?>{'id': 1, 'label': 'A'},
            <String, Object?>{'id': 2, 'label': 'B'},
          ],
        ),
      );
      final rows = await adapter.select(
        const QueryDescriptor(table: 'widgets'),
      );
      for (final row in rows) {
        expect(row.containsKey('id'), isTrue);
        expect(row.containsKey('_id'), isFalse);
      }
    });

    test('update returns the count of modified documents', () async {
      await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'widgets',
          rows: <Map<String, Object?>>[
            <String, Object?>{'id': 1, 'label': 'A'},
            <String, Object?>{'id': 2, 'label': 'B'},
          ],
        ),
      );
      final count = await adapter.update(
        UpdateDescriptor(
          table: 'widgets',
          values: const <String, Object?>{'label': 'X'},
          where: _leaf(field: 'id', op: Operator.eq, value: 1),
        ),
      );
      expect(count, 1);
    });

    test('stream yields every row with id aliasing', () async {
      await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'widgets',
          rows: <Map<String, Object?>>[
            <String, Object?>{'id': 1, 'label': 'A'},
            <String, Object?>{'id': 2, 'label': 'B'},
          ],
        ),
      );
      final streamed = await adapter
          .stream(const QueryDescriptor(table: 'widgets'))
          .toList();
      expect(streamed, hasLength(2));
      for (final row in streamed) {
        expect(row.containsKey('id'), isTrue);
        expect(row.containsKey('_id'), isFalse);
      }
    });

    test('executeSchema createTable creates a MongoDB collection', () async {
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(table: 'new_collection'),
      );
      final schema = await adapter.introspectSchema();
      expect(schema.containsKey('new_collection'), isTrue);
      await adapter.executeSchema(
        const SchemaDescriptor.dropTable(table: 'new_collection'),
      );
    });

    test('SchemaIndexDescriptor: unique violation maps to '
        'UniqueConstraintException', () async {
      await adapter.executeSchema(
        const SchemaIndexDescriptor(
          collection: 'widgets',
          field: 'label',
          unique: true,
        ),
      );
      await adapter.insert(
        const InsertDescriptor(
          table: 'widgets',
          values: <String, Object?>{'id': 1, 'label': 'A'},
        ),
      );
      expect(
        () => adapter.insert(
          const InsertDescriptor(
            table: 'widgets',
            values: <String, Object?>{'id': 2, 'label': 'A'},
          ),
        ),
        throwsA(isA<UniqueConstraintException>()),
      );
    });
  });
}
