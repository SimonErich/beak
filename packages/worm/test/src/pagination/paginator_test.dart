import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/pagination/cursor.dart';
import 'package:worm/src/pagination/page.dart';
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

Future<InMemoryAdapter> _adapterWith({required int rowCount}) async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'rows'),
  );
  if (rowCount > 0) {
    await adapter.insertMany(
      InsertManyDescriptor(
        table: 'rows',
        rows: <Map<String, Object?>>[
          for (var i = 1; i <= rowCount; i++)
            <String, Object?>{'id': i, 'name': 'row-$i'},
        ],
      ),
    );
  }
  return adapter;
}

QueryContext<_Row> _ctx(InMemoryAdapter adapter) =>
    QueryContext<_Row>(adapter: adapter, table: 'rows', hydrate: _Row.fromRow);

void main() {
  group('paginate (offset)', () {
    test('25 rows, page 1, perPage 10 -> from=1 to=10 lastPage=3', () async {
      final adapter = await _adapterWith(rowCount: 25);
      final ctx = _ctx(adapter);
      final result = await paginator.paginate<_Row>(
        context: ctx,
        descriptor: const QueryDescriptor(table: 'rows'),
        page: 1,
        perPage: 10,
      );
      expect(result.data, hasLength(10));
      expect(result.total, 25);
      expect(result.currentPage, 1);
      expect(result.lastPage, 3);
      expect(result.from, 1);
      expect(result.to, 10);
      expect(result.hasMorePages, isTrue);
    });

    test(
      '25 rows, page 3 -> 5 rows, from=21 to=25, hasMorePages=false',
      () async {
        final adapter = await _adapterWith(rowCount: 25);
        final ctx = _ctx(adapter);
        final result = await paginator.paginate<_Row>(
          context: ctx,
          descriptor: const QueryDescriptor(table: 'rows'),
          page: 3,
          perPage: 10,
        );
        expect(result.data, hasLength(5));
        expect(result.from, 21);
        expect(result.to, 25);
        expect(result.hasMorePages, isFalse);
      },
    );

    test('25 rows, page 4 (beyond last) -> empty data, from=0 to=0', () async {
      final adapter = await _adapterWith(rowCount: 25);
      final ctx = _ctx(adapter);
      final result = await paginator.paginate<_Row>(
        context: ctx,
        descriptor: const QueryDescriptor(table: 'rows'),
        page: 4,
        perPage: 10,
      );
      expect(result.data, isEmpty);
      expect(result.from, 0);
      expect(result.to, 0);
      expect(result.hasMorePages, isFalse);
    });

    test('empty table -> total=0, lastPage=1, from=0, to=0, data=[]', () async {
      final adapter = await _adapterWith(rowCount: 0);
      final ctx = _ctx(adapter);
      final result = await paginator.paginate<_Row>(
        context: ctx,
        descriptor: const QueryDescriptor(table: 'rows'),
        perPage: 10,
      );
      expect(result.data, isEmpty);
      expect(result.total, 0);
      expect(result.lastPage, 1);
      expect(result.from, 0);
      expect(result.to, 0);
      expect(result.hasMorePages, isFalse);
    });

    test('QueryBuilder.paginate delegates to top-level function', () async {
      final adapter = await _adapterWith(rowCount: 25);
      final ctx = _ctx(adapter);
      // ignore: omit_local_variable_types — assert delegated return type.
      final Page<_Row> result = await QueryBuilder<_Row>.from(
        ctx,
      ).paginate(page: 1, perPage: 10);
      expect(result.data, hasLength(10));
      expect(result.total, 25);
    });
  });

  group('cursorPaginate', () {
    test('first call returns perPage rows and a non-null nextCursor', () async {
      final adapter = await _adapterWith(rowCount: 25);
      final ctx = _ctx(adapter);
      final page = await paginator.cursorPaginate<_Row>(
        context: ctx,
        descriptor: const QueryDescriptor(table: 'rows'),
        perPage: 10,
      );
      expect(page.data, hasLength(10));
      expect(page.nextCursor, isNotNull);
      expect(page.hasMorePages, isTrue);
    });

    test('follow-up call returns the next perPage rows', () async {
      final adapter = await _adapterWith(rowCount: 25);
      final ctx = _ctx(adapter);
      final page1 = await paginator.cursorPaginate<_Row>(
        context: ctx,
        descriptor: const QueryDescriptor(table: 'rows'),
        perPage: 10,
      );
      final page2 = await paginator.cursorPaginate<_Row>(
        context: ctx,
        descriptor: const QueryDescriptor(table: 'rows'),
        perPage: 10,
        cursor: page1.nextCursor,
      );
      expect(page2.data, hasLength(10));
      expect(page2.data.first.rowId, 11);
      expect(page2.data.last.rowId, 20);
    });

    test('last page (< perPage rows) returns nextCursor=null', () async {
      final adapter = await _adapterWith(rowCount: 25);
      final ctx = _ctx(adapter);
      final page = await paginator.cursorPaginate<_Row>(
        context: ctx,
        descriptor: const QueryDescriptor(table: 'rows'),
        perPage: 30,
      );
      expect(page.data, hasLength(25));
      expect(page.nextCursor, isNull);
      expect(page.hasMorePages, isFalse);
    });

    test('empty table returns data=[] and nextCursor=null', () async {
      final adapter = await _adapterWith(rowCount: 0);
      final ctx = _ctx(adapter);
      final page = await paginator.cursorPaginate<_Row>(
        context: ctx,
        descriptor: const QueryDescriptor(table: 'rows'),
        perPage: 10,
      );
      expect(page.data, isEmpty);
      expect(page.nextCursor, isNull);
      expect(page.hasMorePages, isFalse);
    });

    test('two sequential pages do not return duplicate rows', () async {
      final adapter = await _adapterWith(rowCount: 25);
      final ctx = _ctx(adapter);
      final page1 = await paginator.cursorPaginate<_Row>(
        context: ctx,
        descriptor: const QueryDescriptor(table: 'rows'),
        perPage: 5,
      );
      final page2 = await paginator.cursorPaginate<_Row>(
        context: ctx,
        descriptor: const QueryDescriptor(table: 'rows'),
        perPage: 5,
        cursor: page1.nextCursor,
      );
      final union = <Object>{
        ...page1.data.map((r) => r.id),
        ...page2.data.map((r) => r.id),
      };
      expect(union, hasLength(10));
    });

    test(
      'QueryBuilder.cursorPaginate delegates to top-level function',
      () async {
        final adapter = await _adapterWith(rowCount: 25);
        final ctx = _ctx(adapter);
        final first = await QueryBuilder<_Row>.from(
          ctx,
        ).cursorPaginate(perPage: 5);
        expect(first.data, hasLength(5));
        expect(first.nextCursor, isNotNull);
      },
    );
  });

  group('Cursor encode/decode', () {
    test('round-trips field, value, id correctly', () {
      const original = Cursor(field: 'id', value: 42, id: 42);
      final decoded = Cursor.decode(original.encode());
      expect(decoded, isNotNull);
      expect(decoded!.field, original.field);
      expect(decoded.value, original.value);
      expect(decoded.id, original.id);
    });

    test('round-trips with a non-id ordering column', () {
      const original = Cursor(
        field: 'created_at',
        value: '2024-01-01T00:00:00Z',
        id: 99,
      );
      final decoded = Cursor.decode(original.encode());
      expect(decoded?.field, 'created_at');
      expect(decoded?.value, '2024-01-01T00:00:00Z');
      expect(decoded?.id, 99);
    });

    test('encoded token is URL-safe (uses base64Url alphabet)', () {
      const cursor = Cursor(field: 'id', value: 1, id: 1);
      final token = cursor.encode();
      // base64Url uses only [A-Za-z0-9_-=] characters.
      expect(RegExp(r'^[A-Za-z0-9_\-=]+$').hasMatch(token), isTrue);
    });

    test('decode of null, empty, or malformed token returns null', () {
      expect(Cursor.decode(null), isNull);
      expect(Cursor.decode(''), isNull);
      expect(Cursor.decode('not-a-real-cursor'), isNull);
    });
  });
}
