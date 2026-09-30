import 'dart:io';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

final class _Memo extends BeakModel {
  const _Memo();
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    rules: [BeakRequired()],
  );
  @override
  String get table => 'memos';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    title,
  ];
}

const _title = BeakScalarField<String>(model: _Memo(), column: _Memo.title);

/// A commit endpoint whose failures the test scripts.
final class _FailingSource extends FakeDataSource
    implements BeakCommitDataSource {
  _FailingSource({required this.commitFailure, this.recoverFailure});

  Object commitFailure;
  Object? recoverFailure;
  int commits = 0;
  int recoveries = 0;

  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities(durableReceipts: true);

  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    commits++;
    throw commitFailure;
  }

  @override
  Future<BeakSaveResult> recover(String saveId) async {
    recoveries++;
    throw recoverFailure!;
  }
}

BeakFormSession _session(_FailingSource source) {
  final session = BeakFormSession(
    model: const _Memo(),
    dataSource: source,
    layout: BeakFormLayout(children: [_title.inputText()]),
  );
  addTearDown(session.dispose);
  return session;
}

void main() {
  test('a 422 rejection leaves the form editable and discardable', () async {
    final source = _FailingSource(
      commitFailure: const BeakValidationException(
        'Invalid or oversized save plan.',
      ),
    );
    final session = _session(source);
    await session.load();
    session.root.set(_title, 'Lunch');

    final receipt = await session.save();

    expect(receipt?.hasUnknown, isFalse);
    expect(session.hasUnknown, isFalse);
    expect(
      receipt?.outcomes.single.error?.message,
      'Invalid or oversized save plan.',
    );
    expect(session.isDirty, isTrue);
    await session.discardChanges();
    expect(session.root.read(_title), isNull);
    expect(session.saveResult.value, isNull);
  });

  test('a rejection can be retried under a new save identity', () async {
    final source = _FailingSource(
      commitFailure: const BeakPayloadTooLargeException('Too large.'),
    );
    final session = _session(source);
    await session.load();
    session.root.set(_title, 'Lunch');

    final first = await session.save();
    final second = await session.save();

    expect(source.commits, 2);
    expect(first?.saveId, isNot(second?.saveId));
  });

  test('a lost connection stays unknown and blocks discard', () async {
    final source = _FailingSource(
      commitFailure: const SocketException('Connection reset.'),
    );
    final session = _session(source);
    await session.load();
    session.root.set(_title, 'Lunch');

    final receipt = await session.save();

    expect(receipt?.hasUnknown, isTrue);
    expect(session.hasUnknown, isTrue);
    await session.discardChanges();
    expect(session.root.read(_title), 'Lunch');
  });

  test('recovery with no stored receipt resolves to never received', () async {
    final source = _FailingSource(
      commitFailure: const BeakInternalException('Bad gateway.'),
      recoverFailure: const BeakNotFoundException('No receipt.'),
    );
    final session = _session(source);
    await session.load();
    session.root.set(_title, 'Lunch');
    await session.save();
    expect(session.hasUnknown, isTrue);

    await session.recover();

    expect(source.recoveries, 1);
    expect(session.hasUnknown, isFalse);
    expect(session.error.value, isNull);
    expect(session.saveResult.value?.outcomes.single.reason, 'notReceived');
    expect(session.root.read(_title), 'Lunch');
    await session.discardChanges();
    expect(session.root.read(_title), isNull);
  });

  test('recovery that fails on the server keeps the form unknown', () async {
    final source = _FailingSource(
      commitFailure: const SocketException('Connection reset.'),
      recoverFailure: const BeakInternalException('Bad gateway.'),
    );
    final session = _session(source);
    await session.load();
    session.root.set(_title, 'Lunch');
    await session.save();

    await session.recover();

    expect(source.recoveries, 1);
    expect(session.hasUnknown, isTrue);
    expect(session.error.value, isNotNull);
  });

  test('recover leaves edits alone once the save outcome is known', () async {
    final source = FakeDataSource(models: const [_Memo()]);
    final session = BeakFormSession(
      model: const _Memo(),
      dataSource: source,
      layout: BeakFormLayout(children: [_title.inputText()]),
    );
    addTearDown(session.dispose);
    await session.load();
    session.root.set(_title, 'Lunch');
    final receipt = await session.save();
    expect(receipt?.complete, isTrue);

    session.root.set(_title, 'Dinner');
    await session.recover();

    expect(session.root.read(_title), 'Dinner');
    expect(session.isDirty, isTrue);
  });

  testWidgets('a rejected save shows its reason once and offers no recovery', (
    tester,
  ) async {
    final source = _FailingSource(
      commitFailure: const BeakPayloadTooLargeException('Body too large.'),
    );
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: const _Memo(),
          dataSource: source,
          mode: BeakFormMode.create,
          layout: BeakFormLayout(children: [_title.inputText()]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'Lunch');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(source.commits, 1);
    expect(find.text('Body too large.'), findsOneWidget);
    expect(find.text('Check save status'), findsNothing);
    expect(find.text('Save remaining changes'), findsOneWidget);
  });
}
