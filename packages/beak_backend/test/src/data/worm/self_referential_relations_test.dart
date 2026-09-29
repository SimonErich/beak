import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

/// Folders form a tree on their own table — the shape file managers and
/// threaded comments share.
final class _FolderModel extends BeakModel {
  const _FolderModel();

  @override
  String get table => 'folders';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakIntColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
    BeakIntColumn(key: 'parent_id', label: 'Parent'),
    BeakIntColumn(key: 'hub_id', label: 'Hub'),
  ];

  @override
  List<BeakRelationship> get relationships => const [
    BeakBelongsTo(
      key: 'parent',
      label: 'Parent',
      relatedTable: 'folders',
      displayColumnKey: 'name',
      foreignKey: 'parent_id',
    ),
    BeakHasMany(
      key: 'children',
      label: 'Children',
      relatedTable: 'folders',
      displayColumnKey: 'name',
      foreignKey: 'parent_id',
    ),
  ];
}

/// Activities also self-reference under the SAME relation key (`parent`)
/// as folders — the ambiguity the scoped eager loader must untangle.
final class _ActivityModel extends BeakModel {
  const _ActivityModel();

  @override
  String get table => 'activities';

  @override
  String get displayColumnKey => 'body';

  @override
  List<BeakColumn> get columns => const [
    BeakIntColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'body', label: 'Body'),
    BeakIntColumn(key: 'parent_id', label: 'Parent'),
    BeakIntColumn(key: 'hub_id', label: 'Hub'),
  ];

  @override
  List<BeakRelationship> get relationships => const [
    BeakBelongsTo(
      key: 'parent',
      label: 'Parent',
      relatedTable: 'activities',
      displayColumnKey: 'body',
      foreignKey: 'parent_id',
    ),
    BeakHasMany(
      key: 'replies',
      label: 'Replies',
      relatedTable: 'activities',
      displayColumnKey: 'body',
      foreignKey: 'parent_id',
    ),
  ];
}

/// A hub reaches BOTH self-referential models; `folders` is declared first
/// so its `parent` wins the flat first-registered slot — the wrong relation
/// for `activities.parent` unless resolution is table-scoped.
final class _HubModel extends BeakModel {
  const _HubModel();

  @override
  String get table => 'hubs';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakIntColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];

  @override
  List<BeakRelationship> get relationships => const [
    BeakHasMany(
      key: 'folders',
      label: 'Folders',
      relatedTable: 'folders',
      displayColumnKey: 'name',
      foreignKey: 'hub_id',
    ),
    BeakHasMany(
      key: 'activities',
      label: 'Activities',
      relatedTable: 'activities',
      displayColumnKey: 'body',
      foreignKey: 'hub_id',
    ),
  ];
}

void main() {
  late InMemoryAdapter adapter;
  late WormDataSource dataSource;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    for (final table in const ['hubs', 'folders', 'activities']) {
      await adapter.executeSchema(SchemaDescriptor.createTable(table: table));
    }
    final registry = BeakModelRegistry()
      ..register(const _HubModel())
      ..register(const _FolderModel())
      ..register(const _ActivityModel());
    dataSource = WormDataSource(registry, adapter: adapter);
  });

  tearDown(Worm.reset);

  Future<void> insert(String table, Map<String, Object?> values) =>
      adapter.insert(InsertDescriptor(table: table, values: values));

  Future<void> seedTree() async {
    await insert('folders', {
      'id': 100,
      'name': 'root',
      'parent_id': null,
      'hub_id': 1,
    });
    await insert('folders', {
      'id': 101,
      'name': 'docs',
      'parent_id': 100,
      'hub_id': null,
    });
    await insert('folders', {
      'id': 102,
      'name': 'media',
      'parent_id': 100,
      'hub_id': null,
    });
    await insert('folders', {
      'id': 103,
      'name': 'invoices',
      'parent_id': 101,
      'hub_id': null,
    });
  }

  List<BeakRecord> related(BeakRecord record, String key) =>
      record.relations[key] ?? const [];

  Object? idOf(BeakRecord record) => record['id']?.raw;

  group('self-referential relations through the data source', () {
    test('eager-loads a folder tree two levels deep', () async {
      await seedTree();

      final page = await dataSource.query(
        const BeakQuerySpec(
          table: 'folders',
          relationLoads: [
            BeakRelationLoad(
              'children',
              nested: [BeakRelationLoad('children')],
            ),
          ],
        ),
      );

      final root = page.items.singleWhere((record) => idOf(record) == 100);
      final level1 = related(root, 'children');
      expect(level1.map(idOf), unorderedEquals(<Object>[101, 102]));

      final docs = level1.singleWhere((record) => idOf(record) == 101);
      final media = level1.singleWhere((record) => idOf(record) == 102);
      expect(related(docs, 'children').map(idOf), [103]);
      expect(related(media, 'children'), isEmpty);
    });

    test(
      'a filter reaching more than 16 relationships deep is a spec error',
      () async {
        final path = '${List.filled(20, 'parent').join('.')}.name';
        await expectLater(
          dataSource.query(
            BeakQuerySpec(
              table: 'folders',
              filter: BeakFieldFilter.forKey(
                path,
                BeakOperator.eq,
                const BeakStringValue('root'),
              ),
            ),
          ),
          throwsA(
            isA<BeakValidationException>().having(
              (error) => error.message,
              'message',
              contains('16 levels'),
            ),
          ),
        );
        await expectLater(
          dataSource.query(
            BeakQuerySpec(
              table: 'folders',
              filter: BeakFieldFilter.forKey(
                '${List.filled(3, 'parent').join('.')}.name',
                BeakOperator.eq,
                const BeakStringValue('root'),
              ),
            ),
          ),
          completes,
        );
      },
    );

    test('eager-loads the self-referential parent side', () async {
      await seedTree();

      final page = await dataSource.query(
        const BeakQuerySpec(
          table: 'folders',
          relationLoads: [BeakRelationLoad('parent')],
        ),
      );

      final invoices = page.items.singleWhere((record) => idOf(record) == 103);
      final root = page.items.singleWhere((record) => idOf(record) == 100);
      expect(related(invoices, 'parent').map(idOf), [101]);
      expect(related(root, 'parent'), isEmpty);
    });

    test('same-named relations on different tables never cross-wire', () async {
      await insert('hubs', {'id': 1, 'name': 'main'});
      // Decoys: BOTH tables hold a row with id 5, so a wrong-table lookup
      // would still find data — the payload proves which table served it.
      await insert('folders', {
        'id': 5,
        'name': 'decoy-folder',
        'parent_id': null,
        'hub_id': null,
      });
      await insert('activities', {
        'id': 5,
        'body': 'the real parent activity',
        'parent_id': null,
        'hub_id': null,
      });
      await insert('activities', {
        'id': 200,
        'body': 'a reply',
        'parent_id': 5,
        'hub_id': 1,
      });

      final page = await dataSource.query(
        const BeakQuerySpec(
          table: 'hubs',
          relationLoads: [
            BeakRelationLoad(
              'activities',
              nested: [BeakRelationLoad('parent')],
            ),
          ],
        ),
      );

      final hub = page.items.single;
      final activity = related(hub, 'activities').single;
      expect(idOf(activity), 200);

      final parent = related(activity, 'parent').single;
      expect(parent['body']?.raw, 'the real parent activity');
      expect(parent['name'], isNull, reason: 'must not be the folders row');
    });
  });
}
