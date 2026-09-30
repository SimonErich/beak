import 'dart:convert';

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
  for (final (width, resume) in [(320.0, true), (390.0, false)]) {
    testWidgets(
      'stored draft actions fit at $width and ${resume ? 'resume' : 'discard'}',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final store = BeakMemoryDraftStore();
        final drafts = BeakFormDrafts(
          store: store,
          key: 'narrow',
          context: 'test',
          debounce: const Duration(hours: 1),
        );
        final steps = [
          BeakWizardStep(title: 'Basics', children: [_title.inputText()]),
        ];
        final original = BeakFormSession(
          model: const NoteModel(),
          dataSource: FakeDataSource(),
          drafts: drafts,
          steps: steps,
        );
        await original.load();
        original.root.set(_title, 'Previous draft');
        expect(await original.persistDraft(), isTrue);
        original.dispose();
        late BeakFormSession session;
        final theme = OiThemeData.light();
        await tester.pumpWidget(
          OiApp(
            // Ahem has square glyphs. Keep each action narrower than the card;
            // their combined width must still wrap at both tested viewports.
            theme: theme.copyWith(
              components: theme.components.copyWith(
                button: const OiButtonThemeData(
                  textStyle: TextStyle(fontSize: 7),
                ),
              ),
            ),
            home: BeakConfiguredForm(
              model: const NoteModel(),
              dataSource: FakeDataSource(),
              drafts: drafts,
              steps: steps,
              navigation: BeakWizardNavigation.rail,
              onSession: (value) => session = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final card = find.ancestor(
          of: find.text('An unfinished draft is available'),
          matching: find.byType(OiCard),
        );
        final bounds = tester.getRect(card);
        for (final label in ['Resume draft', 'Discard saved draft']) {
          final action = find.byWidgetPredicate(
            (widget) => widget is OiButton && widget.label == label,
          );
          final actionBounds = tester.getRect(action);
          expect(actionBounds.left, greaterThanOrEqualTo(bounds.left));
          expect(actionBounds.right, lessThanOrEqualTo(bounds.right));
        }
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.text(resume ? 'Resume draft' : 'Discard saved draft'),
        );
        await tester.pumpAndSettle();
        expect(session.hasStoredDraft, isFalse);
        expect(session.root.read(_title), resume ? 'Previous draft' : null);
        expect(find.text('An unfinished draft is available'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'rail heading is separate from navigation and retains the draft',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late BeakFormSession session;
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakConfiguredForm(
            model: const NoteModel(),
            dataSource: FakeDataSource(),
            navigation: BeakWizardNavigation.rail,
            onSession: (value) => session = value,
            steps: [
              BeakWizardStep(
                title: 'Basics',
                description: 'Short rail guidance',
                heading: 'Who is this note for?',
                introduction: 'A longer explanation above the inputs.',
                children: [
                  BeakFormWidget(
                    builder: (_, _) => const SizedBox(height: 1000),
                  ),
                  _title.inputText(),
                ],
              ),
              const BeakWizardStep(title: 'Review', children: []),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final heading = tester.getRect(find.text('Who is this note for?'));
      final wizard = tester.widget<OiWizardLayout>(find.byType(OiWizardLayout));
      expect(wizard.steps.first.title, 'Basics');
      expect(wizard.steps.first.description, 'Short rail guidance');
      await tester.ensureVisible(find.byType(EditableText));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Persistent value');
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Who is this note for?')), heading);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(session.currentStep, 1);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(session.root.read(_title), 'Persistent value');
      expect(tester.getRect(find.text('Who is this note for?')), heading);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('completed rail details follow edits and use panel formatting', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakFormattingScope(
          formatting: const BeakFormatting(currency: 'EUR'),
          child: BeakConfiguredForm(
            model: const NoteModel(),
            dataSource: FakeDataSource(),
            navigation: BeakWizardNavigation.rail,
            steps: [
              BeakWizardStep(
                title: 'Basics',
                description: 'Enter a name',
                completedDescription: (state, format) =>
                    '${state.read(_title)} · ${format.currency(12)}',
                footerHint: 'The name is shared with the next step.',
                children: [_title.inputText()],
              ),
              const BeakWizardStep(
                title: 'Review',
                footerHint: 'Check the name before saving.',
                children: [],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('The name is shared with the next step.'), findsOneWidget);
    OiWizardLayout wizard() => tester.widget(find.byType(OiWizardLayout));
    expect(wizard().steps.first.description, 'Enter a name');
    await tester.enterText(find.byType(EditableText), 'Dinner');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(wizard().steps.first.description, 'Dinner · €12.00');
    expect(find.text('Check the name before saving.'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Lunch');
    await tester.pumpAndSettle();
    expect(wizard().steps.first.description, 'Lunch · €12.00');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'draft header shows automatic successful writes, never clean removal',
    (tester) async {
      final store = BeakMemoryDraftStore();
      final drafts = BeakFormDrafts(
        store: store,
        key: 'header',
        context: 'test',
      );
      late BeakFormSession session;
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakConfiguredForm(
            model: const NoteModel(),
            dataSource: FakeDataSource(),
            drafts: drafts,
            header: const BeakFormHeader(title: 'New note'),
            layout: BeakFormLayout(children: [_title.inputText()]),
            onSession: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save as draft'));
      await tester.pumpAndSettle();
      expect(session.draftSavedAt, isNull);
      expect(find.textContaining('Draft saved'), findsNothing);
      await tester.enterText(find.byType(EditableText), 'Saved automatically');
      await tester.pump(drafts.debounce + const Duration(milliseconds: 10));
      await tester.pumpAndSettle();
      final document =
          jsonDecode((await store.read(drafts.storageKey('notes', null)))!)
              as Map<String, Object?>;
      expect(
        session.draftSavedAt,
        DateTime.parse(document['savedAt']! as String),
      );
      expect(find.textContaining('Draft saved'), findsOneWidget);
      await session.discardStoredDraft();
      await tester.pumpAndSettle();
      expect(session.draftSavedAt, isNull);
      expect(find.textContaining('Draft saved'), findsNothing);
    },
  );

  test(
    'timestamp belongs to resumed or successfully written drafts only',
    () async {
      final store = _Store();
      final config = BeakFormDrafts(
        store: store,
        key: 'restore',
        context: 'test',
        debounce: const Duration(hours: 1),
      );
      BeakFormSession make() => BeakFormSession(
        model: const NoteModel(),
        dataSource: FakeDataSource(),
        drafts: config,
        layout: BeakFormLayout(children: [_title.inputText()]),
      );
      final first = make();
      addTearDown(first.dispose);
      await first.load();
      first.root.set(_title, 'Previous draft');
      store.fail = true;
      expect(await first.persistDraft(), isFalse);
      expect(first.draftSavedAt, isNull);
      store.fail = false;
      expect(await first.persistDraft(), isTrue);
      final writtenAt = first.draftSavedAt;
      expect(writtenAt, isNotNull);
      final resumed = make();
      addTearDown(resumed.dispose);
      await resumed.load();
      expect(resumed.hasStoredDraft, isTrue);
      expect(resumed.draftSavedAt, isNull);
      resumed.resumeDraft();
      expect(resumed.draftSavedAt, writtenAt);
      expect(resumed.root.read(_title), 'Previous draft');
    },
  );
}

final class _Store implements BeakDraftStore {
  final BeakMemoryDraftStore delegate = BeakMemoryDraftStore();
  bool fail = false;
  @override
  Future<String?> read(String key) => delegate.read(key);
  @override
  Future<void> remove(String key) => delegate.remove(key);
  @override
  Future<void> write(String key, String document) async {
    if (fail) throw StateError('Unavailable');
    await delegate.write(key, document);
  }
}
