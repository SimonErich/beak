import 'dart:io';

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

/// Stores the row, then loses the connection before answering.
final class _LostAnswer extends FakeDataSource {
  @override
  Future<BeakRecord> create(String table, BeakRecord data) async {
    await super.create(table, data);
    throw const SocketException('Connection reset.');
  }
}

/// Refuses to start any commit, and keeps its receipts in memory only.
final class _NeverStarts extends FakeDataSource
    implements BeakCommitDataSource {
  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities();

  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) =>
      throw const BeakConfigurationException('Broken before it started.');

  @override
  Future<BeakSaveResult> recover(String saveId) =>
      throw const BeakNotFoundException('No receipt.');
}

void main() {
  BeakFormSession open(FakeDataSource source, BeakFormDrafts? drafts) =>
      BeakFormSession(
        model: const NoteModel(),
        dataSource: source,
        layout: BeakFormLayout(children: [_title.inputText()]),
        drafts: drafts,
      );

  test('a reload cannot tell "never sent" from "sent, receipt gone"', () async {
    final config = BeakFormDrafts(
      store: BeakMemoryDraftStore(),
      key: 'note',
      context: 'reader',
    );
    final source = _LostAnswer();
    final first = open(source, config);
    await first.load();
    first.root.set(_title, 'Once');
    await first.save();
    expect(first.hasUnknown, isTrue);
    expect(source.store.rowsOf('notes'), hasLength(1));
    first.dispose();

    final second = open(source, config);
    addTearDown(second.dispose);
    await second.load();

    // The row exists. Calling the save "not received" would invite a duplicate.
    expect(second.hasUnknown, isTrue);
    expect(second.refusedAsConflict, isFalse);
    expect(second.receiptLost, isTrue);
    expect(second.saveResult.value?.outcomes.first.reason, 'receiptLost');
    expect(await second.save(), same(second.saveResult.value));
    expect(source.store.rowsOf('notes'), hasLength(1));

    await second.discardChanges();
    expect(second.hasUnknown, isFalse);
    final third = open(source, config);
    addTearDown(third.dispose);
    await third.load();
    expect(third.hasUnknown, isFalse);
    expect(third.hasStoredDraft, isFalse);
  });

  testWidgets('the form says so and lets the user discard the edits', (
    tester,
  ) async {
    final config = BeakFormDrafts(
      store: BeakMemoryDraftStore(),
      key: 'note',
      context: 'reader',
    );
    final source = _LostAnswer();
    final first = open(source, config);
    await first.load();
    first.root.set(_title, 'Once');
    await first.save();
    first.dispose();

    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: const NoteModel(),
          dataSource: source,
          layout: BeakFormLayout(children: [_title.inputText()]),
          drafts: config,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('keeps receipts in memory only'),
      findsOneWidget,
    );
    expect(find.text('Check save status'), findsOneWidget);
    OiButton save(String label) =>
        tester.widget(find.widgetWithText(OiButton, label));
    expect(save('Save remaining changes').onTap, isNull);

    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();

    expect(find.textContaining('keeps receipts in memory only'), findsNothing);
    expect(find.text('Check save status'), findsNothing);
    expect(save('Save').onTap, isNotNull);
  });

  test('a save this page never got out is still free to send again', () async {
    final source = _NeverStarts();
    final session = open(source, null);
    addTearDown(session.dispose);
    await session.load();
    session.root.set(_title, 'Again');
    await session.save();
    expect(session.hasUnknown, isTrue);

    await session.recover();

    expect(session.hasUnknown, isFalse);
    expect(session.saveResult.value?.outcomes.first.reason, 'notReceived');
    expect(session.receiptLost, isFalse);
  });
}
