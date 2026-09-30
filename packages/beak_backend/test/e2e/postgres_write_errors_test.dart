@Tags(['e2e'])
library;

import 'dart:io';
import 'dart:math';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

/// What PostgreSQL refuses is the caller's mistake, so the data source
/// answers a 4xx: a string longer than its `varchar`, an integer outside its
/// `integer`, a row that breaks a foreign key, a CHECK or a NOT NULL.
final Uri databaseUrl = Uri.parse(
  Platform.environment['DATABASE_URL'] ??
      'postgres://beak:beak@localhost:25432/beak',
);

Future<bool> postgresIsReachable() async {
  try {
    final socket = await Socket.connect(
      databaseUrl.host,
      databaseUrl.port,
      timeout: const Duration(seconds: 3),
    );
    await socket.close();
    return true;
  } on Object {
    return false;
  }
}

final class _ParentModel extends BeakModel {
  const _ParentModel(this.table);

  @override
  final String table;

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];
}

final class _ChildModel extends BeakModel {
  const _ChildModel(this.table, this.parentTable);

  @override
  final String table;

  final String parentTable;

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'title', label: 'Title'),
    BeakIntColumn(key: 'pages', label: 'Pages'),
    BeakStringColumn(key: 'parent_id', label: 'Parent'),
  ];

  @override
  List<BeakRelationship> get relationships => [
    BeakBelongsTo(
      key: 'parent',
      label: 'Parent',
      relatedTable: parentTable,
      displayColumnKey: 'name',
      foreignKey: 'parent_id',
    ),
  ];
}

void main() {
  late bool reachable;
  late DatabaseAdapter adapter;
  late WormDataSource source;
  late String parents;
  late String children;

  setUpAll(() async {
    reachable = await postgresIsReachable();
  });

  setUp(() async {
    if (!reachable) return;
    final suffix = Random().nextInt(1 << 30).toRadixString(36);
    parents = 'wr_parents_$suffix';
    children = 'wr_children_$suffix';
    adapter = adapterFromUrl(databaseUrl);
    await adapter.connect();
    await adapter.rawExecute(
      'CREATE TABLE $parents (id text PRIMARY KEY, name varchar(5))',
      const [],
    );
    await adapter.rawExecute(
      'CREATE TABLE $children ('
      'id text PRIMARY KEY, '
      'title text NOT NULL, '
      'pages integer CHECK (pages > 0), '
      'parent_id text REFERENCES $parents (id))',
      const [],
    );
    final registry = BeakModelRegistry()
      ..register(_ParentModel(parents))
      ..register(_ChildModel(children, parents));
    source = WormDataSource(registry, adapter: adapter);
    await source.create(
      parents,
      BeakRecord.fromRow({'id': 'p1', 'name': 'Poems'}),
    );
    await source.create(
      children,
      BeakRecord.fromRow({
        'id': 'c1',
        'title': 'Odes',
        'pages': 12,
        'parent_id': 'p1',
      }),
    );
  });

  tearDown(() async {
    if (!reachable) return;
    await adapter.rawExecute('DROP TABLE IF EXISTS $children', const []);
    await adapter.rawExecute('DROP TABLE IF EXISTS $parents', const []);
    await adapter.disconnect();
  });

  /// Runs [body], or skips the test when Postgres is down; the phase gate
  /// runs with services up.
  Future<void> guarded(Future<void> Function() body) async {
    if (!reachable) {
      markTestSkipped(
        'Postgres is unreachable at ${databaseUrl.host}:${databaseUrl.port}.',
      );
      return;
    }
    await body();
  }

  test('a string longer than its varchar is a 422', () {
    return guarded(() async {
      await expectLater(
        () => source.create(
          parents,
          BeakRecord.fromRow({'id': 'p2', 'name': 'far too long'}),
        ),
        throwsA(
          isA<BeakValidationException>().having(
            (e) => e.message,
            'message',
            contains('too long'),
          ),
        ),
      );
    });
  });

  test('an integer outside the column range is a 422 on write', () {
    return guarded(() async {
      await expectLater(
        () => source.update(
          children,
          'c1',
          BeakRecord.fromRow({'pages': 9999999999}),
        ),
        throwsA(isA<BeakValidationException>()),
      );
    });
  });

  test('and the same integer in a filter is a 422 on read', () {
    return guarded(() async {
      final spec = BeakQuerySpec(
        table: children,
        filter: const BeakFieldFilter.forKey(
          'pages',
          BeakOperator.eq,
          BeakIntValue(9999999999),
        ),
      );
      await expectLater(
        () => source.query(spec),
        throwsA(isA<BeakValidationException>()),
      );
    });
  });

  test('a row pointing at no parent is a 422', () {
    return guarded(() async {
      await expectLater(
        () => source.create(
          children,
          BeakRecord.fromRow({
            'id': 'c2',
            'title': 'Ghost',
            'pages': 1,
            'parent_id': 'nope',
          }),
        ),
        throwsA(
          isA<BeakValidationException>().having(
            (e) => e.message,
            'message',
            contains('does not exist'),
          ),
        ),
      );
    });
  });

  test('deleting a parent that still has a child is a 409', () {
    return guarded(() async {
      await expectLater(
        () => source.delete(parents, 'p1', force: true),
        throwsA(isA<BeakConflictException>()),
      );
    });
  });

  test('a CHECK the row breaks is a 422', () {
    return guarded(() async {
      await expectLater(
        () => source.update(children, 'c1', BeakRecord.fromRow({'pages': 0})),
        throwsA(isA<BeakValidationException>()),
      );
    });
  });

  test('a missing NOT NULL value is a 422 naming the column', () {
    return guarded(() async {
      await expectLater(
        () => source.create(
          children,
          BeakRecord.fromRow({'id': 'c3', 'title': null, 'pages': 1}),
        ),
        throwsA(
          isA<BeakValidationException>().having(
            (e) => e.fieldErrors.keys,
            'fields',
            ['title'],
          ),
        ),
      );
    });
  });
}
