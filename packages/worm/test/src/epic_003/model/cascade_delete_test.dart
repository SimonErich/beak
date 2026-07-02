/// Tests for `OnDelete.ormCascade` runtime semantics: deleting a
/// parent with `ormCascadeSpecs` walks every child through the ORM
/// (firing `beforeDelete` / `afterDelete`) before the parent row is
/// deleted from the database; parents without cascade specs delete
/// without regression.
library;

import 'package:test/test.dart';
import 'package:worm/worm.dart';

/// Per-test recorder so models can stamp their hook order without
/// pulling in the observer machinery.
final List<String> _hookLog = <String>[];

final class _CascadeParent extends Model {
  _CascadeParent({required this.parentId});

  final int parentId;

  @override
  Object get id => parentId;

  @override
  String? get tableName => 'cascade_parents';

  @override
  bool get usesTimestamps => false;

  @override
  Map<String, Object?> toRow() => <String, Object?>{'id': parentId};

  @override
  Future<bool> beforeDelete() async {
    _hookLog.add('parent.beforeDelete($parentId)');
    return true;
  }

  @override
  Future<void> afterDelete() async {
    _hookLog.add('parent.afterDelete($parentId)');
  }

  @override
  List<OrmCascadeSpec> get ormCascadeSpecs => <OrmCascadeSpec>[
    const OrmCascadeSpec(
      childTable: 'cascade_children',
      foreignKey: 'parent_id',
      hydrate: _CascadeChild.fromRow,
    ),
  ];
}

final class _CascadeChild extends Model {
  _CascadeChild({required this.childId, required this.parentId});

  factory _CascadeChild.fromRow(Map<String, Object?> row) {
    final id = row['id'];
    final pid = row['parent_id'];
    return _CascadeChild(
      childId: id is int ? id : 0,
      parentId: pid is int ? pid : 0,
    );
  }

  final int childId;
  final int parentId;

  @override
  Object get id => childId;

  @override
  String? get tableName => 'cascade_children';

  @override
  bool get usesTimestamps => false;

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': childId,
    'parent_id': parentId,
  };

  @override
  Future<bool> beforeDelete() async {
    _hookLog.add('child.beforeDelete($childId)');
    return true;
  }

  @override
  Future<void> afterDelete() async {
    _hookLog.add('child.afterDelete($childId)');
  }
}

/// Parent without `ormCascadeSpecs` — the no-cascade regression
/// guard: deleting one of these must not load any child rows or
/// fire any non-parent hook.
final class _PlainParent extends Model {
  _PlainParent({required this.plainId});

  final int plainId;

  @override
  Object get id => plainId;

  @override
  String? get tableName => 'plain_parents';

  @override
  bool get usesTimestamps => false;

  @override
  Map<String, Object?> toRow() => <String, Object?>{'id': plainId};

  @override
  Future<bool> beforeDelete() async {
    _hookLog.add('plain.beforeDelete($plainId)');
    return true;
  }

  @override
  Future<void> afterDelete() async {
    _hookLog.add('plain.afterDelete($plainId)');
  }
}

/// Holder for the [HasMany] annotation compile-check — only its
/// metadata is inspected, never instantiated as a Worm model.
@HasMany(_CascadeChild, foreignKey: 'parent_id', onDelete: OnDelete.ormCascade)
final class _AnnotatedParent {
  const _AnnotatedParent();
}

String _onDeleteLabel(OnDelete value) {
  switch (value) {
    case OnDelete.cascade:
      return 'cascade';
    case OnDelete.ormCascade:
      return 'ormCascade';
    case OnDelete.restrict:
      return 'restrict';
    case OnDelete.setNull:
      return 'setNull';
    case OnDelete.setDefault:
      return 'setDefault';
    case OnDelete.noAction:
      return 'noAction';
  }
}

void main() {
  late InMemoryAdapter adapter;

  setUp(() async {
    _hookLog.clear();
    adapter = InMemoryAdapter();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'cascade_parents'),
    );
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'cascade_children'),
    );
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'plain_parents'),
    );
    await adapter.insert(
      const InsertDescriptor(
        table: 'cascade_parents',
        values: <String, Object?>{'id': 1},
      ),
    );
    await adapter.insertMany(
      const InsertManyDescriptor(
        table: 'cascade_children',
        rows: <Map<String, Object?>>[
          <String, Object?>{'id': 10, 'parent_id': 1},
          <String, Object?>{'id': 11, 'parent_id': 1},
          <String, Object?>{'id': 99, 'parent_id': 2},
        ],
      ),
    );
    await adapter.insert(
      const InsertDescriptor(
        table: 'plain_parents',
        values: <String, Object?>{'id': 7},
      ),
    );
    await Worm.initialize(
      config: const WormConfig(),
      adapters: <String, InMemoryAdapter>{'default': adapter},
    );
  });

  tearDown(Worm.reset);

  group('OnDelete enum', () {
    test('OnDelete.ormCascade is a valid enum value', () {
      const value = OnDelete.ormCascade;
      expect(OnDelete.values, contains(value));
      // Exhaustive switch — proves the enum case compiles without
      // an `@unreachable` default branch.
      expect(_onDeleteLabel(value), 'ormCascade');
    });
  });

  group('OnDelete.ormCascade runtime cascade', () {
    test(
      'fires beforeDelete and afterDelete on each child in sequence, '
      'sandwiched between parent.beforeDelete and parent.afterDelete',
      () async {
        final parent = _CascadeParent(parentId: 1)..markPersisted();
        final ok = await parent.delete();
        expect(ok, isTrue);

        expect(_hookLog.first, 'parent.beforeDelete(1)');
        expect(_hookLog.last, 'parent.afterDelete(1)');
        expect(
          _hookLog,
          containsAllInOrder(<String>[
            'parent.beforeDelete(1)',
            'child.beforeDelete(10)',
            'child.afterDelete(10)',
            'child.beforeDelete(11)',
            'child.afterDelete(11)',
            'parent.afterDelete(1)',
          ]),
        );
      },
    );

    test('children are absent from the DB after parent.delete()', () async {
      final parent = _CascadeParent(parentId: 1)..markPersisted();
      await parent.delete();

      final remainingChildren = await adapter.select(
        const QueryDescriptor(table: 'cascade_children'),
      );
      expect(remainingChildren, hasLength(1));
      // The orphan child of parent 2 stays — only parent 1's
      // dependents are removed.
      expect(remainingChildren.single['id'], 99);

      final remainingParents = await adapter.select(
        const QueryDescriptor(table: 'cascade_parents'),
      );
      expect(remainingParents, isEmpty);
    });

    test('parent with empty ormCascadeSpecs deletes without firing child '
        'hooks (no regression)', () async {
      final plain = _PlainParent(plainId: 7)..markPersisted();
      final ok = await plain.delete();
      expect(ok, isTrue);

      // The plain parent fires its own hooks but no others — the
      // cascade walker must be a no-op when ormCascadeSpecs is
      // empty.
      expect(_hookLog, <String>[
        'plain.beforeDelete(7)',
        'plain.afterDelete(7)',
      ]);

      final survivors = await adapter.select(
        const QueryDescriptor(table: 'plain_parents'),
      );
      expect(survivors, isEmpty);
    });
  });

  group('HasMany onDelete annotation', () {
    test('accepts onDelete: OnDelete.ormCascade', () {
      // Reading the const-instance back proves the named parameter
      // is wired through the annotation's constructor without a
      // compile-time error.
      const annotation = HasMany(
        _CascadeChild,
        foreignKey: 'parent_id',
        onDelete: OnDelete.ormCascade,
      );
      expect(annotation.onDelete, OnDelete.ormCascade);
      expect(annotation.foreignKey, 'parent_id');
      expect(annotation.related, _CascadeChild);

      // Also exercise it through a real annotation on a class — if
      // the field weren't accepted the file would not compile.
      const usage = _AnnotatedParent();
      expect(usage, isA<_AnnotatedParent>());
    });
  });
}
