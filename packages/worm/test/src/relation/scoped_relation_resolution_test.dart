import 'package:test/test.dart';
import 'package:worm/worm.dart';

/// Generic row-backed model so one fixture serves every table.
final class _Row extends Model {
  _Row(this._values);

  final Map<String, Object?> _values;

  @override
  Object get id => _values['id'] ?? 0;

  @override
  Map<String, Object?> toRow() => Map<String, Object?>.of(_values);
}

_Row _hydrate(Map<String, Object?> row) => _Row(Map<String, Object?>.of(row));

Future<InMemoryAdapter> _seededAdapter(
  Map<String, List<Map<String, Object?>>> tables,
) async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  for (final entry in tables.entries) {
    await adapter.executeSchema(SchemaDescriptor.createTable(table: entry.key));
    await adapter.insertMany(
      InsertManyDescriptor(table: entry.key, rows: entry.value),
    );
  }
  return adapter;
}

List<_Row> _many(Model model, String key) => switch (model.relations[key]) {
  final List<Object?> items => <_Row>[
    for (final item in items)
      if (item is _Row) item,
  ],
  _ => const <_Row>[],
};

_Row? _one(Model model, String key) => switch (model.relations[key]) {
  final _Row row => row,
  _ => null,
};

Object? _idOf(_Row row) => row.toRow()['id'];

void main() {
  group('self-referential relations', () {
    const children = HasManyRelation<Model, Model>(
      name: 'children',
      childTable: 'folders',
      foreignKey: 'parent_id',
      hydrateChild: _hydrate,
    );
    const parent = BelongsToRelation<Model, Model>(
      name: 'parent',
      parentTable: 'folders',
      foreignKey: 'parent_id',
      hydrateParent: _hydrate,
    );

    Future<QueryContext<_Row>> folderContext() async {
      final adapter = await _seededAdapter({
        'folders': [
          {'id': 1, 'name': 'root', 'parent_id': null},
          {'id': 2, 'name': 'docs', 'parent_id': 1},
          {'id': 3, 'name': 'media', 'parent_id': 1},
          {'id': 4, 'name': 'invoices', 'parent_id': 2},
        ],
      });
      return QueryContext<_Row>(
        adapter: adapter,
        table: 'folders',
        hydrate: _hydrate,
        relations: const {'children': children, 'parent': parent},
      );
    }

    test('loads a self-referential has-many two levels deep', () async {
      final context = await folderContext();
      final roots = await QueryBuilder<_Row>.from(context)
          .where(const Field<Object?>('id').eq(1))
          .withRelationPaths(const ['children.children'])
          .get();

      final root = roots.single;
      final level1 = _many(root, 'children');
      expect(level1.map(_idOf), unorderedEquals(<Object>[2, 3]));

      final docs = level1.singleWhere((row) => _idOf(row) == 2);
      final media = level1.singleWhere((row) => _idOf(row) == 3);
      expect(_many(docs, 'children').map(_idOf), [4]);
      expect(_many(media, 'children'), isEmpty);
    });

    test('loads a self-referential belongs-to', () async {
      final context = await folderContext();
      final rows = await QueryBuilder<_Row>.from(context)
          .where(const Field<Object?>('id').inList(const [1, 4]))
          .withRelationPaths(const ['parent'])
          .get();

      final byId = {for (final row in rows) _idOf(row): row};
      final grandchildParent = _one(byId[4]!, 'parent');
      expect(grandchildParent?.toRow()['id'], 2);
      expect(_one(byId[1]!, 'parent'), isNull);
    });
  });

  group('table-scoped nested resolution', () {
    const items = HasManyRelation<Model, Model>(
      name: 'items',
      childTable: 'betas',
      foreignKey: 'alpha_id',
      hydrateChild: _hydrate,
    );
    const alphaParent = BelongsToRelation<Model, Model>(
      name: 'parent',
      parentTable: 'alphas',
      foreignKey: 'parent_id',
      hydrateParent: _hydrate,
    );
    const betaParent = BelongsToRelation<Model, Model>(
      name: 'parent',
      parentTable: 'betas',
      foreignKey: 'parent_id',
      hydrateParent: _hydrate,
    );

    Future<InMemoryAdapter> ambiguousAdapter() => _seededAdapter({
      // Both tables hold a row with id 20 so a wrong-table lookup would
      // still find data — the label proves which table served the load.
      'alphas': [
        {'id': 1, 'label': 'root', 'parent_id': null},
        {'id': 20, 'label': 'wrong-table', 'parent_id': null},
      ],
      'betas': [
        {'id': 10, 'label': 'item', 'alpha_id': 1, 'parent_id': 20},
        {'id': 20, 'label': 'right-table', 'alpha_id': null, 'parent_id': null},
      ],
    });

    test('a nested segment resolves against the loaded side table', () async {
      final context = QueryContext<_Row>(
        adapter: await ambiguousAdapter(),
        table: 'alphas',
        hydrate: _hydrate,
        // Flat map simulates first-wins registration: the root table's
        // same-named relation shadows the child table's.
        relations: const {'items': items, 'parent': alphaParent},
        relationsByTable: const {
          'alphas': {'items': items, 'parent': alphaParent},
          'betas': {'parent': betaParent},
        },
      );

      final roots = await QueryBuilder<_Row>.from(context)
          .where(const Field<Object?>('id').eq(1))
          .withRelationPaths(const ['items.parent'])
          .get();

      final item = _many(roots.single, 'items').single;
      final loadedParent = _one(item, 'parent');
      expect(loadedParent, isNotNull);
      expect(loadedParent?.toRow()['label'], 'right-table');
    });

    test('falls back to the flat map without a scoped entry', () async {
      final context = QueryContext<_Row>(
        adapter: await ambiguousAdapter(),
        table: 'alphas',
        hydrate: _hydrate,
        relations: const {'items': items, 'parent': alphaParent},
        // No entry for 'betas': the nested segment falls back to the
        // flat map, preserving pre-scoping behavior.
        relationsByTable: const {
          'alphas': {'items': items, 'parent': alphaParent},
        },
      );

      final roots = await QueryBuilder<_Row>.from(context)
          .where(const Field<Object?>('id').eq(1))
          .withRelationPaths(const ['items.parent'])
          .get();

      final item = _many(roots.single, 'items').single;
      expect(_one(item, 'parent')?.toRow()['label'], 'wrong-table');
    });

    test('the root level prefers the root table scope', () async {
      final context = QueryContext<_Row>(
        adapter: await ambiguousAdapter(),
        table: 'alphas',
        hydrate: _hydrate,
        relations: const {},
        relationsByTable: const {
          'alphas': {'items': items},
        },
      );

      final roots = await QueryBuilder<_Row>.from(context)
          .where(const Field<Object?>('id').eq(1))
          .withRelationPaths(const ['items'])
          .get();

      expect(_many(roots.single, 'items').map(_idOf), [10]);
    });

    test('an unknown relation still throws', () async {
      final context = QueryContext<_Row>(
        adapter: await ambiguousAdapter(),
        table: 'alphas',
        hydrate: _hydrate,
        relations: const {'items': items},
      );

      await expectLater(
        QueryBuilder<_Row>.from(
          context,
        ).withRelationPaths(const ['missing']).get(),
        throwsA(isA<ConfigurationException>()),
      );
    });
  });
}
