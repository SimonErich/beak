import 'dart:async';
import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/panel_fixtures.dart';

const _name = BeakScalarField<String>(
  model: _Folder(),
  column: BeakStringColumn(key: 'name', label: 'Name'),
);
const _password = BeakScalarField<String>(
  model: _Folder(),
  column: BeakStringColumn(
    key: 'password',
    label: 'Password',
    semantic: BeakSemantic.password(),
  ),
);
const _image = BeakScalarField<String>(
  model: _Folder(),
  column: BeakImageColumn(key: 'image', label: 'Image', storagePath: 'images'),
);
const _childName = BeakScalarField<String>(
  model: _Child(),
  column: BeakStringColumn(key: 'name', label: 'Child name'),
);
const _children = BeakToManyField(
  model: _Folder(),
  target: _Child(),
  relation: BeakHasMany(
    key: 'children',
    label: 'Children',
    relatedTable: 'children',
    foreignKey: 'folder_id',
    displayColumnKey: 'name',
    owned: true,
  ),
);
BeakFormLayout _layout() => BeakFormLayout(
  children: [
    _name.input(),
    _password.input(),
    _image.input(),
    _children.tableForm(
      removeBehavior: BeakRemoveBehavior.deleteOwned,
      children: [_childName.input()],
    ),
  ],
);

void main() {
  test(
    'new related rows await shared create capabilities before validation',
    () async {
      final source = _CapabilitySource();
      final session = BeakFormSession(
        model: const _Folder(),
        dataSource: source,
        layout: _layout(),
      );
      addTearDown(session.dispose);
      await session.load();
      final row = session.root.addRow(
        _children,
        values: BeakRecord.fromRow({'name': 'Private'}),
      );
      expect(row.visible(row.layout.children.first), false);
      expect(row.validating, true);
      var validated = false;
      final validation = session.validate().then((value) {
        validated = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(validated, false);
      source.childCapabilities.complete(
        const BeakAccessCapabilities(
          readableFields: {'id', 'folder_id'},
          writableFields: {'folder_id'},
        ),
      );
      expect(await validation, true);
      expect(row.buildRecord().values, isEmpty);
      final second = session.root.addRow(_children);
      await second.validate();
      expect(second.visible(second.layout.children.first), false);
      expect(source.childrenRequests, 1);
    },
  );

  test(
    'interrupted saves survive reload frozen, recover nested identities, and never replay',
    () async {
      final store = BeakMemoryDraftStore();
      final config = BeakFormDrafts(
        store: store,
        key: 'folder',
        context: 'owner',
      );
      final source = _ReceiptSource(interrupted: true);
      BeakFormSession open(BeakFormDrafts drafts) => BeakFormSession(
        model: const _Folder(),
        dataSource: source,
        layout: _layout(),
        drafts: drafts,
      );
      final first = open(config);
      await first.load();
      first.root.set(_name, 'Unsaved name');
      first.root.set(_password, 'never-store-this');
      first.root.addRow(_children).set(_childName, 'Nested');
      final saving = first.save();
      await source.dispatched.future;
      final key = config.storageKey('folders', null);
      final document = (await store.read(key))!;
      expect(document, contains('pending'));
      expect(document, isNot(contains('never-store-this')));
      final stored = jsonDecode(document) as Map<String, dynamic>;
      final pending = stored['pending'] as Map<String, dynamic>;
      expect(pending['saveId'], source.plan!.saveId);
      expect(pending.containsKey('arguments'), false);
      first.dispose();

      // Receipt identities must not expire with ordinary drafts or a layout version.
      final resumed = open(
        BeakFormDrafts(
          store: store,
          key: 'folder',
          context: 'owner',
          schemaVersion: 2,
          retention: Duration.zero,
        ),
      );
      addTearDown(resumed.dispose);
      await resumed.load();
      expect(source.recoveries, [source.plan!.saveId]);
      expect(resumed.hasUnknown, true);
      expect(resumed.hasStoredDraft, false);
      expect(resumed.root.read(_name), 'Unsaved name');
      expect(resumed.root.rows(_children).single.read(_childName), 'Nested');
      resumed.root.set(_name, 'Must remain frozen');
      expect(resumed.root.read(_name), 'Unsaved name');
      await resumed.save();
      await resumed.discardStoredDraft();
      expect(source.commits, 1);
      expect(await store.read(key), isNotNull);

      source.recoveredStatus = BeakWriteOutcome.applied;
      await resumed.recover();
      expect(resumed.hasUnknown, false);
      expect(resumed.root.id, 'saved-folders');
      expect(resumed.root.rows(_children).single.id, 'saved-children');
      expect(resumed.isDirty, false);
      expect(await store.read(key), isNull);
      expect(source.commits, 1);
      source.completion.complete(source.receipt(BeakWriteOutcome.applied));
      await saving;
    },
  );

  test(
    'definite rejection retains a correctable durable graph after reload',
    () async {
      final store = BeakMemoryDraftStore();
      final config = BeakFormDrafts(
        store: store,
        key: 'folder',
        context: 'owner',
      );
      final source = _ReceiptSource(reject: true);
      BeakFormSession open() => BeakFormSession(
        model: const _Folder(),
        dataSource: source,
        layout: _layout(),
        drafts: config,
      );
      final first = open();
      await first.load();
      first.root.set(_name, 'Correctable');
      first.root.addRow(_children).set(_childName, 'Keep child');
      final result = await first.save();
      expect(result?.complete, false);
      expect(first.hasUnknown, false);
      final document = (await store.read(config.storageKey('folders', null)))!;
      expect(
        (jsonDecode(document) as Map<String, dynamic>).containsKey('pending'),
        false,
      );
      first.dispose();
      final resumed = open();
      addTearDown(resumed.dispose);
      await resumed.load();
      expect(resumed.hasStoredDraft, true);
      final beforeDecision = await store.read(
        config.storageKey('folders', null),
      );
      resumed.root.set(_name, 'New work before choosing recovery');
      expect(await resumed.persistDraft(), isFalse);
      expect(await resumed.save(), isNull);
      expect(
        await store.read(config.storageKey('folders', null)),
        beforeDecision,
      );
      resumed.resumeDraft();
      expect(resumed.root.read(_name), 'Correctable');
      expect(
        resumed.root.rows(_children).single.read(_childName),
        'Keep child',
      );
      resumed.root.set(_name, 'Corrected');
      expect(resumed.root.read(_name), 'Corrected');
      expect(source.recoveries, isEmpty);
    },
  );

  test(
    'a pending document storage failure prevents dispatch without losing edits',
    () async {
      final source = _ReceiptSource();
      final session = BeakFormSession(
        model: const _Folder(),
        dataSource: source,
        layout: _layout(),
        drafts: BeakFormDrafts(
          store: _BrokenStore(),
          key: 'folder',
          context: 'owner',
        ),
      );
      addTearDown(session.dispose);
      await session.load();
      session.root.set(_name, 'Retained in memory');
      expect(await session.save(), isNull);
      expect(source.commits, 0);
      expect(session.root.read(_name), 'Retained in memory');
      expect(session.hasUnknown, false);
    },
  );

  test(
    'nested edits, removals and new rows resume against current server state',
    () async {
      final store = BeakMemoryDraftStore();
      final config = BeakFormDrafts(
        store: store,
        key: 'folder',
        context: 'user',
      );
      final source = FakeDataSource(
        models: const [_Folder(), _Child()],
        records: {
          'folders': {
            'p': BeakRecord.fromRow({'id': 'p', 'name': 'Original'}),
          },
          'children': {
            'c1': BeakRecord.fromRow({
              'id': 'c1',
              'folder_id': 'p',
              'name': 'First',
            }),
            'c2': BeakRecord.fromRow({
              'id': 'c2',
              'folder_id': 'p',
              'name': 'Remove',
            }),
          },
        },
      );
      BeakFormSession create() => BeakFormSession(
        model: const _Folder(),
        dataSource: source,
        recordId: 'p',
        layout: _layout(),
        drafts: config,
      );
      final first = create();
      await first.load();
      final rows = first.root.rows(_children);
      rows.first.set(_childName, 'Changed');
      first.root.removeRow(rows.last);
      first.root.addRow(_children).set(_childName, 'Added');
      await first.persistDraft();
      first.dispose();
      await source.update(
        'folders',
        'p',
        BeakRecord.fromRow({'name': 'Remote title'}),
      );
      final resumed = create();
      addTearDown(resumed.dispose);
      await resumed.load();
      resumed.resumeDraft();
      expect(resumed.conflicts, isEmpty);
      expect(resumed.root.read(_name), 'Remote title');
      expect(resumed.root.rows(_children).map((r) => r.read(_childName)), [
        'Changed',
        'Added',
      ]);
      expect(
        resumed.reviewChanges.where(
          (c) => c.kind == BeakDraftChangeKind.delete,
        ),
        hasLength(1),
      );
      expect((await resumed.save())?.complete, true);
      final saved = await source.query(const _Child().query());
      expect(
        saved.items.map((r) => r['name']?.raw),
        unorderedEquals(['Changed', 'Added']),
      );
    },
  );
  test(
    'passwords and pending file references never reach durable storage',
    () async {
      final store = BeakMemoryDraftStore();
      final config = BeakFormDrafts(
        store: store,
        key: 'folder',
        context: 'user',
      );
      final source = FakeDataSource(models: const [_Folder(), _Child()]);
      final first = BeakFormSession(
        model: const _Folder(),
        dataSource: source,
        layout: _layout(),
        drafts: config,
      );
      await first.load();
      first.root.set(_name, 'Keep this');
      first.root.set(_password, 'secret-password');
      first.root.set(_image, 'beak-draft:private-bytes');
      await first.persistDraft();
      final document = await store.read(config.storageKey('folders', null));
      expect(document, isNot(contains('secret-password')));
      expect(document, isNot(contains('private-bytes')));
      first.dispose();
      final resumed = BeakFormSession(
        model: const _Folder(),
        dataSource: source,
        layout: _layout(),
        drafts: config,
      );
      addTearDown(resumed.dispose);
      await resumed.load();
      resumed.resumeDraft();
      expect(resumed.root.read(_name), 'Keep this');
      expect(resumed.root.read(_password), null);
      expect(resumed.root.read(_image), null);
      expect(
        resumed.draftNotice,
        contains('Select any uncommitted files again'),
      );
    },
  );
  test(
    'a remotely deleted edited child requires explicit recreate or discard',
    () async {
      final store = BeakMemoryDraftStore();
      final config = BeakFormDrafts(
        store: store,
        key: 'folder',
        context: 'user',
      );
      final source = FakeDataSource(
        models: const [_Folder(), _Child()],
        records: {
          'folders': {
            'p': BeakRecord.fromRow({'id': 'p', 'name': 'Folder'}),
          },
          'children': {
            'c': BeakRecord.fromRow({
              'id': 'c',
              'folder_id': 'p',
              'name': 'Before',
            }),
          },
        },
      );
      BeakFormSession create() => BeakFormSession(
        model: const _Folder(),
        dataSource: source,
        recordId: 'p',
        layout: _layout(),
        drafts: config,
      );
      final first = create();
      await first.load();
      first.root.rows(_children).single.set(_childName, 'Keep');
      await first.persistDraft();
      first.dispose();
      await source.delete('children', 'c');
      final resumed = create();
      addTearDown(resumed.dispose);
      await resumed.load();
      resumed.resumeDraft();
      expect(resumed.conflicts.single.label, contains('removed remotely'));
      expect(await resumed.validate(), false);
      resumed.resolveConflict(resumed.conflicts.single.path, useRemote: true);
      expect(resumed.root.rows(_children), isEmpty);
      expect(await resumed.validate(), true);
    },
  );
  test(
    'storage failures preserve local values and stay separate from submission errors',
    () async {
      final session = BeakFormSession(
        model: const _Folder(),
        dataSource: FakeDataSource(models: const [_Folder(), _Child()]),
        layout: _layout(),
        drafts: BeakFormDrafts(
          store: _BrokenStore(),
          key: 'folder',
          context: 'user',
        ),
      );
      addTearDown(session.dispose);
      await session.load();
      session.root.set(_name, 'Unsaved');
      await session.persistDraft();
      expect(session.root.read(_name), 'Unsaved');
      expect(session.draftNotice, contains('could not be stored'));
      expect(session.error.value, null);
    },
  );
  test(
    'versioned attribute definition drives required and canonical validation',
    () async {
      var version = 1;
      final input = _name.inputAttribute(
        definition: (_) => BeakAttributeDefinition(
          id: 'size',
          label: 'Size',
          type: BeakAttributeType.choice,
          choices: ['S', 'M'],
          required: true,
          version: 2,
        ),
        version: (_) => version,
      );
      final session = BeakFormSession(
        model: const _Folder(),
        dataSource: FakeDataSource(models: const [_Folder(), _Child()]),
        layout: BeakFormLayout(children: [input]),
      );
      addTearDown(session.dispose);
      session.root.set(_name, 'S');
      expect(await session.validate(), false);
      expect(
        session.root.errors['name']!.single,
        contains('definition changed'),
      );
      version = 2;
      expect(await session.validate(), true);
      session.root.set(_name, 'XL');
      expect(await session.validate(), false);
      expect(session.root.errors['name']!.single, contains('valid choice'));
    },
  );
  test('late edit loading after disposal is ignored', () async {
    final source = FakeDataSource(models: const [_Folder(), _Child()]);
    final session = BeakFormSession(
      model: const _Folder(),
      dataSource: source,
      recordId: 'p',
      editValues: (_) async => BeakRecord.fromRow({'id': 'p', 'name': 'Late'}),
    );
    final loading = session.load();
    session.dispose();
    await expectLater(loading, completes);
  });
}

final class _Folder extends BeakModel {
  const _Folder();
  @override
  String get table => 'folders';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'Id'),
    _name.column,
    _password.column,
    _image.column,
  ];
  @override
  List<BeakRelationship> get relationships => [_children.relation];
}

final class _Child extends BeakModel {
  const _Child();
  @override
  String get table => 'children';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'Id'),
    _childName.column,
    const BeakStringColumn(key: 'folder_id', label: 'Folder'),
  ];
}

final class _BrokenStore implements BeakDraftStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> remove(String key) async {}
  @override
  Future<void> write(String key, String document) async =>
      throw StateError('Storage quota');
}

final class _CapabilitySource extends FakeDataSource
    implements BeakCapabilityDataSource {
  final childCapabilities = Completer<BeakAccessCapabilities>();
  int childrenRequests = 0;

  @override
  Future<BeakAccessCapabilities> capabilities(
    String table, {
    Object? id,
  }) async {
    if (table == 'children') {
      childrenRequests++;
      return childCapabilities.future;
    }
    return const BeakAccessCapabilities();
  }
}

final class _ReceiptSource extends FakeDataSource
    implements BeakCommitDataSource {
  _ReceiptSource({this.interrupted = false, this.reject = false});
  final bool interrupted;
  final bool reject;
  final dispatched = Completer<void>();
  final completion = Completer<BeakSaveResult>();
  BeakSavePlan? plan;
  int commits = 0;
  final List<String> recoveries = [];
  BeakWriteOutcome recoveredStatus = BeakWriteOutcome.unknown;

  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities(atomicGraph: true, durableReceipts: true);

  BeakSaveResult receipt(BeakWriteOutcome status) => BeakSaveResult(
    saveId: plan!.saveId,
    mode: BeakSaveMode.atomic,
    rootOperationId: plan!.operations.first.id,
    outcomes: [
      for (final operation in plan!.operations)
        BeakOperationResult(
          id: operation.id,
          status: status,
          draftId: operation.target.draftId,
          resolvedId: 'saved-${operation.target.table}',
          record: status == BeakWriteOutcome.applied
              ? BeakRecord(
                  values: {
                    ...operation.values.values,
                    'id': BeakStringValue('saved-${operation.target.table}'),
                  },
                )
              : null,
          error: status == BeakWriteOutcome.unapplied
              ? BeakSaveError(
                  code: 'validation',
                  message: 'Correct the name',
                  fieldErrors: {
                    'name': ['Correct the name'],
                  },
                )
              : null,
        ),
    ],
  );

  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    commits++;
    this.plan = plan;
    dispatched.complete();
    return interrupted
        ? completion.future
        : receipt(
            reject ? BeakWriteOutcome.unapplied : BeakWriteOutcome.applied,
          );
  }

  @override
  Future<BeakSaveResult> recover(String saveId) async {
    recoveries.add(saveId);
    return receipt(recoveredStatus);
  }
}
