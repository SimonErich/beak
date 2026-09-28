import 'dart:async';
import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';
import '../../support/panel_fixtures.dart';

const _title = BeakScalarField<String>(
  model: NoteModel(),
  column: BeakStringColumn(key: 'title', label: 'Title'),
);
void main() {
  BeakFormSession notes(
    BeakDataSource source, {
    BeakFormDrafts? drafts,
    Object? id,
  }) => BeakFormSession(
    model: const NoteModel(),
    dataSource: source,
    drafts: drafts,
    recordId: id,
    layout: BeakFormLayout(children: [_title.input()]),
  );
  test('durable draft resumes after disposal and save removes it', () async {
    final store = BeakMemoryDraftStore();
    final config = BeakFormDrafts(
      store: store,
      key: 'editor',
      context: 'tenant:a/user:7',
    );
    final source = FakeDataSource();
    final first = notes(source, drafts: config);
    await first.load();
    first.root.set(_title, 'Unfinished');
    await first.persistDraft();
    first.dispose();
    final resumed = notes(source, drafts: config);
    addTearDown(resumed.dispose);
    await resumed.load();
    expect(resumed.hasStoredDraft, true);
    expect(resumed.root.read(_title), null);
    resumed.resumeDraft();
    expect(resumed.root.read(_title), 'Unfinished');
    expect(resumed.isDirty, true);
    expect((await resumed.save())?.complete, true);
    await resumed.discardStoredDraft();
    expect(await store.read(config.storageKey('notes', null)), null);
  });
  test(
    'restored drafts compare baseline with latest and require conflict choice',
    () async {
      final store = BeakMemoryDraftStore();
      final config = BeakFormDrafts(
        store: store,
        key: 'editor',
        context: 'user',
      );
      final source = FakeDataSource(
        records: {
          'notes': {
            'n1': BeakRecord.fromRow({'id': 'n1', 'title': 'Before'}),
          },
        },
      );
      final first = notes(source, drafts: config, id: 'n1');
      await first.load();
      first.root.set(_title, 'Local');
      await first.persistDraft();
      first.dispose();
      await source.update(
        'notes',
        'n1',
        BeakRecord.fromRow({'title': 'Remote'}),
      );
      final resumed = notes(source, drafts: config, id: 'n1');
      addTearDown(resumed.dispose);
      await resumed.load();
      resumed.resumeDraft();
      expect(resumed.conflicts.single.original?.raw, 'Before');
      expect(resumed.conflicts.single.remote?.raw, 'Remote');
      expect(await resumed.validate(), false);
      await resumed.persistDraft();
      final reopened = notes(source, drafts: config, id: 'n1');
      await reopened.load();
      reopened.resumeDraft();
      expect(reopened.conflicts.single.original?.raw, 'Before');
      reopened.dispose();
      resumed.resolveConflict(resumed.conflicts.single.path, useRemote: false);
      expect(resumed.root.read(_title), 'Local');
      expect(resumed.root.initialRecord['title']?.raw, 'Remote');
      expect(await resumed.validate(), true);
    },
  );
  test(
    'namespace and schema versions isolate users and reject old layouts',
    () async {
      final store = BeakMemoryDraftStore();
      final source = FakeDataSource();
      final first = notes(
        source,
        drafts: BeakFormDrafts(store: store, key: 'editor', context: 'one'),
      );
      await first.load();
      first.root.set(_title, 'Private');
      await first.persistDraft();
      first.dispose();
      final other = notes(
        source,
        drafts: BeakFormDrafts(store: store, key: 'editor', context: 'two'),
      );
      addTearDown(other.dispose);
      await other.load();
      expect(other.hasStoredDraft, false);
      final upgraded = notes(
        source,
        drafts: BeakFormDrafts(
          store: store,
          key: 'editor',
          context: 'one',
          schemaVersion: 2,
        ),
      );
      addTearDown(upgraded.dispose);
      await upgraded.load();
      expect(upgraded.hasStoredDraft, false);
      expect(upgraded.draftNotice, contains('incompatible'));
    },
  );
  test(
    'existence rules infer picker prerequisites, scope, invalidation and create defaults',
    () async {
      final source = FakeDataSource(
        models: const [_Booking(), _Profile()],
        records: {
          'profiles': {
            'p1': BeakRecord.fromRow({
              'id': 'p1',
              'name': 'Alice',
              'customer_id': 'a',
            }),
            'p2': BeakRecord.fromRow({
              'id': 'p2',
              'name': 'Bob',
              'customer_id': 'b',
            }),
          },
        },
      );
      final input = _profile.inputCombobox(exclusive: false);
      final session = BeakFormSession(
        model: const _Booking(),
        dataSource: source,
        layout: BeakFormLayout(children: [_customer.input(), input]),
      );
      addTearDown(session.dispose);
      expect(session.root.enabled(input), false);
      expect(await session.root.search(input, ''), isEmpty);
      session.root.set(_customer, 'a');
      expect(session.root.enabled(input), true);
      final options = await session.root.search(input, '');
      expect(options.map((r) => r['name']?.raw), ['Alice']);
      session.root.select(_profile, options.single);
      session.root.set(_customer, 'b');
      await Future<void>.delayed(Duration.zero);
      expect(session.root.read(_profile), null);
      final created = session.root.createSelection(input);
      expect(created.snapshot['customer_id']?.raw, 'b');
    },
  );
  test(
    'suggestions follow dependencies until overridden and derived values are read only',
    () {
      final total = _total.input();
      final session = BeakFormSession(
        model: const _Sale(),
        dataSource: FakeDataSource(models: const [_Sale()]),
        layout: BeakFormLayout(
          children: [_quantity.input(), _price.input(), total],
        ),
      );
      addTearDown(session.dispose);
      session.root.set(_quantity, 2);
      expect(session.root.read(_price), 20);
      expect(session.root.read(_total), 40);
      session.root.set(_quantity, 3);
      expect(session.root.read(_price), 30);
      session.root.set(_price, 7);
      session.root.set(_quantity, 4);
      expect(session.root.read(_price), 7);
      expect(session.root.read(_total), 28);
      expect(session.root.enabled(total), false);
      expect(session.root.buildRecord().values.containsKey('total'), false);
    },
  );
  test('named actions commit clean records with typed arguments', () async {
    final source = _CommandSource();
    final session = BeakFormSession(
      model: const _Sale(),
      dataSource: source,
      recordId: 's1',
    );
    addTearDown(session.dispose);
    await session.load();
    await session.executeAction(
      'issue',
      arguments: BeakRecord.fromRow({'reference': 'INV-2'}),
    );
    expect(source.plan?.action, 'issue');
    expect(source.plan?.arguments['reference']?.raw, 'INV-2');
    expect(source.plan?.operations.single.target.id, 's1');
  });
  testWidgets('action capabilities hide commands and block direct execution', (
    tester,
  ) async {
    final source = _RestrictedCommandSource();
    late BeakFormSession session;
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: const _Sale(),
          dataSource: source,
          recordId: 's1',
          mode: BeakFormMode.read,
          onSession: (value) => session = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Issue'), findsNothing);
    expect(await session.executeAction('issue'), isNull);
    expect(await session.save(action: 'issue'), isNull);
    expect(source.plan, isNull);
    expect(session.error.value, isA<BeakAuthorizationException>());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'section guards and server capabilities cover inputs and custom widgets',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final session = Completer<BeakFormSession>();
      final sections = BeakFormSections(
        sections: [
          BeakSection(
            title: 'Data',
            enabledIf: (_) => false,
            children: [
              _quantity.input(),
              _price.input(),
              BeakFormWidget(
                builder: (context, draft) => OiLabel.body(
                  'Custom enabled: ${BeakDraftScope.of(context).enabled}',
                ),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakConfiguredForm(
            model: const _Sale(),
            dataSource: _LimitedSource(),
            layout: sections.tabs,
            onSession: session.complete,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = await session.future;
      expect(find.text('Custom enabled: false'), findsOneWidget);
      expect(find.text('Price'), findsNothing);
      expect(state.root.buildRecord().values.containsKey('price'), false);
      expect(state.root.enabled(sections.sections.first.children.first), false);
      expect(
        sections.steps.single.enabledIf,
        same(sections.sections.first.enabledIf),
      );
      expect(tester.takeException(), null);
    },
  );
  testWidgets('resource model actions and duplication need no page callbacks', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _CommandSource();
    await tester.pumpWidget(
      BeakPanel(
        dataSource: source,
        resources: [
          const BeakResource(
            model: _Sale(),
            duplication: BeakDuplicationSpec(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sales').first);
    await tester.pumpAndSettle();
    Finder action(String label) => find.byWidgetPredicate(
      (widget) => widget is OiButton && widget.semanticLabel == label,
    );
    expect(action('Issue'), findsOneWidget);
    await tester.tap(action('Issue'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue').last);
    await tester.pumpAndSettle();
    expect(source.plan?.action, 'issue');
    source.plan = null;
    await tester.tap(action('View'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue').last);
    await tester.pumpAndSettle();
    expect(source.plan?.action, 'issue');
    await tester.tap(find.text('Sales').first);
    await tester.pumpAndSettle();
    await tester.tap(action('Duplicate'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byType(BeakConfiguredForm), findsOneWidget);
    expect(source.createCalls, isEmpty);
    expect(tester.takeException(), null);
  });

  testWidgets(
    'inspector, action confirmation and custom read visibility work',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = _CommandSource();
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakConfiguredForm(
            model: const _Sale(),
            dataSource: source,
            recordId: 's1',
            mode: BeakFormMode.read,
            showInspector: true,
            layout: BeakFormLayout(
              children: [
                _quantity.input(),
                BeakFormWidget(
                  showOnRead: false,
                  builder: (_, _) => const Text('Edit tools'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit tools'), findsNothing);
      await tester.tap(find.text('Inspect form'));
      await tester.pumpAndSettle();
      expect(find.text('Form inspector'), findsWidgets);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Issue'));
      await tester.pumpAndSettle();
      expect(source.plan, null);
      await tester.tap(find.text('Issue').last);
      await tester.pumpAndSettle();
      expect(source.plan?.action, 'issue');
      expect(tester.takeException(), null);
    },
  );
}

const _customer = BeakScalarField<String>(
  model: _Booking(),
  column: BeakStringColumn(key: 'customer_id', label: 'Customer'),
);
const _profileId = BeakScalarField<String>(
  model: _Booking(),
  column: BeakStringColumn(key: 'profile_id', label: 'Profile'),
);
const _profile = BeakToOneField(
  model: _Booking(),
  target: _Profile(),
  relation: BeakBelongsTo(
    key: 'profile',
    label: 'Profile',
    relatedTable: 'profiles',
    foreignKey: 'profile_id',
    displayColumnKey: 'name',
  ),
);
const _profileCustomer = BeakScalarField<String>(
  model: _Profile(),
  column: BeakStringColumn(key: 'customer_id', label: 'Customer'),
);
const _profileKey = BeakScalarField<String>(
  model: _Profile(),
  column: BeakStringColumn(key: 'id', label: 'Id'),
);

final class _Booking extends BeakModel {
  const _Booking();
  @override
  String get table => 'bookings';
  @override
  String get displayColumnKey => 'customer_id';
  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'Id'),
    _customer.column,
    _profileId.column,
  ];
  @override
  List<BeakRelationship> get relationships => [_profile.relation];
  @override
  List<BeakRecordRule> get validationRules => [
    const BeakExists(
      _profileId,
      _profileKey,
      matching: [BeakFieldMatch(target: _profileCustomer, source: _customer)],
    ),
  ];
}

final class _Profile extends BeakModel {
  const _Profile();
  @override
  String get table => 'profiles';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'Id'),
    const BeakStringColumn(key: 'name', label: 'Name'),
    _profileCustomer.column,
  ];
}

const _quantity = BeakScalarField<int>(
  model: _Sale(),
  column: BeakIntColumn(key: 'quantity', label: 'Quantity'),
);
const _price = BeakScalarField<int>(
  model: _Sale(),
  column: BeakIntColumn(key: 'price', label: 'Price'),
);
const _total = BeakScalarField<int>(
  model: _Sale(),
  column: BeakIntColumn(key: 'total', label: 'Total'),
);

final class _Sale extends BeakModel {
  const _Sale();
  @override
  String get table => 'sales';
  @override
  String get displayColumnKey => 'quantity';
  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'Id'),
    _quantity.column,
    _price.column,
    _total.column,
  ];
  @override
  BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior.suggested(
        field: _price,
        dependencies: [_quantity],
        resolve: (c) => (c.read(_quantity) ?? 0) * 10,
      ),
      BeakValueBehavior.derived(
        field: _total,
        dependencies: [_quantity, _price],
        resolve: (c) => (c.read(_quantity) ?? 0) * (c.read(_price) ?? 0),
      ),
    ],
    actions: const [BeakModelAction(name: 'issue', label: 'Issue')],
  );
}

final class _LimitedSource extends FakeDataSource
    implements BeakCapabilityDataSource {
  _LimitedSource() : super(models: const [_Sale()]);
  @override
  Future<BeakAccessCapabilities> capabilities(
    String table, {
    Object? id,
  }) async => const BeakAccessCapabilities(
    readableFields: {'id', 'quantity'},
    writableFields: {'quantity'},
  );
}

base class _CommandSource extends FakeDataSource
    implements BeakCommitDataSource {
  _CommandSource()
    : super(
        models: const [_Sale()],
        records: {
          'sales': {
            's1': BeakRecord.fromRow({
              'id': 's1',
              'quantity': 2,
              'price': 20,
              'total': 40,
            }),
          },
        },
      );
  BeakSavePlan? plan;
  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities(atomicGraph: true);
  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    this.plan = plan;
    return BeakSaveResult(
      saveId: plan.saveId,
      mode: BeakSaveMode.atomic,
      outcomes: [
        for (final op in plan.operations)
          BeakOperationResult(
            id: op.id,
            status: BeakWriteOutcome.applied,
            resolvedId: op.target.id,
            record: BeakRecord.fromRow({
              'id': 's1',
              'quantity': 2,
              'price': 20,
              'total': 40,
            }),
          ),
      ],
    );
  }

  @override
  Future<BeakSaveResult> recover(String saveId) => throw UnimplementedError();
}

final class _RestrictedCommandSource extends _CommandSource
    implements BeakCapabilityDataSource {
  @override
  Future<BeakAccessCapabilities> capabilities(
    String table, {
    Object? id,
  }) async => const BeakAccessCapabilities(executableActions: {});
}
