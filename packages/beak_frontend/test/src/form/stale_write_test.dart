import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _staleMessage = 'The record changed since it was loaded.';

/// A server that refuses every write as stale: an unapplied receipt whose error
/// carries the `conflict` code, exactly as the graph commit endpoint answers a
/// failed `expectedUpdatedAt` check.
final class _StaleSource extends FakeDataSource
    implements BeakCommitDataSource {
  _StaleSource()
    : super(
        records: {
          'notes': {
            'n1': BeakRecord.fromRow(const {'id': 'n1', 'title': 'One'}),
          },
        },
      );

  int commits = 0;

  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities();

  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    commits++;
    return BeakSaveResult(
      saveId: plan.saveId,
      mode: BeakSaveMode.staged,
      outcomes: [
        for (final operation in plan.operations)
          BeakOperationResult(
            id: operation.id,
            status: BeakWriteOutcome.unapplied,
            reason: 'rejected',
            error: BeakSaveError(code: 'conflict', message: _staleMessage),
          ),
      ],
    );
  }

  @override
  Future<BeakSaveResult> recover(String saveId) =>
      throw const BeakNotFoundException('No receipt.');
}

void main() {
  Future<void> pumpEdit(WidgetTester tester, FakeDataSource source) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: const NoteModel(),
          dataSource: source,
          recordId: 'n1',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a stale write offers the merge instead of a doomed retry', (
    tester,
  ) async {
    final source = _StaleSource();
    await pumpEdit(tester, source);
    await tester.enterText(find.byType(EditableText).first, 'Mine');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(source.commits, 1);
    expect(find.text(_staleMessage), findsOneWidget);
    expect(find.text('Compare with latest version'), findsOneWidget);

    await source.update(
      'notes',
      'n1',
      BeakRecord.fromRow(const {'id': 'n1', 'title': 'Theirs'}),
    );
    await tester.tap(find.text('Compare with latest version'));
    await tester.pumpAndSettle();

    expect(find.text('Your draft: Mine'), findsOneWidget);
    expect(find.text('Latest version: Theirs'), findsOneWidget);
    // The refusal belongs to the version that was just replaced.
    expect(find.text(_staleMessage), findsNothing);
    expect(find.text('Compare with latest version'), findsNothing);
  });

  testWidgets('a refusal that is not a stale write offers no merge', (
    tester,
  ) async {
    final source = _RefusingSource();
    await pumpEdit(tester, source);
    await tester.enterText(find.byType(EditableText).first, 'Mine');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Not allowed.'), findsOneWidget);
    expect(find.text('Compare with latest version'), findsNothing);
  });
}

/// Refuses every write for a reason a newer version would not change.
final class _RefusingSource extends _StaleSource {
  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async => BeakSaveResult(
    saveId: plan.saveId,
    mode: BeakSaveMode.staged,
    outcomes: [
      for (final operation in plan.operations)
        BeakOperationResult(
          id: operation.id,
          status: BeakWriteOutcome.unapplied,
          reason: 'rejected',
          error: BeakSaveError(code: 'authorization', message: 'Not allowed.'),
        ),
    ],
  );
}
