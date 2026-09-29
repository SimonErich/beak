import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import 'beak_record_factory.dart';
import 'data_source_contract_types.dart';

/// How many owner rows, and how many related rows, every fixture seeds.
const int _rowCount = 3;

/// Related row indexes by owner row index, for each kind of relationship.
///
/// Every layout holds an owner with nothing related (belongs-to aside, whose
/// foreign key always points somewhere), and the many-to-many layout shares a
/// related row between two owners, so a detach that reaches past its own
/// parent shows.
Map<int, List<int>> _layoutFor(BeakRelationship relation) => switch (relation) {
  BeakBelongsTo() => const {
    0: [0],
    1: [1],
    2: [0],
  },
  BeakHasOne() => const {
    0: [0],
    1: [1],
    2: [],
  },
  BeakHasMany() => const {
    0: [0, 1],
    1: [2],
    2: [],
  },
  BeakBelongsToMany() => const {
    0: [0, 1],
    1: [1, 2],
    2: [],
  },
};

/// The name the tests give a kind of relationship.
String _kindOf(BeakRelationship relation) => switch (relation) {
  BeakBelongsTo() => 'belongs to',
  BeakHasOne() => 'has one',
  BeakHasMany() => 'has many',
  BeakBelongsToMany() => 'belongs to many',
};

/// The id of row [index] of [model], stable across tests.
String _idOf(BeakModel model, int index) => '${model.table}-${index + 1}';

/// A filter admitting only row [index] of [model].
BeakFilter _onlyRow(BeakModel model, int index) => BeakFieldFilter(
  column: model.primaryKey,
  operator: BeakOperator.eq,
  value: BeakValue.of(_idOf(model, index)),
);

/// One relationship on one owner model, with the rows that wire it.
final class _Edge {
  _Edge(this.owner, this.relation, BeakModelRegistry registry)
    : related = registry.byTableOrThrow(relation.relatedTable),
      links = _layoutFor(relation);

  final BeakModel owner;
  final BeakRelationship relation;
  final BeakModel related;

  /// Related row indexes by owner row index.
  final Map<int, List<int>> links;

  String get key => relation.key;

  String ownerId(int index) => _idOf(owner, index);

  String relatedId(int index) => _idOf(related, index);

  /// The ids linked to owner row [ownerIndex] under the layout [wired], sorted.
  List<String> idsOf(Map<int, List<int>> wired, int ownerIndex) =>
      [for (final index in wired[ownerIndex] ?? const <int>[]) relatedId(index)]
        ..sort();

  /// Every owner's linked ids as the seeded layout defines them, with
  /// [changes] replacing whole owners.
  Map<String, List<String>> expected([Map<int, List<int>> changes = const {}]) {
    final wired = {...links, ...changes};
    return {
      for (final index in wired.keys) ownerId(index): idsOf(wired, index),
    };
  }
}

/// The rows of one table a fixture seeds, before the factory builds them.
final class _Table {
  _Table(this.model)
    : overrides = [
        for (var index = 0; index < _rowCount; index++)
          {model.primaryKey.key: BeakValue.of(_idOf(model, index))},
      ];

  final BeakModel model;

  /// Column overrides per row: the primary key, plus any foreign key a
  /// relationship wires.
  final List<Map<String, BeakValue>> overrides;
}

/// Rows across the tables of some [edges], wired along each edge's layout.
final class _Fixture {
  _Fixture(this.edges);

  final List<_Edge> edges;

  /// Seeds the fixture into [source].
  ///
  /// Foreign keys travel inside the seeded records, so belongs-to, has-one
  /// and has-many wiring needs nothing beyond [seed]. Many-to-many links go
  /// through [seedLinks] when there is one, and through the source's own
  /// `attach` when there is not.
  Future<void> seedInto(
    BeakDataSource source, {
    required BeakDataSourceSeeder seed,
    BeakDataSourceLinkSeeder? seedLinks,
  }) async {
    final tables = <String, _Table>{};
    final pivots = <(BeakBelongsToMany, _Edge)>[];
    for (final edge in edges) {
      final _Table owner = tables.putIfAbsent(
        edge.owner.table,
        () => _Table(edge.owner),
      );
      final _Table related = tables.putIfAbsent(
        edge.related.table,
        () => _Table(edge.related),
      );
      switch (edge.relation) {
        case BeakBelongsTo(:final foreignKey):
          for (final MapEntry(key: ownerIndex, value: relatedIndexes)
              in edge.links.entries) {
            for (final relatedIndex in relatedIndexes) {
              owner.overrides[ownerIndex][foreignKey] = BeakValue.of(
                edge.relatedId(relatedIndex),
              );
            }
          }
        case BeakHasOne(:final foreignKey) || BeakHasMany(:final foreignKey):
          for (final MapEntry(key: ownerIndex, value: relatedIndexes)
              in edge.links.entries) {
            for (final relatedIndex in relatedIndexes) {
              related.overrides[relatedIndex][foreignKey] = BeakValue.of(
                edge.ownerId(ownerIndex),
              );
            }
          }
        case final BeakBelongsToMany pivot:
          pivots.add((pivot, edge));
      }
    }

    final factory = BeakRecordFactory();
    for (final table in tables.values) {
      await seed(source, table.model, [
        for (final overrides in table.overrides)
          factory.build(table.model, overrides: overrides),
      ]);
    }

    for (final (pivot, edge) in pivots) {
      for (final MapEntry(key: ownerIndex, value: relatedIndexes)
          in edge.links.entries) {
        final relatedIds = <Object>[
          for (final index in relatedIndexes) edge.relatedId(index),
        ];
        if (relatedIds.isEmpty) {
          continue;
        }
        if (seedLinks != null) {
          await seedLinks(source, pivot, edge.ownerId(ownerIndex), relatedIds);
        } else {
          await source.attach(
            edge.owner.table,
            edge.ownerId(ownerIndex),
            edge.key,
            relatedIds,
          );
        }
      }
    }
  }
}

/// The source under test and how to fill it, shared by the relation tests.
final class _Harness {
  _Harness({required this.create, required this.seed, this.seedLinks});

  final BeakDataSourceBuilder create;
  final BeakDataSourceSeeder seed;
  final BeakDataSourceLinkSeeder? seedLinks;

  late BeakDataSource source;

  Future<void> reset() async => source = await create();

  Future<void> given(_Fixture fixture) =>
      fixture.seedInto(source, seed: seed, seedLinks: seedLinks);

  /// Attaches related rows [relatedIndexes] to owner row [ownerIndex].
  Future<void> attach(_Edge edge, int ownerIndex, List<int> relatedIndexes) =>
      source.attach(edge.owner.table, edge.ownerId(ownerIndex), edge.key, [
        for (final index in relatedIndexes) edge.relatedId(index),
      ]);

  /// Detaches related rows [relatedIndexes] from owner row [ownerIndex].
  Future<void> detach(_Edge edge, int ownerIndex, List<int> relatedIndexes) =>
      source.detach(edge.owner.table, edge.ownerId(ownerIndex), edge.key, [
        for (final index in relatedIndexes) edge.relatedId(index),
      ]);

  /// Each owner's related ids as a load of [edge] returns them, sorted.
  Future<Map<String, List<String>>> loadedIds(
    _Edge edge, {
    BeakFilter? constraint,
  }) async {
    final page = await source.query(
      edge.owner.query().withRelation(edge.relation, constraint: constraint),
    );
    return {
      for (final record in page.items)
        '${edge.owner.primaryKeyOf(record)}': [
          for (final child
              in record.relations[edge.key] ?? const <BeakRecord>[])
            '${edge.related.primaryKeyOf(child)}',
        ]..sort(),
    };
  }

  /// Each owner's related ids, and each related row's own, for a load of
  /// [first] with [second] nested inside it.
  Future<Map<String, Map<String, List<String>>>> loadedNested(
    _Edge first,
    _Edge second, {
    BeakFilter? outer,
    BeakFilter? inner,
  }) async {
    final page = await source.query(
      first.owner.query(
        relationLoads: [
          BeakRelationLoad(
            first.key,
            filter: outer,
            nested: [BeakRelationLoad(second.key, filter: inner)],
          ),
        ],
      ),
    );
    return {
      for (final record in page.items)
        '${first.owner.primaryKeyOf(record)}': {
          for (final child
              in record.relations[first.key] ?? const <BeakRecord>[])
            '${first.related.primaryKeyOf(child)}': [
              for (final grandchild
                  in child.relations[second.key] ?? const <BeakRecord>[])
                '${second.related.primaryKeyOf(grandchild)}',
            ]..sort(),
        },
    };
  }
}

/// Defines the relation groups of the `BeakDataSource` contract.
///
/// One group per relationship of every model in [owners] that points at
/// another table: eager loads (plain, filtered, soft-deleted rows), and for a
/// to-many relationship `attach` and `detach`. Where an owner's related model
/// has a relationship of its own to a third table, a nested-load group as
/// well. The rows come from a [BeakRecordFactory], with primary keys and the
/// foreign keys that wire the relationship set by the fixture, so no test
/// depends on the store assigning anything.
///
/// A relationship from a table to itself is skipped: its rows would have to
/// be owner and related at once.
void defineBeakRelationContract(
  String description, {
  required BeakModelRegistry registry,
  required List<BeakModel> owners,
  required BeakDataSourceBuilder create,
  required BeakDataSourceSeeder seed,
  BeakDataSourceLinkSeeder? seedLinks,
}) {
  final edgesByOwner = <BeakModel, List<_Edge>>{
    for (final owner in owners)
      owner: [
        for (final relation in owner.relationships)
          if (relation.relatedTable != owner.table)
            _Edge(owner, relation, registry),
      ],
  };
  if (edgesByOwner.values.every((edges) => edges.isEmpty)) {
    throw ArgumentError(
      'None of ${owners.map((model) => model.table).join(', ')} has a '
      'relationship to another table; pass relationModels that do.',
    );
  }

  group('$description satisfies the BeakDataSource relation contract', () {
    final harness = _Harness(create: create, seed: seed, seedLinks: seedLinks);
    setUp(harness.reset);

    for (final MapEntry(key: owner, value: edges) in edgesByOwner.entries) {
      if (edges.isEmpty) {
        continue;
      }
      group('${owner.table} relations', () {
        _defineUnknownRelationTests(harness, edges.first);
        for (final edge in edges) {
          _defineEdgeTests(harness, edge);
          final _Edge? second = _secondHopOf(edge, registry);
          if (second != null) {
            _defineNestedTests(harness, edge, second);
          }
        }
      });
    }
  });
}

/// The first relationship of [first]'s related model that reaches a third
/// table, or `null` when there is none.
_Edge? _secondHopOf(_Edge first, BeakModelRegistry registry) {
  for (final relation in first.related.relationships) {
    if (relation.relatedTable != first.owner.table &&
        relation.relatedTable != first.related.table) {
      return _Edge(first.related, relation, registry);
    }
  }
  return null;
}

void _defineUnknownRelationTests(_Harness harness, _Edge seeded) {
  group('an unknown relation', () {
    test('cannot be loaded, and says so with a typed error', () async {
      await harness.given(_Fixture([seeded]));
      expect(
        () => harness.source.query(
          seeded.owner.query(
            relationLoads: const [BeakRelationLoad('no_such_relation')],
          ),
        ),
        throwsA(isA<BeakException>()),
      );
    });

    test('cannot be attached or detached', () async {
      await harness.given(_Fixture([seeded]));
      expect(
        () => harness.source.attach(
          seeded.owner.table,
          seeded.ownerId(0),
          'no_such_relation',
          [seeded.relatedId(0)],
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => harness.source.detach(
          seeded.owner.table,
          seeded.ownerId(0),
          'no_such_relation',
          [seeded.relatedId(0)],
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });
}

void _defineEdgeTests(_Harness harness, _Edge edge) {
  group('${edge.key} (${_kindOf(edge.relation)})', () {
    _defineLoadTests(harness, edge);
    switch (edge.relation) {
      case BeakBelongsToMany():
        _definePivotTests(harness, edge);
      case BeakHasMany():
        _defineChildrenTests(harness, edge);
      case BeakBelongsTo() || BeakHasOne():
        _defineToOneTests(harness, edge);
    }
  });
}

void _defineLoadTests(_Harness harness, _Edge edge) {
  group('eager load', () {
    setUp(() => harness.given(_Fixture([edge])));

    test('gives every parent exactly its related rows', () async {
      final page = await harness.source.query(
        edge.owner.query().withRelation(edge.relation),
      );
      expect(
        page.items.every((record) => record.relations.containsKey(edge.key)),
        isTrue,
        reason: 'a loaded relation is present, empty or not',
      );
      expect(await harness.loadedIds(edge), edge.expected());
    });

    test('counts parents, not related rows', () async {
      final page = await harness.source.query(
        edge.owner.query().withRelation(edge.relation),
      );
      expect(page.items, hasLength(_rowCount));
      expect(page.total, _rowCount);
    });

    test('a query without a load carries no relations', () async {
      final page = await harness.source.query(edge.owner.query());
      expect(page.items, hasLength(_rowCount));
      expect(page.items.every((record) => record.relations.isEmpty), isTrue);
    });

    test('a filtered load keeps every parent and narrows the related '
        'rows', () async {
      final loaded = await harness.loadedIds(
        edge,
        constraint: _onlyRow(edge.related, 0),
      );
      expect(loaded, hasLength(_rowCount), reason: 'no parent is dropped');
      expect(loaded, {
        for (final MapEntry(:key, :value) in edge.expected().entries)
          key: value.where((id) => id == edge.relatedId(0)).toList(),
      });
    });

    if (edge.related.softDeletes) {
      test('a soft-deleted related row is not loaded', () async {
        await harness.source.delete(edge.related.table, edge.relatedId(0));
        expect(await harness.loadedIds(edge), {
          for (final MapEntry(:key, :value) in edge.expected().entries)
            key: value.where((id) => id != edge.relatedId(0)).toList(),
        });
      });
    }
  });
}

void _definePivotTests(_Harness harness, _Edge edge) {
  group('attach and detach', () {
    setUp(() => harness.given(_Fixture([edge])));

    test('attach links the rows and leaves other parents alone', () async {
      await harness.attach(edge, 2, [0, 2]);
      expect(
        await harness.loadedIds(edge),
        edge.expected({
          2: [0, 2],
        }),
      );
    });

    test('attaching a link that already exists is skipped, not '
        'duplicated', () async {
      await harness.attach(edge, 0, [1, 2]);
      expect(
        await harness.loadedIds(edge),
        edge.expected({
          0: [0, 1, 2],
        }),
      );
    });

    test('attaching nothing changes nothing', () async {
      await harness.attach(edge, 0, const []);
      expect(await harness.loadedIds(edge), edge.expected());
    });

    test('detach removes only the links it names, for its own parent '
        'only', () async {
      await harness.detach(edge, 0, [1]);
      expect(
        await harness.loadedIds(edge),
        edge.expected({
          0: [0],
        }),
        reason: 'parent 1 still holds the row parent 0 let go of',
      );
    });

    test('detaching a link that is not there does nothing', () async {
      await harness.detach(edge, 2, [0, 1]);
      await harness.detach(edge, 0, [2]);
      expect(await harness.loadedIds(edge), edge.expected());
    });

    test('detaching nothing changes nothing', () async {
      await harness.detach(edge, 0, const []);
      expect(await harness.loadedIds(edge), edge.expected());
    });

    test('a detached row still exists', () async {
      await harness.detach(edge, 0, [0]);
      expect(
        await harness.source.getOne(edge.related.table, edge.relatedId(0)),
        isNotNull,
        reason: 'detach unlinks; it does not delete',
      );
    });
  });
}

void _defineChildrenTests(_Harness harness, _Edge edge) {
  group('attach and detach', () {
    setUp(() => harness.given(_Fixture([edge])));

    test('attach moves the rows under the new parent', () async {
      await harness.attach(edge, 2, [2]);
      expect(
        await harness.loadedIds(edge),
        edge.expected({
          1: [],
          2: [2],
        }),
        reason: 'a has-many row has one parent, so it leaves the old one',
      );
    });

    test('attaching a row its parent already owns changes nothing', () async {
      await harness.attach(edge, 0, [0]);
      expect(await harness.loadedIds(edge), edge.expected());
    });

    test('attaching nothing changes nothing', () async {
      await harness.attach(edge, 0, const []);
      expect(await harness.loadedIds(edge), edge.expected());
    });

    test('detach clears the parent of the rows it names', () async {
      await harness.detach(edge, 0, [0]);
      expect(
        await harness.loadedIds(edge),
        edge.expected({
          0: [1],
        }),
      );
    });

    test('detach leaves a row that belongs to another parent alone', () async {
      await harness.detach(edge, 0, [2]);
      expect(await harness.loadedIds(edge), edge.expected());
    });

    test('detaching nothing changes nothing', () async {
      await harness.detach(edge, 0, const []);
      expect(await harness.loadedIds(edge), edge.expected());
    });

    test('a detached row still exists', () async {
      await harness.detach(edge, 0, [0]);
      expect(
        await harness.source.getOne(edge.related.table, edge.relatedId(0)),
        isNotNull,
        reason: 'detach clears the foreign key; it does not delete',
      );
    });
  });
}

void _defineToOneTests(_Harness harness, _Edge edge) {
  test('attach and detach reject a relation that is not to-many', () async {
    await harness.given(_Fixture([edge]));
    expect(
      () => harness.source.attach(edge.owner.table, edge.ownerId(0), edge.key, [
        edge.relatedId(0),
      ]),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      () => harness.source.detach(edge.owner.table, edge.ownerId(0), edge.key, [
        edge.relatedId(0),
      ]),
      throwsA(isA<BeakConfigurationException>()),
    );
  });
}

void _defineNestedTests(_Harness harness, _Edge first, _Edge second) {
  group('${first.key} then ${second.key} (nested load)', () {
    late _Fixture fixture;

    setUp(() async {
      fixture = _Fixture([first, second]);
      await harness.given(fixture);
    });

    /// [first]'s related ids per owner, each with [second]'s under it, for
    /// the rows [outer] and [inner] admit.
    Map<String, Map<String, List<String>>> expected({
      bool Function(int index)? outer,
      bool Function(int index)? inner,
    }) => {
      for (final ownerIndex in first.links.keys)
        first.ownerId(ownerIndex): {
          for (final middle in first.links[ownerIndex]!)
            if (outer?.call(middle) ?? true)
              first.relatedId(middle): [
                for (final leaf in second.links[middle] ?? const <int>[])
                  if (inner?.call(leaf) ?? true) second.relatedId(leaf),
              ]..sort(),
        },
    };

    test('loads the second level under each first-level row', () async {
      expect(await harness.loadedNested(first, second), expected());
    });

    test('a filter on the second level narrows only that level', () async {
      expect(
        await harness.loadedNested(
          first,
          second,
          inner: _onlyRow(second.related, 0),
        ),
        expected(inner: (index) => index == 0),
      );
    });

    test('a filter on the first level still loads the second', () async {
      expect(
        await harness.loadedNested(
          first,
          second,
          outer: _onlyRow(first.related, 0),
        ),
        expected(outer: (index) => index == 0),
      );
    });
  });
}
