/// Spec alias `cursorPaginate(after:)` decoding an encoded cursor token.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/pagination/cursor.dart';
import 'package:worm/src/pagination/paginator.dart' as paginator;
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/query_builder.dart';
import 'package:worm/src/query/query_context.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';

T _read<T>(Map<String, Object?> row, String key, T fallback) {
  final value = row[key];
  if (value is T) return value;
  return fallback;
}

final class _Row extends Model {
  _Row({required this.rowId, required this.name});

  factory _Row.fromRow(Map<String, Object?> row) => _Row(
    rowId: _read<int>(row, 'id', 0),
    name: _read<String>(row, 'name', ''),
  );

  final int rowId;
  final String name;

  @override
  Object get id => rowId;

  @override
  Map<String, Object?> toRow() => <String, Object?>{'id': rowId, 'name': name};
}

Future<InMemoryAdapter> _seededAdapter() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'rows'),
  );
  await adapter.insertMany(
    InsertManyDescriptor(
      table: 'rows',
      rows: <Map<String, Object?>>[
        for (var i = 1; i <= 25; i++)
          <String, Object?>{'id': i, 'name': 'row-$i'},
      ],
    ),
  );
  return adapter;
}

QueryContext<_Row> _ctx(InMemoryAdapter adapter) =>
    QueryContext<_Row>(adapter: adapter, table: 'rows', hydrate: _Row.fromRow);

void main() {
  group('cursorPaginate(after:) alias', () {
    test('decodes after token into the same Cursor as direct cursor', () async {
      final adapter = await _seededAdapter();
      final ctx = _ctx(adapter);
      final first = await paginator.cursorPaginate<_Row>(
        context: ctx,
        descriptor: const QueryDescriptor(table: 'rows'),
        perPage: 10,
      );
      final token = first.nextCursor!.encode();

      final viaCursor = await paginator.cursorPaginate<_Row>(
        context: ctx,
        descriptor: const QueryDescriptor(table: 'rows'),
        perPage: 10,
        cursor: Cursor.decode(token),
      );
      final viaAfter = await paginator.cursorPaginate<_Row>(
        context: ctx,
        descriptor: const QueryDescriptor(table: 'rows'),
        perPage: 10,
        after: token,
      );

      expect(
        viaAfter.data.map((r) => r.rowId).toList(),
        viaCursor.data.map((r) => r.rowId).toList(),
      );
      expect(viaAfter.nextCursor?.encode(), viaCursor.nextCursor?.encode());
      expect(viaAfter.perPage, viaCursor.perPage);
    });

    test('after: null is equivalent to no cursor', () async {
      final adapter = await _seededAdapter();
      final ctx = _ctx(adapter);
      final viaAfter = await paginator.cursorPaginate<_Row>(
        context: ctx,
        descriptor: const QueryDescriptor(table: 'rows'),
        perPage: 5,
      );
      final viaCursor = await paginator.cursorPaginate<_Row>(
        context: ctx,
        descriptor: const QueryDescriptor(table: 'rows'),
        perPage: 5,
      );
      expect(viaAfter.data.first.rowId, viaCursor.data.first.rowId);
    });

    test('passing both cursor and after throws ArgumentError', () async {
      final adapter = await _seededAdapter();
      final ctx = _ctx(adapter);
      await expectLater(
        paginator.cursorPaginate<_Row>(
          context: ctx,
          descriptor: const QueryDescriptor(table: 'rows'),
          perPage: 5,
          cursor: const Cursor(field: 'id', value: 1, id: 1),
          after: 'abc',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('QueryBuilder.cursorPaginate forwards after:', () async {
      final adapter = await _seededAdapter();
      final ctx = _ctx(adapter);
      final first = await QueryBuilder<_Row>.from(
        ctx,
      ).cursorPaginate(perPage: 10);
      final token = first.nextCursor!.encode();
      final second = await QueryBuilder<_Row>.from(
        ctx,
      ).cursorPaginate(perPage: 10, after: token);
      expect(second.data.first.rowId, 11);
    });
  });
}
