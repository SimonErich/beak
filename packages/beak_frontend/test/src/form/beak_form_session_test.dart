import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/src/form/beak_form_layout.dart';
import 'package:beak_frontend/src/form/beak_form_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/panel_fixtures.dart';

void main() {
  test(
    'record capabilities load concurrently with bounded, distinct permissions',
    () async {
      final source = _DelayedCapabilitiesSource();
      final session = _basketSession(source, id: 'basket');
      addTearDown(session.dispose);
      await session.load();
      expect(source.calls, 10);
      expect(source.maxPending, inInclusiveRange(2, 4));
      final rows = session.root.rows(_items);
      expect(rows.length, 9);
      for (final row in rows) {
        expect(row.capabilities.canWrite('name'), row.id != 'line-0');
      }
      source.deniedId = 'line-1';
      await session.load();
      expect(source.calls, 20);
      for (final row in session.root.rows(_items)) {
        expect(row.capabilities.canWrite('name'), row.id != 'line-1');
      }
    },
  );

  const title = BeakScalarField<String>(
    model: ArticleModel(),
    column: ArticleColumns.title,
  );
  const active = BeakScalarField<bool>(
    model: ArticleModel(),
    column: ArticleColumns.active,
  );
  const summary = BeakScalarField<String>(
    model: ArticleModel(),
    column: ArticleColumns.summary,
  );

  test(
    'minimum collection rows gate their wizard step and initial values stay stable',
    () async {
      final session = BeakFormSession(
        model: const _Basket(),
        dataSource: FakeDataSource(models: const [_Basket(), _Line()]),
        steps: [
          BeakWizardStep(
            title: 'Lines',
            children: [
              _items.tableForm(minRows: 1, children: [_lineName.inputText()]),
            ],
          ),
        ],
      );
      addTearDown(session.dispose);
      expect(await session.validateStep(0), false);
      expect(session.root.errors[_items.key], ['Add at least 1 row.']);
      final row = session.root.addRow(_items)..set(_lineName, 'Coffee');
      expect(await session.validateStep(0), true);
      session.root.removeRow(row);
      expect(await session.validateStep(0), false);
    },
  );

  test('disabled collection rejects adding, removing and restoring rows', () {
    var enabled = true;
    final session = BeakFormSession(
      model: const _Basket(),
      dataSource: FakeDataSource(),
      layout: BeakFormLayout(
        children: [
          _items.tableForm(
            enabledIf: (_) => enabled,
            children: [_lineName.inputText()],
          ),
        ],
      ),
    );
    addTearDown(session.dispose);
    final row = session.root.addRow(_items);
    enabled = false;
    expect(
      () => session.root.addRow(_items),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      () => session.root.removeRow(row),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      () => session.root.restoreRow(row),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(session.root.rows(_items), [row]);
  });

  test(
    'compact changes count a new relation row once and retain field detail',
    () {
      final session = _basketSession(
        FakeDataSource(models: const [_Basket(), _Line()]),
      );
      addTearDown(session.dispose);
      session.root.addRow(_items).set(_lineName, 'Coffee');
      expect(session.reviewChangeCount, 1);
      expect(session.compactReviewChanges.single.label, 'Coffee');
      expect(session.reviewChangeSummary, 'Coffee added');
      expect(session.reviewChanges.length, greaterThan(1));
      expect(
        session.reviewChanges.any((change) => change.column?.key == 'name'),
        true,
      );
    },
  );

  test(
    'saved relation selections hydrate includes without applying new option eligibility',
    () async {
      const category = BeakToOneField(
        model: ArticleModel(),
        relation: ArticleRelations.category,
        target: _CategoryWithOwner(),
      );
      const owner = BeakToOneField(
        model: _CategoryWithOwner(),
        relation: _CategoryWithOwner.owner,
        target: NoteModel(),
      );
      const ownerTitle = BeakScalarField<String>(
        model: ArticleModel(),
        column: BeakStringColumn(key: 'title', label: 'Owner'),
        path: [ArticleRelations.category, _CategoryWithOwner.owner],
      );
      final source = FakeDataSource(
        models: const [ArticleModel(), _CategoryWithOwner(), NoteModel()],
        records: {
          'articles': {
            'a1': BeakRecord.fromRow({
              'id': 'a1',
              'title': 'Saved',
              'category_id': 'c1',
            }),
          },
          'categories': {
            'c1': BeakRecord.fromRow({
              'id': 'c1',
              'name': 'Existing',
              'owner_id': 'n1',
            }),
          },
          'notes': {
            'n1': BeakRecord.fromRow({'id': 'n1', 'title': 'Owner label'}),
          },
        },
      );
      final session = BeakFormSession(
        model: const ArticleModel(),
        dataSource: source,
        recordId: 'a1',
        layout: BeakFormLayout(
          children: [
            title.inputText(),
            category.inputCombobox(
              options: (_) => category
                  .options(
                    filter: const BeakScalarField<String>(
                      model: _CategoryWithOwner(),
                      column: BeakStringColumn(key: 'name', label: 'Name'),
                    ).eq('Eligible new option'),
                  )
                  .including([owner]),
            ),
          ],
        ),
      );
      addTearDown(session.dispose);
      await session.load();
      expect(session.root.read(ownerTitle), 'Owner label');
      session.root.set(title, 'Local title');
      expect(title.readFrom(session.root.initialRecord), 'Saved');
      expect(session.root.read(title), 'Local title');
      final query = source.queryCalls.lastWhere(
        (query) => query.table == 'categories',
      );
      expect(query.relationLoads.single.relationKey, 'owner');
      expect(
        query.filter,
        isA<BeakFieldFilter>().having(
          (filter) => filter.columnKey,
          'column',
          'id',
        ),
      );
    },
  );

  test('hidden values stay in draft but are omitted from the command', () {
    final session = BeakFormSession(
      model: const ArticleModel(),
      dataSource: FakeDataSource(),
      layout: BeakFormLayout(
        children: [
          title.inputText(),
          active.inputToggle(),
          summary.inputText(visibleIf: (state) => state.read(active) == true),
        ],
      ),
    );
    addTearDown(session.dispose);
    session.root.set(title, 'Draft');
    session.root.set(summary, 'Retained');
    expect(session.root.read(summary), 'Retained');
    expect(session.root.buildRecord().values.containsKey('summary'), false);
    session.root.set(active, true);
    expect(session.root.buildRecord()['summary']?.raw, 'Retained');
  });

  test('step validation awaits rules and validates only that step', () async {
    final session = BeakFormSession(
      model: const ArticleModel(),
      dataSource: FakeDataSource(),
      steps: [
        BeakWizardStep(title: 'Identity', children: [title.inputText()]),
        BeakWizardStep(
          title: 'Extra',
          children: [
            summary.inputText(
              validators: [
                (value, state) async => value == 'OK' ? null : 'Enter OK',
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(session.dispose);
    expect(await session.validateStep(0), false);
    session.root.set(title, 'Valid');
    expect(await session.validateStep(0), true);
    expect(await session.validate(), false);
    session.root.set(summary, 'OK');
    expect(await session.validate(), true);
  });
  test(
    'a new parent and related rows stay local until one final save',
    () async {
      final source = FakeDataSource(models: const [_Basket(), _Line()]);
      final session = _basketSession(source);
      addTearDown(session.dispose);
      session.root.set(_basketTitle, 'Shopping');
      final line = session.root.addRow(_items)..set(_lineName, 'Coffee');
      expect(source.createCalls, isEmpty);
      final checkpoint = line.checkpoint();
      line.set(_lineName, 'Changed');
      line.restore(checkpoint);
      expect(line.read(_lineName), 'Coffee');
      final result = await session.save();
      expect(result?.complete, true);
      expect(source.createCalls.map((entry) => entry.$1), ['baskets', 'lines']);
      expect(
        source.store.rowsOf('lines').single['basket_id']?.raw,
        session.root.id,
      );
      expect(session.isDirty, false);
    },
  );

  test(
    'partial saves rebase confirmed records and retry only unapplied rows',
    () async {
      final source = _FailingLineSource();
      final session = _basketSession(source);
      addTearDown(session.dispose);
      session.root.set(_basketTitle, 'Shopping');
      final row = session.root.addRow(_items)..set(_lineName, 'Coffee');
      final first = await session.save();
      expect(first?.complete, false);
      expect(session.root.id, isNotNull);
      expect(row.id, isNull);
      expect(row.errors['name'], ['Name rejected.']);
      expect(session.isDirty, true);
      source.reject = false;
      row.set(_lineName, 'Tea');
      final second = await session.save();
      expect(second?.complete, true);
      expect(
        source.createCalls.where((entry) => entry.$1 == 'baskets').length,
        1,
      );
      expect(source.store.rowsOf('lines').single['name']?.raw, 'Tea');
      expect(session.isDirty, false);
    },
  );

  test(
    'removing a new row never sends a delete and cancelling restores its values',
    () {
      final source = FakeDataSource(models: const [_Basket(), _Line()]);
      final session = _basketSession(source);
      addTearDown(session.dispose);
      final row = session.root.addRow(_items)..set(_lineName, 'Coffee');
      final checkpoint = session.root.checkpoint();
      session.root.removeRow(row);
      expect(session.root.rows(_items), isEmpty);
      session.root.restore(checkpoint);
      expect(session.root.rows(_items).single.read(_lineName), 'Coffee');
      expect(source.deleteCalls, isEmpty);
    },
  );

  test(
    'custom validator failures are reported and release the submit lock',
    () async {
      var reject = true;
      final source = FakeDataSource();
      final session = BeakFormSession(
        model: const ArticleModel(),
        dataSource: source,
        layout: BeakFormLayout(
          children: [
            title.inputText(
              validators: [
                (value, state) async {
                  if (reject) {
                    throw const BeakValidationException(
                      'Validator unavailable',
                    );
                  }
                  return null;
                },
              ],
            ),
          ],
        ),
      );
      addTearDown(session.dispose);
      session.root.set(title, 'Saved later');
      expect(await session.save(), isNull);
      expect(session.error.value?.message, 'Validator unavailable');
      expect(session.submitting.value, false);
      reject = false;
      expect((await session.save())?.complete, true);
    },
  );

  test('hidden scalar values survive saving visible fields', () async {
    final session = BeakFormSession(
      model: const ArticleModel(),
      dataSource: FakeDataSource(),
      layout: BeakFormLayout(
        children: [
          title.inputText(),
          active.inputToggle(),
          summary.inputText(visibleIf: (state) => state.read(active) == true),
        ],
      ),
    );
    addTearDown(session.dispose);
    session.root.set(title, 'Saved');
    session.root.set(summary, 'Keep locally');
    expect((await session.save())?.complete, true);
    expect(session.root.read(summary), 'Keep locally');
    session.root.set(active, true);
    expect(session.root.buildRecord()['summary']?.raw, 'Keep locally');
  });

  test(
    'a lost reply freezes edits and recovers without replaying creates',
    () async {
      const field = BeakScalarField<String>(
        model: NoteModel(),
        column: BeakStringColumn(key: 'title', label: 'Title'),
      );
      final source = _LostReplySource();
      final session = BeakFormSession(
        model: const NoteModel(),
        dataSource: source,
      );
      addTearDown(session.dispose);
      session.root.set(field, 'Original');
      final result = await session.save();
      expect(result?.complete, false);
      expect(session.hasUnknown, true);
      session.root.set(field, 'Must not overwrite the pending command');
      expect(session.root.read(field), 'Original');
      await session.save();
      expect(source.createCalls, hasLength(1));
      await session.recover();
      expect(session.hasUnknown, false);
      expect(session.saveResult.value?.complete, true);
      expect(session.root.id, isNotNull);
      expect(session.root.read(field), 'Original');
      expect(source.createCalls, hasLength(1));
      expect(session.canLeave, true);
    },
  );

  test(
    'concurrent saves share one commit and navigation waits for its receipt',
    () async {
      final source = _DelayedSource();
      final session = BeakFormSession(
        model: const NoteModel(),
        dataSource: source,
      );
      addTearDown(session.dispose);
      session.allowExit();
      final first = session.save();
      final second = session.save();
      await source.started.future;
      expect(source.commitCalls, 1);
      expect(session.canLeave, false);
      source.release.complete();
      expect((await first)?.complete, true);
      expect((await second)?.complete, true);
      expect(source.createCalls, hasLength(1));
      expect(session.canLeave, true);
    },
  );

  test('disposing during a commit does not mutate disposed signals', () async {
    final source = _DelayedSource();
    final session = BeakFormSession(
      model: const NoteModel(),
      dataSource: source,
    );
    final pending = session.save();
    await source.started.future;
    session.dispose();
    source.release.complete();
    expect(await pending, isNull);
    expect(source.createCalls, hasLength(1));
  });

  test(
    'hidden new lookup selections are staged until their placement is visible',
    () async {
      const categoryModel = _Category();
      const category = BeakToOneField(
        model: ArticleModel(),
        relation: ArticleRelations.category,
        target: categoryModel,
      );
      final name = BeakScalarField<String>(
        model: categoryModel,
        column: categoryModel.columnByKey('name')!,
      );
      final input = category.inputCombobox(
        exclusive: false,
        visibleIf: (state) => state.read(title) == 'Visible',
      );
      final source = FakeDataSource(models: const [_Category()]);
      final session = BeakFormSession(
        model: const ArticleModel(),
        dataSource: source,
        layout: BeakFormLayout(children: [title.inputText(), input]),
      );
      addTearDown(session.dispose);
      session.root.set(title, 'Hidden');
      session.root.createSelection(input).set(name, 'Local category');
      expect((await session.save())?.complete, true);
      expect(source.store.rowsOf('categories'), isEmpty);
      expect(source.createCalls.single.$2['category_id'], isNull);
      session.root.set(title, 'Visible');
      expect((await session.save())?.complete, true);
      expect(
        source.store.rowsOf('categories').single['name']?.raw,
        'Local category',
      );
      expect(session.root.read(category)?['name']?.raw, 'Local category');
    },
  );

  test(
    'changing a dependency rejects old options even before a selection',
    () async {
      const categoryModel = _Category();
      const category = BeakToOneField(
        model: ArticleModel(),
        relation: ArticleRelations.category,
        target: categoryModel,
      );
      final input = category.inputCombobox(
        options: (state) => BeakOptionQuery(
          model: categoryModel,
          query: BeakQuerySpec(
            table: categoryModel.table,
            filter: BeakFieldFilter.forKey(
              'name',
              BeakOperator.eq,
              BeakValue.of(state.read(title)),
            ),
          ),
        ),
      );
      final source = _QueuedLookupSource();
      final session = BeakFormSession(
        model: const ArticleModel(),
        dataSource: source,
        layout: BeakFormLayout(children: [title.inputText(), input]),
      );
      addTearDown(session.dispose);
      session.root.set(title, 'Old');
      final oldLookup = session.root.search(input, '');
      session.root.set(title, 'New');
      source.lookups.single.complete(
        BeakPage(
          items: [
            BeakRecord.fromRow({'id': 'old', 'name': 'Old'}),
          ],
          total: 1,
          page: 1,
          perPage: 25,
        ),
      );
      expect(await oldLookup, isEmpty);
      final currentLookup = session.root.search(input, '');
      source.lookups.last.complete(
        BeakPage(
          items: [
            BeakRecord.fromRow({'id': 'new', 'name': 'New'}),
          ],
          total: 1,
          page: 1,
          perPage: 25,
        ),
      );
      expect((await currentLookup).single['name']?.raw, 'New');
    },
  );

  test('failed initial loading cannot submit an empty update', () async {
    final source = FakeDataSource();
    final session = BeakFormSession(
      model: const NoteModel(),
      dataSource: source,
      recordId: 'missing',
    );
    addTearDown(session.dispose);
    await session.load();
    expect(session.initialized, false);
    expect(session.error.value, isA<BeakNotFoundException>());
    expect(await session.save(), isNull);
    expect(source.updateCalls, isEmpty);
  });

  test(
    'persisted relationship removal detaches without deleting the child',
    () async {
      final source = FakeDataSource(
        models: const [_Basket(), _Line()],
        records: {
          'baskets': {
            'owner': BeakRecord.fromRow({'id': 'owner', 'title': 'Shopping'}),
          },
          'lines': {
            'child': BeakRecord.fromRow({
              'id': 'child',
              'name': 'Coffee',
              'basket_id': 'owner',
            }),
          },
        },
      );
      final session = BeakFormSession(
        model: const _Basket(),
        dataSource: source,
        recordId: 'owner',
        layout: BeakFormLayout(
          children: [
            _basketTitle.inputText(),
            _items.tableForm(children: [_lineName.inputText()]),
          ],
        ),
      );
      addTearDown(session.dispose);
      await session.load();
      session.root.removeRow(session.root.rows(_items).single);
      final result = await session.save();
      expect(
        result?.complete,
        true,
        reason: result?.toJson().toString() ?? session.error.value?.message,
      );
      expect(source.deleteCalls, isEmpty);
      expect(source.store.rowsOf('lines').single['basket_id']?.raw, isNull);
      expect(session.root.rows(_items), isEmpty);
    },
  );

  test(
    'pivot attachment preserves the child identity and only saves it once',
    () async {
      const labels = BeakToManyField(
        model: NoteModel(),
        relation: NoteRelations.labels,
        target: LabelModel(),
      );
      const name = BeakScalarField<String>(
        model: LabelModel(),
        column: BeakStringColumn(key: 'name', label: 'Name'),
      );
      final source = FakeDataSource(
        records: {
          'notes': {
            'owner': BeakRecord.fromRow({'id': 'owner', 'title': 'Shopping'}),
          },
        },
      );
      final session = BeakFormSession(
        model: const NoteModel(),
        dataSource: source,
        recordId: 'owner',
        layout: BeakFormLayout(
          children: [
            labels.tableForm(children: [name.inputText()]),
          ],
        ),
      );
      addTearDown(session.dispose);
      await session.load();
      final row = session.root.addRow(labels)..set(name, 'Coffee');
      expect((await session.save())?.complete, true);
      expect(row.id, source.store.rowsOf('labels').single['id']?.raw);
      expect(row.id, isNot('owner'));
      expect(row.read(name), 'Coffee');
      expect(session.isDirty, false);
      await session.save();
      expect(source.createCalls, hasLength(1));
      expect(source.attachCalls, hasLength(1));
    },
  );

  test('hidden relationship drafts stay local and are not saved', () async {
    final source = FakeDataSource(models: const [_Basket(), _Line()]);
    final session = BeakFormSession(
      model: const _Basket(),
      dataSource: source,
      layout: BeakFormLayout(
        children: [
          _basketTitle.inputText(),
          _items.tableForm(
            visibleIf: (state) => state.read(_basketTitle) == 'Visible',
            children: [_lineName.inputText()],
          ),
        ],
      ),
    );
    addTearDown(session.dispose);
    session.root.set(_basketTitle, 'Hidden');
    final row = session.root.addRow(_items)..set(_lineName, 'Retained');
    expect((await session.save())?.complete, true);
    expect(source.createCalls.map((call) => call.$1), ['baskets']);
    expect(row.id, isNull);
    expect(row.read(_lineName), 'Retained');
    session.root.set(_basketTitle, 'Visible');
    expect((await session.save())?.complete, true);
    expect(source.store.rowsOf('lines').single['name']?.raw, 'Retained');
  });

  test(
    'derived values react automatically and circular calculations are rejected',
    () {
      const stock = BeakScalarField<int>(
        model: ArticleModel(),
        column: ArticleColumns.stock,
      );
      const price = BeakScalarField<double>(
        model: ArticleModel(),
        column: ArticleColumns.price,
      );
      final session = BeakFormSession(
        model: const ArticleModel(),
        dataSource: FakeDataSource(),
        layout: BeakFormLayout(
          children: [
            stock.inputNumber(),
            price.inputNumber(
              derive: (state) => (state.read(stock) ?? 0) * 2.0,
            ),
          ],
        ),
      );
      addTearDown(session.dispose);
      session.root.set(stock, 4);
      expect(session.root.read(price), 8.0);
      expect(
        () => BeakFormSession(
          model: const ArticleModel(),
          dataSource: FakeDataSource(),
          layout: BeakFormLayout(
            children: [
              price.inputNumber(derive: (state) => state.read(price) ?? 0),
            ],
          ),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );
}

final class _Basket extends BeakModel {
  const _Basket();
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    rules: [BeakRequired()],
  );
  static const items = BeakHasMany(
    key: 'items',
    label: 'Items',
    relatedTable: 'lines',
    displayColumnKey: 'name',
    foreignKey: 'basket_id',
    owned: true,
  );
  @override
  String get table => 'baskets';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    title,
  ];
  @override
  List<BeakRelationship> get relationships => const [items];
}

final class _Line extends BeakModel {
  const _Line();
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    rules: [BeakRequired()],
  );
  @override
  String get table => 'lines';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    name,
    BeakStringColumn(key: 'basket_id', label: 'Basket'),
  ];
}

const _basketTitle = BeakScalarField<String>(
  model: _Basket(),
  column: _Basket.title,
);
const _lineName = BeakScalarField<String>(model: _Line(), column: _Line.name);
const _items = BeakToManyField(
  model: _Basket(),
  relation: _Basket.items,
  target: _Line(),
);

BeakFormSession _basketSession(FakeDataSource source, {Object? id}) =>
    BeakFormSession(
      model: const _Basket(),
      dataSource: source,
      recordId: id,
      layout: BeakFormLayout(
        children: [
          _basketTitle.inputText(),
          _items.tableForm(
            children: [_lineName.inputText()],
            removeBehavior: BeakRemoveBehavior.deleteOwned,
          ),
        ],
      ),
    );

final class _FailingLineSource extends FakeDataSource
    implements BeakCommitDataSource {
  _FailingLineSource() : super(models: const [_Basket(), _Line()]);
  bool reject = true;
  BeakSaveResult? last;
  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities();
  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    final registry = BeakModelRegistry()
      ..register(const _Basket())
      ..register(const _Line());
    return last = await executeBeakSavePlan(
      plan: plan,
      registry: registry,
      run: (operation, identities) async {
        if (operation.target.table == 'lines' && reject) {
          return BeakOperationResult(
            id: operation.id,
            status: BeakWriteOutcome.unapplied,
            error: BeakSaveError(
              code: 'validation',
              message: 'Check this item.',
              fieldErrors: {
                'name': ['Name rejected.'],
              },
            ),
          );
        }
        return executeBeakSaveOperation(
          operation,
          source: this,
          registry: registry,
          identities: identities,
        );
      },
    );
  }

  @override
  Future<BeakSaveResult> recover(String saveId) async => last!;
}

final class _LostReplySource extends FakeDataSource
    implements BeakCommitDataSource {
  BeakSaveResult? receipt;
  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities();
  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    final registry = BeakModelRegistry()..register(const NoteModel());
    receipt = await executeBeakSavePlan(
      plan: plan,
      registry: registry,
      run: (operation, identities) => executeBeakSaveOperation(
        operation,
        source: this,
        registry: registry,
        identities: identities,
      ),
    );
    throw const BeakStorageException('Response lost after write.');
  }

  @override
  Future<BeakSaveResult> recover(String saveId) async => receipt!;
}

final class _DelayedSource extends FakeDataSource
    implements BeakCommitDataSource {
  final started = Completer<void>();
  final release = Completer<void>();
  int commitCalls = 0;
  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities();
  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    commitCalls++;
    started.complete();
    await release.future;
    final registry = BeakModelRegistry()..register(const NoteModel());
    return executeBeakSavePlan(
      plan: plan,
      registry: registry,
      run: (operation, identities) => executeBeakSaveOperation(
        operation,
        source: this,
        registry: registry,
        identities: identities,
      ),
    );
  }

  @override
  Future<BeakSaveResult> recover(String saveId) async =>
      throw UnimplementedError();
}

final class _Category extends BeakModel {
  const _Category();
  @override
  String get table => 'categories';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];
}

final class _QueuedLookupSource extends FakeDataSource {
  _QueuedLookupSource() : super(models: const [_Category()]);
  final List<Completer<BeakPage<BeakRecord>>> lookups = [];
  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) {
    queryCalls.add(spec);
    final result = Completer<BeakPage<BeakRecord>>();
    lookups.add(result);
    return result.future;
  }
}

final class _CategoryWithOwner extends BeakModel {
  const _CategoryWithOwner();
  static const owner = BeakBelongsTo(
    key: 'owner',
    label: 'Owner',
    relatedTable: 'notes',
    displayColumnKey: 'title',
    foreignKey: 'owner_id',
  );
  @override
  String get table => 'categories';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
    BeakStringColumn(key: 'owner_id', label: 'Owner'),
  ];
  @override
  List<BeakRelationship> get relationships => const [owner];
}

final class _DelayedCapabilitiesSource extends FakeDataSource
    implements BeakCapabilityDataSource {
  _DelayedCapabilitiesSource()
    : super(
        models: const [_Basket(), _Line()],
        records: {
          'baskets': {
            'basket': BeakRecord.fromRow({'id': 'basket', 'title': 'Delivery'}),
          },
          'lines': {
            for (var i = 0; i < 9; i++)
              'line-$i': BeakRecord.fromRow({
                'id': 'line-$i',
                'name': 'Line $i',
                'basket_id': 'basket',
              }),
          },
        },
      );

  int calls = 0;
  int pending = 0;
  int maxPending = 0;
  String deniedId = 'line-0';

  @override
  Future<BeakAccessCapabilities> capabilities(
    String table, {
    Object? id,
  }) async {
    calls++;
    pending++;
    if (pending > maxPending) maxPending = pending;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    pending--;
    return BeakAccessCapabilities(writableFields: id == deniedId ? {} : null);
  }
}
