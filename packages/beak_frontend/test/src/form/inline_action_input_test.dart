import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';
import '../../support/panel_fixtures.dart';

const _body = BeakScalarField<String>(
  model: _Arguments(),
  column: _Arguments.body,
);
const _title = BeakScalarField<String>(model: _Model(), column: _Model.title);
final _layout = BeakFormLayout(
  children: [
    _title.inputText(),
    BeakFormActionInput(
      name: 'note',
      submitWithForm: 'amend',
      optionalWithForm: true,
      layout: BeakFormLayout(children: [_body.inputText(maxLines: 3)]),
    ),
  ],
);
BeakFormSession _session(_Source source, {BeakFormDrafts? drafts}) =>
    BeakFormSession(
      model: const _Model(),
      dataSource: source,
      recordId: 'one',
      layout: _layout,
      drafts: drafts,
    );
void main() {
  testWidgets(
    'persisted edit markers follow draft changes and action arguments',
    (tester) async {
      final source = _Source();
      late BeakFormSession session;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakConfiguredForm(
            model: const _Model(),
            dataSource: source,
            recordId: 'one',
            header: const BeakFormLayout(children: []),
            aside: const BeakFormLayout(children: []),
            onSession: (value) => session = value,
            layout: BeakFormLayout(
              showChangeIndicators: true,
              children: _layout.children,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Title: Modified'), findsNothing);
      final editor = find.byType(EditableText).first;
      await tester.tap(editor);
      await tester.pumpAndSettle();
      final focus = tester.widget<EditableText>(editor).focusNode;
      expect(focus.hasFocus, isTrue);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Ch',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        identical(tester.widget<EditableText>(editor).focusNode, focus),
        isTrue,
      );
      expect(
        tester.widget<EditableText>(editor).controller.value.composing,
        const TextRange(start: 0, end: 2),
      );
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Changed',
          selection: TextSelection.collapsed(offset: 7),
          composing: TextRange(start: 2, end: 7),
        ),
      );
      session.actionInput('note').root.set(_body, 'New note');
      await tester.pumpAndSettle();
      expect(
        identical(tester.widget<EditableText>(editor).focusNode, focus),
        isTrue,
      );
      expect(focus.hasFocus, isTrue);
      expect(session.root.read(_title), 'Changed');
      expect(
        tester.widget<EditableText>(editor).controller.value.selection,
        const TextSelection.collapsed(offset: 7),
      );
      expect(
        tester.widget<EditableText>(editor).controller.value.composing,
        const TextRange(start: 2, end: 7),
      );
      expect(session.root.fieldChanged(_title), isTrue);
      expect(find.bySemanticsLabel('Title: Modified'), findsOneWidget);
      expect(find.bySemanticsLabel('New note: Modified'), findsOneWidget);
      session.root.set(_title, 'Before');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Title: Modified'), findsNothing);
      await session.discardChanges();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('New note: Modified'), findsNothing);
      expect(source.plans, isEmpty);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
  testWidgets(
    'scaffold compact heading leaves the persisted error editor and pinned footer reachable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = _Source();
      late BeakFormSession session;
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakConfiguredForm(
            model: const _Model(),
            dataSource: source,
            recordId: 'one',
            showChangeBar: true,
            compactActions: true,
            onSession: (value) => session = value,
            header: BeakFormLayout(
              children: [
                BeakFormNotice(
                  title: 'The kitchen and driver see changes immediately.',
                  message: (_) => 'Items can change until 10:30.',
                  inline: true,
                ),
                BeakFormMetrics(
                  metrics: [
                    for (final label in [
                      'Total',
                      'Delivery',
                      'Payment',
                      'Profile',
                      'Budget left',
                    ])
                      BeakFormMetric(
                        label: label,
                        value: (_) => 'Current value',
                      ),
                  ],
                ),
              ],
            ),
            layout: BeakFormLayout(
              children: [
                const BeakFormPlaceholder(
                  label: 'Earlier content',
                  height: 900,
                ),
                _title.inputText(
                  label: 'Delivery phone',
                  validate: const [BeakRequired()],
                ),
              ],
            ),
            frameBuilder: (_, _, _, actions, child) => Column(
              children: [
                const SizedBox(height: 64, child: Text('Workspace toolbar')),
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, constraints) => Row(
                      children: [
                        if (constraints.maxWidth >= 600)
                          const SizedBox(width: 320, child: Text('Navigation')),
                        Expanded(
                          child: BeakPageScaffold(
                            resource: const BeakResource(model: _Model()),
                            variant: OiResourcePageVariant.edit,
                            surface: false,
                            showBack: false,
                            title: 'ORD-24817',
                            heading: const SizedBox(
                              height: 120,
                              child: Text('ORD-24817 — record identity'),
                            ),
                            actions: [actions],
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      session.root.set(_title, '');
      expect(await session.validate(), isFalse);
      await tester.pumpAndSettle();
      final issue = find.byWidgetPredicate(
        (widget) =>
            widget is OiTappable &&
            widget.semanticLabel == '1 field needs attention',
      );
      final editor = find.byType(EditableText);
      for (final size in [
        const Size(375, 812),
        const Size(812, 375),
        const Size(1180, 375),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpAndSettle();
        final footer = find.widgetWithText(OiButton, 'Discard changes');
        expect(tester.getRect(footer).bottom, lessThanOrEqualTo(size.height));
        await tester.tap(issue);
        await tester.pumpAndSettle();
        expect(tester.widget<EditableText>(editor).focusNode.hasFocus, isTrue);
        expect(tester.getRect(editor).top, greaterThanOrEqualTo(64));
        expect(
          tester.getRect(editor).bottom,
          lessThan(tester.getRect(footer).top),
        );
        expect(session.root.read(_title), '');
        expect(session.validationIssueCount, 1);
        expect(session.isDirty, isTrue);
        expect(tester.takeException(), isNull);
      }
      expect(source.plans, isEmpty);
    },
  );
  testWidgets(
    'unsaved bar summarizes, reveals errors by keyboard and saves or discards the shared draft',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = _Source();
      late BeakFormSession session;
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakConfiguredForm(
            model: const _Model(),
            dataSource: source,
            recordId: 'one',
            showChangeBar: true,
            onSession: (value) => session = value,
            header: BeakFormLayout(
              children: [
                BeakFormNotice(
                  title: 'The kitchen and driver see changes immediately.',
                  message: (_) => 'Items can change until 10:30.',
                  inline: true,
                ),
                BeakFormMetrics(
                  metrics: [
                    for (final label in [
                      'Total',
                      'Delivery',
                      'Payment',
                      'Profile',
                      'Budget left',
                    ])
                      BeakFormMetric(
                        label: label,
                        value: (_) => 'Current value',
                      ),
                  ],
                ),
              ],
            ),
            layout: BeakFormLayout(
              children: [
                const BeakFormPlaceholder(
                  label: 'Earlier content',
                  height: 900,
                ),
                _title.inputText(
                  label: 'Delivery phone',
                  validate: const [BeakRequired()],
                ),
              ],
            ),
            frameBuilder: (_, _, _, actions, child) => Column(
              children: [
                actions,
                Expanded(child: child),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      session.root.set(_title, '');
      expect(await session.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('1 unsaved change'), findsOneWidget);
      expect(find.text('Delivery phone'), findsWidgets);
      expect(session.reviewChangeSummary, 'Delivery phone');
      final issue = find.byWidgetPredicate(
        (widget) =>
            widget is OiTappable &&
            widget.semanticLabel == '1 field needs attention',
      );
      expect(issue, findsOneWidget);
      expect(
        tester.getRect(issue).left,
        lessThanOrEqualTo(
          tester.getRect(find.text('1 unsaved change')).right + 324,
        ),
      );
      expect(
        tester.getRect(issue).right,
        lessThan(
          tester.getRect(find.widgetWithText(OiButton, 'Discard changes')).left,
        ),
      );
      final issueWidget = tester.widget<OiTappable>(issue);
      final issueFocus = FocusManager.instance.rootScope.traversalDescendants
          .firstWhere(
            (node) => identical(
              node.context?.findAncestorWidgetOfExactType<OiTappable>(),
              issueWidget,
            ),
          );
      issueFocus.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final editor = find.byType(EditableText);
      expect(tester.widget<EditableText>(editor).focusNode.hasFocus, isTrue);
      expect(
        tester.getRect(editor).bottom,
        lessThan(
          tester.getRect(find.widgetWithText(OiButton, 'Discard changes')).top,
        ),
      );
      for (final size in [const Size(375, 812), const Size(812, 375)]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpAndSettle();
        await tester.tap(issue);
        await tester.pumpAndSettle();
        expect(tester.widget<EditableText>(editor).focusNode.hasFocus, isTrue);
        expect(
          tester.getRect(editor).bottom,
          lessThan(
            tester
                .getRect(find.widgetWithText(OiButton, 'Discard changes'))
                .top,
          ),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(const Size(1100, 700));
      await tester.pumpAndSettle();
      await tester.enterText(editor, 'Saved phone');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OiButton, 'Save').last);
      await tester.pumpAndSettle();
      expect(source.plans, hasLength(1));
      expect(session.isDirty, isFalse);
      expect(find.text('1 unsaved change'), findsNothing);
      await tester.ensureVisible(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      session.root.set(_title, 'Discard this');
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(320, 700));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(OiButton, 'Discard changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OiButton, 'Discard changes').last);
      await tester.pumpAndSettle();
      expect(session.root.read(_title), 'Saved phone');
      expect(session.isDirty, isFalse);
      expect(source.plans, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unsaved bar is available without an external frame', (
    tester,
  ) async {
    late BeakFormSession session;
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: const _Model(),
          dataSource: _Source(),
          recordId: 'one',
          showChangeBar: true,
          onSession: (value) => session = value,
          layout: BeakFormLayout(children: [_title.inputText(label: 'Title')]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    session.root.set(_title, 'Changed');
    await tester.pumpAndSettle();
    expect(find.text('1 unsaved change'), findsOneWidget);
    expect(find.widgetWithText(OiButton, 'Discard changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error reveal activates an invalid field in a hidden local tab', (
    tester,
  ) async {
    late BeakFormSession session;
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: const _Model(),
          dataSource: _Source(),
          recordId: 'one',
          showChangeBar: true,
          onSession: (value) => session = value,
          layout: BeakFormLayout(
            children: [
              BeakTabs(
                tabs: [
                  BeakTab(
                    title: 'First',
                    children: [
                      _title.inputText(
                        label: 'Hidden phone',
                        validate: const [BeakRequired()],
                      ),
                    ],
                  ),
                  BeakTab(
                    title: 'Second',
                    children: [BeakCalculated(value: (_) => 'Other content')],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    session.root.set(_title, '');
    expect(await session.validate(), isFalse);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsNothing);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is OiTappable &&
            widget.semanticLabel == '1 field needs attention',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  for (final scenario in ['default', 'create', 'readOnly', 'permission']) {
    testWidgets('change markers respect $scenario context', (tester) async {
      final source = _Source()..denyTitle = scenario == 'permission';
      late BeakFormSession session;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakConfiguredForm(
            model: const _Model(),
            dataSource: source,
            recordId: scenario == 'create' ? null : 'one',
            onSession: (value) => session = value,
            layout: BeakFormLayout(
              showChangeIndicators: scenario != 'default',
              children: [
                BeakInput(field: _title, readOnly: scenario == 'readOnly'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      session.root.set(_title, 'Changed');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Title: Modified'), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  for (final stale in ['cleared', 'removed']) {
    testWidgets('error reveal ignores an editor $stale during scrolling', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var visible = true;
      late BeakFormSession session;
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakConfiguredForm(
            model: const _Model(),
            dataSource: _Source(),
            recordId: 'one',
            showChangeBar: true,
            onSession: (value) => session = value,
            layout: BeakFormLayout(
              children: [
                const BeakFormPlaceholder(
                  label: 'Earlier content',
                  height: 900,
                ),
                BeakInput(
                  field: _title,
                  visibleIf: (_) => visible,
                  validate: const [BeakRequired()],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      session.root.set(_title, '');
      expect(await session.validate(), isFalse);
      await tester.pumpAndSettle();
      final focus = tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode;
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is OiTappable &&
              widget.semanticLabel == '1 field needs attention',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      if (stale == 'removed') visible = false;
      session.root.set(_title, 'Resolved');
      await session.validate();
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  test('discard resets fields and staged arguments without writing', () async {
    final source = _Source();
    final session = _session(source);
    addTearDown(session.dispose);
    await session.load();
    final original = session.root.read(_title);
    session.root.set(_title, 'Unsent title');
    session.actionInput('note').root.set(_body, 'Unsent note');
    expect(session.isDirty, isTrue);
    await session.discardChanges();
    expect(session.root.read(_title), original);
    expect(session.actionInput('note').root.read(_body), isNull);
    expect(session.isDirty, isFalse);
    expect(session.canLeave, isTrue);
    expect(source.plans, isEmpty);
  });

  test(
    'unknown saves retain staged arguments when discard is requested',
    () async {
      final source = _Source()..unknown = true;
      final session = _session(source);
      addTearDown(session.dispose);
      await session.load();
      session.actionInput('note').root.set(_body, 'Recover this note');
      await session.executeAction(
        'amend',
        arguments: (await session.actionArguments('amend'))!,
      );
      expect(session.hasUnknown, isTrue);
      await session.discardChanges();
      expect(session.actionInput('note').root.read(_body), 'Recover this note');
      expect(session.hasUnknown, isTrue);
    },
  );

  testWidgets(
    'full-region tabs align the aside and keep the shared draft across navigation',
    (tester) async {
      final source = _Source();
      late BeakFormSession session;
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakConfiguredForm(
            model: const _Model(),
            dataSource: source,
            recordId: 'one',
            onSession: (value) => session = value,
            frameBuilder: (_, _, _, _, body) => body,
            aside: BeakFormLayout(
              children: [BeakCalculated(value: (_) => 'Aside')],
            ),
            layout: BeakFormLayout(
              children: [
                BeakTabs(
                  acrossRegions: true,
                  tabs: [
                    BeakTab(title: 'First', children: [_title.inputText()]),
                    BeakTab(
                      title: 'Second',
                      children: [
                        BeakCalculated(value: (state) => state.read(_title)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OiTabs), findsOneWidget);
      expect(tester.getSize(find.byType(OiTabs)).width, 1200);
      expect(
        tester.getTopLeft(find.text('Aside')).dy,
        greaterThan(tester.getBottomLeft(find.text('First')).dy),
      );
      session.root.set(_title, 'Shared draft');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(find.text('Shared draft'), findsOneWidget);
      expect(session.root.read(_title), 'Shared draft');
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'inline arguments validate, guard navigation, and clear only on a complete command',
    () async {
      final source = _Source();
      final session = _session(source);
      addTearDown(session.dispose);
      await session.load();
      expect(session.isDirty, isFalse);
      expect(await session.actionArguments('note'), isNull);
      expect((await session.actionArguments('amend'))!.values, isEmpty);
      final input = session.actionInput('note');
      input.root.set(_body, 'New note');
      expect(session.isDirty, isTrue);
      expect(session.canLeave, isFalse);
      source.fail = true;
      await session.executeAction(
        'note',
        arguments: (await session.actionArguments('note'))!,
      );
      expect(input.root.read(_body), 'New note');
      expect(session.canLeave, isFalse);
      source.fail = false;
      final result = await session.executeAction(
        'note',
        arguments: (await session.actionArguments('note'))!,
      );
      expect(result?.complete, isTrue);
      expect(input.root.read(_body), isNull);
      expect(session.isDirty, isFalse);
      expect(session.canLeave, isTrue);
      expect(source.plans.last.arguments['body']?.raw, 'New note');
    },
  );
  test(
    'unrelated completed commands retain unsent inline arguments and navigation guard',
    () async {
      final source = _Source();
      final session = _session(source);
      addTearDown(session.dispose);
      await session.load();
      session.actionInput('note').root.set(_body, 'Unsent note');
      expect((await session.executeAction('other'))?.complete, isTrue);
      expect(session.actionInput('note').root.read(_body), 'Unsent note');
      expect(session.isDirty, isTrue);
      expect(session.canLeave, isFalse);
      expect(
        session.reviewChanges.any(
          (change) => change.path == 'action:note.body',
        ),
        isTrue,
      );
    },
  );
  test(
    'inline notes resume with durable drafts and recover without duplicate commits',
    () async {
      final source = _Source();
      final drafts = BeakFormDrafts(
        store: BeakMemoryDraftStore(),
        key: 'order',
        context: 'test',
      );
      final original = _session(source, drafts: drafts);
      await original.load();
      original.actionInput('note').root.set(_body, 'Remember');
      expect(await original.persistDraft(), isTrue);
      original.dispose();
      final resumed = _session(source, drafts: drafts);
      addTearDown(resumed.dispose);
      await resumed.load();
      expect(resumed.hasStoredDraft, isTrue);
      resumed.resumeDraft();
      expect(resumed.actionInput('note').root.read(_body), 'Remember');
      expect(resumed.isDirty, isTrue);
      source.unknown = true;
      await resumed.executeAction(
        'amend',
        arguments: (await resumed.actionArguments('amend'))!,
      );
      expect(resumed.hasUnknown, isTrue);
      expect(resumed.actionInput('note').root.read(_body), 'Remember');
      await resumed.recover();
      expect(source.plans, hasLength(1));
      expect(resumed.actionInput('note').root.read(_body), isNull);
      expect(resumed.canLeave, isTrue);
    },
  );
  testWidgets(
    'read inline action has no dialog and edit primary shares its arguments',
    (tester) async {
      final source = _Source();
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late BeakFormSession session;
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakConfiguredForm(
            model: const _Model(),
            dataSource: source,
            recordId: 'one',
            layout: _layout,
            mode: BeakFormMode.read,
            submitAction: 'amend',
            onSession: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'Inline');
      await tester.tap(find.text('Add note'));
      await tester.pumpAndSettle();
      expect(source.plans.single.action, 'note');
      expect(find.byType(OiDialog), findsNothing);
      expect(session.isDirty, isFalse);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Add note'), findsNothing);
      session.actionInput('note').root.set(_body, 'With edit');
      session.root.set(_title, 'Changed');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amend'));
      await tester.pumpAndSettle();
      expect(source.plans.last.action, 'amend');
      expect(source.plans.last.arguments['body']?.raw, 'With edit');
      expect(
        source.plans.last.operations.first.values['title']?.raw,
        'Changed',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

final class _Model extends BeakModel {
  const _Model();
  static const title = BeakStringColumn(key: 'title', label: 'Title');
  @override
  String get table => 'inline_orders';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    title,
  ];
  @override
  BeakModelBehavior get behavior => const BeakModelBehavior(
    actions: [
      BeakModelAction(
        name: 'note',
        label: 'Add note',
        inputModel: _Arguments(),
      ),
      BeakModelAction(name: 'other', label: 'Other action'),
      BeakModelAction(name: 'amend', label: 'Amend', inputModel: _Arguments()),
    ],
  );
}

final class _Arguments extends BeakModel {
  const _Arguments();
  static const body = BeakStringColumn(
    key: 'body',
    label: 'New note',
    rules: [BeakRequired(), BeakMaxLength(20)],
  );
  @override
  String get table => 'inline_arguments';
  @override
  String get displayColumnKey => 'body';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    body,
  ];
}

final class _Source extends FakeDataSource
    implements BeakCommitDataSource, BeakCapabilityDataSource {
  _Source()
    : super(
        models: const [_Model()],
        records: {
          'inline_orders': {
            'one': BeakRecord.fromRow({'id': 'one', 'title': 'Before'}),
          },
        },
      );
  bool fail = false, unknown = false;
  bool denyTitle = false;
  @override
  Future<BeakAccessCapabilities> capabilities(
    String table, {
    Object? id,
  }) async =>
      BeakAccessCapabilities(writableFields: denyTitle ? const {} : null);
  final plans = <BeakSavePlan>[];
  late BeakSaveResult receipt;
  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities(atomicGraph: true);
  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    plans.add(plan);
    if (fail) {
      return BeakSaveResult(
        saveId: plan.saveId,
        mode: BeakSaveMode.atomic,
        outcomes: [
          for (final op in plan.operations)
            BeakOperationResult(id: op.id, status: BeakWriteOutcome.unapplied),
        ],
      );
    }
    final record = await update(
      'inline_orders',
      'one',
      plan.operations.first.values,
    );
    receipt = BeakSaveResult(
      saveId: plan.saveId,
      mode: BeakSaveMode.atomic,
      outcomes: [
        for (final op in plan.operations)
          BeakOperationResult(
            id: op.id,
            status: BeakWriteOutcome.applied,
            resolvedId: 'one',
            record: record,
          ),
      ],
    );
    if (!unknown) return receipt;
    return BeakSaveResult(
      saveId: plan.saveId,
      mode: BeakSaveMode.atomic,
      outcomes: [
        for (final op in plan.operations)
          BeakOperationResult(id: op.id, status: BeakWriteOutcome.unknown),
      ],
    );
  }

  @override
  Future<BeakSaveResult> recover(String saveId) async => receipt;
}
