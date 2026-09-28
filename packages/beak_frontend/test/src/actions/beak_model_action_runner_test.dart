import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import '../../support/panel_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'unknown commands recover the same save without another confirmation or dispatch',
    () async {
      final source = _Source();
      final runner = BeakModelActionRunner();
      addTearDown(runner.dispose);
      var confirmations = 0;
      Future<BeakModelActionOutcome> run() => runner.execute(
        model: const _Model(),
        source: source,
        recordId: 'one',
        action: _action,
        principal: 'alice',
        prepare: (_) async {
          confirmations++;
          return const BeakRecord(values: {});
        },
      );
      expect((await run()).complete, isFalse);
      expect((await run()).complete, isFalse);
      expect((await run()).complete, isTrue);
      expect(source.commits, hasLength(1));
      expect(source.recovered, [
        source.commits.single.saveId,
        source.commits.single.saveId,
      ]);
      expect(confirmations, 1);
    },
  );

  test(
    'concurrent invocations coalesce and another principal cannot reuse the pending record',
    () async {
      final source = _Source();
      final runner = BeakModelActionRunner();
      addTearDown(runner.dispose);
      final inputs = Completer<BeakRecord?>();
      final first = runner.execute(
        model: const _Model(),
        source: source,
        recordId: 'one',
        action: _action,
        principal: 'alice',
        prepare: (_) => inputs.future,
      );
      final duplicate = runner.execute(
        model: const _Model(),
        source: source,
        recordId: 'one',
        action: _action,
        principal: 'alice',
        prepare: (_) => throw StateError('Duplicate confirmation'),
      );
      inputs.complete(const BeakRecord(values: {}));
      await Future.wait([first, duplicate]);
      expect(source.commits, hasLength(1));
      await runner.execute(
        model: const _Model(),
        source: source,
        recordId: 'one',
        action: _action,
        principal: 'bob',
        prepare: (_) async => const BeakRecord(values: {}),
      );
      expect(source.commits, hasLength(2));
      expect(source.commits.first.saveId, isNot(source.commits.last.saveId));
    },
  );
}

const _action = BeakModelAction(name: 'send', label: 'Send');

final class _Model extends BeakModel {
  const _Model();
  @override
  String get table => 'commands';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];
  @override
  BeakModelBehavior get behavior => const BeakModelBehavior(actions: [_action]);
}

final class _Source extends FakeDataSource implements BeakCommitDataSource {
  _Source()
    : super(
        models: const [_Model()],
        records: {
          'commands': {
            'one': BeakRecord.fromRow({'id': 'one', 'name': 'Dispatch'}),
          },
        },
      );
  final commits = <BeakSavePlan>[];
  final recovered = <String>[];
  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities(atomicGraph: true, durableReceipts: true);
  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    commits.add(plan);
    return _receipt(plan, BeakWriteOutcome.unknown);
  }

  @override
  Future<BeakSaveResult> recover(String saveId) async {
    recovered.add(saveId);
    return _receipt(
      commits.firstWhere((plan) => plan.saveId == saveId),
      recovered.length == 1
          ? BeakWriteOutcome.unknown
          : BeakWriteOutcome.applied,
    );
  }

  BeakSaveResult _receipt(BeakSavePlan plan, BeakWriteOutcome status) =>
      BeakSaveResult(
        saveId: plan.saveId,
        mode: BeakSaveMode.atomic,
        outcomes: [
          for (final op in plan.operations)
            BeakOperationResult(id: op.id, status: status, resolvedId: 'one'),
        ],
      );
}
