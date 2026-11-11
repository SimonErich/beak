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

final class _ImmutableNoteModel extends BeakModel {
  const _ImmutableNoteModel();
  @override
  String get table => 'notes';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => const NoteModel().columns;
  @override
  BeakModelBehavior get behavior =>
      BeakModelBehavior(editableWhen: (_) => false);
}

void main() {
  test(
    'derived revisions do not create unsaved edits after load or save',
    () async {
      final source = _RevisionedNoteSource();
      final session = BeakFormSession(
        model: const _RevisionedNote(),
        dataSource: source,
        recordId: 'n1',
        layout: BeakFormLayout(children: [_RevisionedNote.title.input()]),
      );
      addTearDown(session.dispose);
      await session.load();
      expect(session.root.read(_RevisionedNote.version), 8);
      expect(session.isDirty, isFalse);
      expect(session.canLeave, isTrue);

      session.root.set(_RevisionedNote.title, 'Changed');
      expect(session.isDirty, isTrue);
      expect(session.canLeave, isFalse);
      final result = await session.save();
      expect(
        result?.complete,
        isTrue,
        reason:
            '${result?.toJson()} ${session.error.value} ${session.root.errors}',
      );
      expect(session.root.read(_RevisionedNote.title), 'Changed');
      expect(session.root.initialRecord['version']?.raw, 8);
      expect(session.root.read(_RevisionedNote.version), 9);
      expect(session.isDirty, isFalse);
      expect(session.canLeave, isTrue);

      session.root.set(_RevisionedNote.title, 'Another edit');
      expect(session.isDirty, isTrue);
      expect(session.canLeave, isFalse);
    },
  );

  testWidgets('creating a record with a derived revision invokes onSaved', (
    tester,
  ) async {
    late BeakFormSession session;
    Object? savedId;
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: const _RevisionedNote(),
          dataSource: _RevisionedNoteSource(),
          mode: BeakFormMode.create,
          layout: BeakFormLayout(children: [_RevisionedNote.title.input()]),
          onSession: (value) => session = value,
          onSaved: (id) => savedId = id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    session.root.set(_RevisionedNote.title, 'New record');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      savedId,
      isNotNull,
      reason:
          '${session.saveResult.value?.toJson()} ${session.error.value} ${session.root.errors}',
    );
    expect(session.isDirty, isFalse);
    expect(session.canLeave, isTrue);
    expect(tester.takeException(), isNull);
  });

  test(
    'immutable records can be created and required input stays validated',
    () async {
      final input = _title.input(validate: const [BeakRequired()]);
      final source = FakeDataSource(
        records: {
          'notes': {
            'saved': BeakRecord.fromRow({'id': 'saved', 'title': 'Saved'}),
          },
        },
      );
      final creating = BeakFormSession(
        model: const _ImmutableNoteModel(),
        dataSource: source,
        layout: BeakFormLayout(children: [input]),
      );
      addTearDown(creating.dispose);
      await creating.load();
      expect(creating.root.enabled(input), isTrue);
      expect(await creating.validate(), isFalse);
      creating.root.set(_title, 'New');
      expect(await creating.validate(), isTrue);
      expect(creating.root.buildRecord()['title']?.raw, 'New');

      final editing = BeakFormSession(
        model: const _ImmutableNoteModel(),
        dataSource: source,
        recordId: 'saved',
        layout: BeakFormLayout(children: [input]),
      );
      addTearDown(editing.dispose);
      await editing.load();
      expect(editing.root.enabled(input), isFalse);
      editing.root.set(_title, 'Forged');
      expect(editing.root.buildRecord()['title'], isNull);
    },
  );

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
  test('derived columns hidden from forms remain readable in the draft', () {
    final session = BeakFormSession(
      model: const _HiddenTotalSale(),
      dataSource: FakeDataSource(models: const [_HiddenTotalSale()]),
      layout: BeakFormLayout(children: [_quantity.input(), _price.input()]),
    );
    addTearDown(session.dispose);
    session.root.set(_quantity, 2);
    expect(session.root.snapshot['total']?.raw, 40);
    expect(session.root.buildRecord().values.containsKey('total'), isFalse);
    session.root.set(_price, 7);
    expect(session.root.snapshot['total']?.raw, 14);
  });

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
      _Sale.issue,
      arguments: BeakRecord.fromRow({'reference': 'INV-2'}),
    );
    expect(source.plan?.action, 'issue');
    expect(source.plan?.arguments['reference']?.raw, 'INV-2');
    expect(source.plan?.operations.single.target.id, 's1');
  });
  test('commands the model does not declare are rejected', () async {
    final session = BeakFormSession(
      model: const _Sale(),
      dataSource: _CommandSource(),
      recordId: 's1',
    );
    addTearDown(session.dispose);
    await session.load();
    const foreign = BeakModelAction(name: 'refund', label: 'Refund');
    expect(
      () => session.executeAction(foreign),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      () => session.save(action: foreign),
      throwsA(isA<BeakConfigurationException>()),
    );
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
    expect(await session.executeAction(_Sale.issue), isNull);
    expect(await session.save(action: _Sale.issue), isNull);
    expect(source.plan, isNull);
    expect(session.error.value, isA<BeakAuthorizationException>());
    expect(tester.takeException(), isNull);
  });

  testWidgets('input-free action fallback confirmation is localized', (
    tester,
  ) async {
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        locale: const Locale('de'),
        supportedLocales: BeakLocalizations.supportedLocales,
        localizationsDelegates: const [BeakLocalizations.delegate],
        home: BeakConfiguredForm(
          model: const _Sale(),
          dataSource: _CommandSource(),
          recordId: 's1',
          mode: BeakFormMode.read,
          layout: const BeakFormLayout(
            children: [
              BeakFormActions(actions: [_Sale.issue]),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte bestätigen Sie diese Aktion.'), findsOneWidget);
    expect(find.text('Apply this action to the record?'), findsNothing);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  const translated = BeakModelAction(
    name: 'issue',
    label: 'Issue in English',
    description: 'Confirm issuance in English',
    allowOnCreate: true,
  );
  testWidgets('localized model commands fit narrow form regions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const command = BeakModelAction(
      name: 'issue',
      label: 'Speiseplan veröffentlichen und Benachrichtigungen versenden',
    );
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: Center(
          child: SizedBox(
            width: 220,
            child: BeakConfiguredForm(
              model: const _LocalizedSale(),
              dataSource: _CommandSource(),
              recordId: 's1',
              mode: BeakFormMode.read,
              layout: const BeakFormLayout(
                children: [
                  BeakFormActions(actions: [command]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(command.label), findsOneWidget);
    expect(tester.takeException(), isNull);
    final button = find.byWidgetPredicate(
      (widget) => widget is OiButton && widget.label == command.label,
    );
    expect(tester.getSize(button).width, lessThanOrEqualTo(220));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Beleg jetzt erstellen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'configured action presentation reaches confirmation and dispatch',
    (tester) async {
      final source = _CommandSource();
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakConfiguredForm(
            model: const _LocalizedSale(),
            dataSource: source,
            recordId: 's1',
            mode: BeakFormMode.read,
            layout: const BeakFormLayout(
              children: [
                BeakFormActions(actions: [translated]),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Beleg erstellen'), findsNothing);
      await tester.tap(find.text(translated.label));
      await tester.pumpAndSettle();
      expect(find.text(translated.description!), findsOneWidget);
      await tester.tap(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is OiButton && widget.label == translated.label,
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(source.plan?.action, 'issue');
      expect(source.plan?.arguments.values, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in [const Locale('en'), const Locale('de')]) {
    testWidgets(
      'action modal retains canonical inputs in ${locale.languageCode}',
      (tester) async {
        final source = _CommandSource();
        await tester.pumpWidget(
          OiApp(
            theme: OiThemeData.light(),
            locale: locale,
            supportedLocales: BeakLocalizations.supportedLocales,
            localizationsDelegates: const [BeakLocalizations.delegate],
            home: BeakConfiguredForm(
              model: const _LocalizedSale(withInput: true),
              dataSource: source,
              recordId: 's1',
              mode: BeakFormMode.read,
              layout: const BeakFormLayout(
                children: [
                  BeakFormActions(actions: [translated]),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(translated.label));
        await tester.pumpAndSettle();
        expect(find.text(translated.description!), findsOneWidget);
        expect(find.byType(EditableText), findsOneWidget);
        await tester.tap(find.text(BeakLocalizations(locale).apply));
        await tester.pumpAndSettle();
        expect(source.plan, isNull);
        await tester.enterText(find.byType(EditableText), 'INV-EN');
        await tester.tap(find.text(BeakLocalizations(locale).apply));
        await tester.pumpAndSettle();
        expect(source.plan?.action, 'issue');
        expect(source.plan?.arguments['reference']?.raw, 'INV-EN');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'inline action preserves translated presentation and canonical inputs',
    (tester) async {
      final source = _CommandSource();
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakConfiguredForm(
            model: const _LocalizedSale(withInput: true),
            dataSource: source,
            recordId: 's1',
            mode: BeakFormMode.read,
            layout: const BeakFormLayout(
              children: [BeakFormActionInput(action: translated)],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(translated.label), findsOneWidget);
      expect(find.text(translated.description!), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'INLINE-EN');
      await tester.tap(find.text(translated.label));
      await tester.pumpAndSettle();
      expect(source.plan?.action, 'issue');
      expect(source.plan?.arguments['reference']?.raw, 'INLINE-EN');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'presentation clones cannot override canonical availability or capabilities',
    (tester) async {
      for (final inline in [false, true]) {
        for (final restricted in [false, true]) {
          final source = restricted
              ? _RestrictedCommandSource()
              : _CommandSource();
          await tester.pumpWidget(
            OiApp(
              key: ValueKey('$inline-$restricted'),
              theme: OiThemeData.light(),
              home: BeakConfiguredForm(
                model: _LocalizedSale(withInput: true, available: restricted),
                dataSource: source,
                recordId: 's1',
                mode: BeakFormMode.read,
                layout: BeakFormLayout(
                  children: [
                    if (inline)
                      const BeakFormActionInput(action: translated)
                    else
                      const BeakFormActions(actions: [translated]),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(translated.label), findsNothing);
          expect(source.plan, isNull);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('translated presentation cannot enable an action on create', (
    tester,
  ) async {
    for (final inline in [false, true]) {
      final source = _CommandSource();
      await tester.pumpWidget(
        OiApp(
          key: ValueKey(inline),
          theme: OiThemeData.light(),
          home: BeakConfiguredForm(
            model: const _LocalizedSale(withInput: true),
            dataSource: source,
            mode: BeakFormMode.create,
            layout: BeakFormLayout(
              children: [
                if (inline)
                  const BeakFormActionInput(action: translated)
                else
                  const BeakFormActions(actions: [translated]),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(translated.label), findsNothing);
      expect(source.plan, isNull);
      expect(tester.takeException(), isNull);
    }
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

final class _RevisionedNote extends BeakModel {
  const _RevisionedNote();
  static const title = BeakScalarField<String>(
    model: _RevisionedNote(),
    column: BeakStringColumn(key: 'title', label: 'Title'),
  );
  static const version = BeakScalarField<int>(
    model: _RevisionedNote(),
    column: BeakIntColumn(
      key: 'version',
      label: 'Version',
      visibleOn: {BeakContext.detail},
    ),
  );
  @override
  String get table => 'revisioned_notes';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'Id'),
    title.column,
    version.column,
  ];
  @override
  BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior.derived(
        field: version,
        dependencies: [title],
        resolve: (state) => (state.original(version) ?? 0) + 1,
      ),
    ],
  );
}

final class _RevisionedNoteSource extends FakeDataSource
    implements BeakCommitDataSource {
  _RevisionedNoteSource()
    : super(
        models: const [_RevisionedNote()],
        records: {
          'revisioned_notes': {
            'n1': BeakRecord.fromRow({
              'id': 'n1',
              'title': 'Saved',
              'version': 7,
            }),
          },
        },
      );
  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities(atomicGraph: true);
  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async => BeakSaveResult(
    saveId: plan.saveId,
    mode: BeakSaveMode.atomic,
    outcomes: [
      for (final operation in plan.operations)
        BeakOperationResult(
          id: operation.id,
          status: BeakWriteOutcome.applied,
          resolvedId: operation.target.id ?? 'n2',
          record: BeakRecord.fromRow({
            ...operation.values.toRow(),
            'id': operation.target.id ?? 'n2',
            'version': operation.target.id == null ? 1 : 8,
          }),
        ),
    ],
  );
  @override
  Future<BeakSaveResult> recover(String saveId) => throw UnimplementedError();
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
  static const issue = BeakModelAction(name: 'issue', label: 'Issue');
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
    actions: const [issue],
  );
}

final class _HiddenTotalSale extends BeakModel {
  const _HiddenTotalSale();
  static const total = BeakScalarField<int>(
    model: _HiddenTotalSale(),
    column: BeakIntColumn(
      key: 'total',
      label: 'Total',
      visibleOn: {BeakContext.detail},
    ),
  );
  @override
  String get table => 'sales';
  @override
  String get displayColumnKey => 'quantity';
  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'Id'),
    _quantity.column,
    _price.column,
    total.column,
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
        field: total,
        dependencies: [_quantity, _price],
        resolve: (c) => (c.read(_quantity) ?? 0) * (c.read(_price) ?? 0),
      ),
    ],
  );
}

final class _LocalizedSale extends BeakModel {
  const _LocalizedSale({this.withInput = false, this.available = true});
  final bool withInput, available;
  @override
  String get table => 'sales';
  @override
  String get displayColumnKey => 'quantity';
  @override
  List<BeakColumn> get columns => const _Sale().columns;
  @override
  BeakModelBehavior get behavior => BeakModelBehavior(
    actions: [
      BeakModelAction(
        name: 'issue',
        label: 'Beleg erstellen',
        description: 'Beleg jetzt erstellen',
        availableWhen: (_) => available,
        inputModel: withInput ? const _IssueArguments() : null,
      ),
    ],
  );
}

final class _IssueArguments extends BeakModel {
  const _IssueArguments();
  @override
  String get table => 'issue_arguments';
  @override
  String get displayColumnKey => 'reference';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(
      key: 'reference',
      label: 'Reference',
      rules: [BeakRequired()],
    ),
  ];
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
