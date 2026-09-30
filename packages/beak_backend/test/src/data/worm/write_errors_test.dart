import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

/// What the database refuses is the caller's to hear about: a row that
/// breaks a foreign key, a CHECK, a NOT NULL or a column's size is a 4xx,
/// with the column named when the driver names it, never an opaque 500.
final class _ShelfModel extends BeakModel {
  const _ShelfModel();

  @override
  String get table => 'shelves';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];

  @override
  List<BeakRelationship> get relationships => const [
    BeakHasMany(
      key: 'books',
      label: 'Books',
      relatedTable: 'books',
      displayColumnKey: 'title',
      foreignKey: 'shelf_id',
    ),
    BeakHasMany(
      key: 'tomes',
      label: 'Tomes',
      relatedTable: 'tomes',
      displayColumnKey: 'id',
      foreignKey: 'shelf_id',
    ),
  ];
}

final class _TomeModel extends BeakModel {
  const _TomeModel();

  @override
  String get table => 'tomes';

  @override
  String get displayColumnKey => 'id';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'shelf_id', label: 'Shelf'),
  ];
}

final class _BookModel extends BeakModel {
  const _BookModel();

  @override
  String get table => 'books';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'title', label: 'Title'),
    BeakIntColumn(key: 'pages', label: 'Pages'),
    BeakStringColumn(key: 'shelf_id', label: 'Shelf'),
  ];

  @override
  List<BeakRelationship> get relationships => const [
    BeakBelongsTo(
      key: 'shelf',
      label: 'Shelf',
      relatedTable: 'shelves',
      displayColumnKey: 'name',
      foreignKey: 'shelf_id',
    ),
  ];
}

/// An adapter that refuses every write the way PostgreSQL refuses a string
/// longer than its column: a [DataException] from the driver.
final class _TooLongAdapter implements DatabaseAdapter {
  _TooLongAdapter({this.column});

  final String? column;

  DataException get _refusal => DataException(
    table: 'books',
    column: column,
    message: 'value too long for type character varying(255)',
  );

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor d) =>
      Future.error(_refusal);

  @override
  Future<int> update(UpdateDescriptor d) => Future.error(_refusal);

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) =>
      Future.error(_refusal);

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) =>
      Future.error(_refusal);

  @override
  Future<int> count(AggregateDescriptor d) => Future.error(_refusal);

  @override
  Future<num?> sum(AggregateDescriptor d) => Future.error(_refusal);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  group('over SQLite with real constraints', () {
    late SqliteAdapter adapter;
    late WormDataSource source;

    setUp(() async {
      adapter = SqliteAdapter.memory();
      await adapter.connect();
      await adapter.rawExecute(
        'CREATE TABLE shelves (id TEXT PRIMARY KEY, name TEXT)',
        const [],
      );
      await adapter.rawExecute(
        'CREATE TABLE books ('
        'id TEXT PRIMARY KEY, '
        'title TEXT NOT NULL, '
        'pages INTEGER CHECK (pages > 0), '
        'shelf_id TEXT REFERENCES shelves (id))',
        const [],
      );
      final registry = BeakModelRegistry()
        ..register(const _ShelfModel())
        ..register(const _BookModel());
      source = WormDataSource(registry, adapter: adapter);
      await source.create(
        'shelves',
        BeakRecord.fromRow({'id': 's1', 'name': 'Poetry'}),
      );
      await source.create(
        'books',
        BeakRecord.fromRow({
          'id': 'b1',
          'title': 'Odes',
          'pages': 120,
          'shelf_id': 's1',
        }),
      );
    });

    tearDown(() => adapter.disconnect());

    Matcher validation(String mentions, {String? column}) =>
        isA<BeakValidationException>()
            .having((e) => e.message, 'message', contains(mentions))
            .having(
              (e) => e.fieldErrors.keys,
              'fieldErrors',
              column == null ? isEmpty : contains(column),
            );

    test('creating a row that points at no shelf is a 422', () {
      expect(
        () => source.create(
          'books',
          BeakRecord.fromRow({
            'id': 'b2',
            'title': 'Ghost',
            'pages': 1,
            'shelf_id': 'nope',
          }),
        ),
        throwsA(validation('does not exist')),
      );
    });

    test('moving a row to a shelf that is not there is a 422', () {
      expect(
        () => source.update(
          'books',
          'b1',
          BeakRecord.fromRow({'shelf_id': 'nope'}),
        ),
        throwsA(validation('does not exist')),
      );
    });

    test('attaching books to a shelf that is not there is a 404', () {
      expect(
        () => source.attach('shelves', 'nope', 'books', ['b1']),
        throwsA(isA<BeakNotFoundException>()),
      );
    });

    test('force-deleting a shelf that still holds a book is a 409', () {
      expect(
        () => source.delete('shelves', 's1', force: true),
        throwsA(
          isA<BeakConflictException>().having(
            (e) => e.message,
            'message',
            contains('still referenced'),
          ),
        ),
      );
    });

    test('a CHECK the row breaks is a 422', () {
      expect(
        () => source.update('books', 'b1', BeakRecord.fromRow({'pages': 0})),
        throwsA(validation('not allowed')),
      );
    });

    test('a missing NOT NULL value is a 422 naming the column', () {
      expect(
        () => source.create(
          'books',
          BeakRecord.fromRow({'id': 'b3', 'title': null, 'pages': 2}),
        ),
        throwsA(validation('not allowed', column: 'title')),
      );
    });

    test('detaching a book that must have a shelf is a 422', () async {
      await adapter.rawExecute(
        'CREATE TABLE tomes (id TEXT PRIMARY KEY, shelf_id TEXT NOT NULL '
        'REFERENCES shelves (id))',
        const [],
      );
      await adapter.rawExecute(
        "INSERT INTO tomes (id, shelf_id) VALUES ('t1', 's1')",
        const [],
      );
      final registry = BeakModelRegistry()
        ..register(const _ShelfModel())
        ..register(const _BookModel())
        ..register(const _TomeModel());
      final tomes = WormDataSource(registry, adapter: adapter);
      expect(
        () => tomes.detach('shelves', 's1', 'tomes', ['t1']),
        throwsA(validation('not allowed')),
      );
    });

    test('a duplicate key stays a 409', () {
      expect(
        () => source.create(
          'books',
          BeakRecord.fromRow({'id': 'b1', 'title': 'Again', 'pages': 3}),
        ),
        throwsA(isA<BeakConflictException>()),
      );
    });
  });

  group('a value the database cannot hold', () {
    WormDataSource sourceRefusing({String? column}) {
      final registry = BeakModelRegistry()
        ..register(const _ShelfModel())
        ..register(const _BookModel());
      return WormDataSource(registry, adapter: _TooLongAdapter(column: column));
    }

    test('names the column when the driver does', () {
      expect(
        () => sourceRefusing(
          column: 'title',
        ).create('books', BeakRecord.fromRow({'id': 'b', 'title': 'x' * 300})),
        throwsA(
          isA<BeakValidationException>()
              .having((e) => e.message, 'message', contains('too long'))
              .having((e) => e.fieldErrors.keys, 'fields', ['title']),
        ),
      );
    });

    test('is generic when the driver names none', () {
      expect(
        () => sourceRefusing().update(
          'books',
          'b1',
          BeakRecord.fromRow({'title': 'x' * 300}),
        ),
        throwsA(
          isA<BeakValidationException>()
              .having((e) => e.message, 'message', contains('too long'))
              .having((e) => e.fieldErrors, 'fields', isEmpty),
        ),
      );
    });

    group('in a query', () {
      final spec = const BeakQuerySpec(table: 'books').withFilter(
        const BeakFieldFilter.forKey(
          'pages',
          BeakOperator.eq,
          BeakIntValue(9223372036854775807),
        ),
      );

      test('a page query says the operand does not fit', () {
        expect(
          () => sourceRefusing().query(spec),
          throwsA(
            isA<BeakValidationException>().having(
              (e) => e.message,
              'message',
              contains('does not fit'),
            ),
          ),
        );
      });

      test('a count says the operand does not fit', () {
        expect(
          () => sourceRefusing().aggregate(
            const BeakAggregateSpec.count(
              table: 'books',
              filter: BeakFieldFilter.forKey(
                'pages',
                BeakOperator.eq,
                BeakIntValue(9223372036854775807),
              ),
            ),
          ),
          throwsA(isA<BeakValidationException>()),
        );
      });

      test('a fetch by key says the key does not fit', () {
        expect(
          () => sourceRefusing().getOne('books', 'b1'),
          throwsA(isA<BeakValidationException>()),
        );
      });
    });

    test('ignores a column that is not a field of the model', () {
      expect(
        () => sourceRefusing(
          column: 'secret',
        ).create('books', BeakRecord.fromRow({'id': 'b', 'title': 'x'})),
        throwsA(
          isA<BeakValidationException>().having(
            (e) => e.fieldErrors,
            'fields',
            isEmpty,
          ),
        ),
      );
    });
  });
}
