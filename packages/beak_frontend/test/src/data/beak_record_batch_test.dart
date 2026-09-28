import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';

const _nameColumn = BeakStringColumn(
  key: 'name',
  label: 'Name',
  rules: [BeakRequired()],
);
const _qtyColumn = BeakIntColumn(
  key: 'qty',
  label: 'Quantity',
  rules: [BeakMin(1)],
);
const _activeColumn = BeakBoolColumn(key: 'active', label: 'Active');
const _totalColumn = BeakIntColumn(
  key: 'total',
  label: 'Total',
  rules: [BeakRequired()],
);
const _name = BeakScalarField<String>(model: _Model(), column: _nameColumn);
const _qty = BeakScalarField<int>(model: _Model(), column: _qtyColumn);
const _active = BeakScalarField<bool>(model: _Model(), column: _activeColumn);
const _total = BeakScalarField<int>(model: _Model(), column: _totalColumn);

final class _Model extends BeakModel {
  const _Model();
  @override
  String get table => 'items';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    _nameColumn,
    _qtyColumn,
    _activeColumn,
    _totalColumn,
    BeakDateTimeColumn(key: 'updated_at', label: 'Updated'),
  ];
  @override
  BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior<int>.derived(
        field: _total,
        dependencies: [_qty],
        resolve: (context) => (context.read(_qty) ?? 0) * 2,
      ),
    ],
  );
}

final class _Source implements BeakCommitDataSource {
  final List<String> calls = [];
  bool fail = false;
  Completer<void>? pending;
  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities();
  BeakSaveResult result(String id) => BeakSaveResult(
    saveId: id,
    mode: BeakSaveMode.atomic,
    outcomes: [
      BeakOperationResult(id: 'row', status: BeakWriteOutcome.applied),
    ],
  );
  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    calls.add(plan.saveId);
    await pending?.future;
    if (fail) throw const BeakStorageException('Lost response');
    return result(plan.saveId);
  }

  @override
  Future<BeakSaveResult> recover(String saveId) async => result(saveId);
}

void main() {
  final definition = BeakImportDefinition(
    model: const _Model(),
    fields: [_name, _qty, _active],
  );
  test(
    'CSV preview handles quotes, newlines, typed cells and shared derivations',
    () {
      final preview = definition.preview(
        'Name,Quantity,Active\r\n"Beans, ""dark""\nroast",2,false\r\n',
      );
      expect(preview.valid, isTrue);
      expect(preview.rows.single.values['name']?.raw, 'Beans, "dark"\nroast');
      expect(preview.rows.single.values['qty']?.raw, 2);
      expect(preview.rows.single.values['active']?.raw, isFalse);
      final plan = preview.plans('import').single;
      expect(plan.saveId, 'import-2');
      expect(
        plan.operations.single.values.values.containsKey('total'),
        isFalse,
        reason: 'Server owns derived values; preview must not submit them.',
      );
    },
  );

  test('invalid cells and row structure remain reviewable without writes', () {
    final preview = definition.preview('Name,Quantity,Active\n,0,maybe');
    expect(preview.valid, isFalse);
    expect(
      preview.rows.single.errors.keys,
      containsAll(['name', 'qty', 'active']),
    );
    expect(() => preview.plans('bad'), throwsA(isA<BeakValidationException>()));
    for (final csv in [
      '',
      'Name,Name\nx,y',
      'Unknown\nx',
      'Name,Quantity\nx',
      'Name\n"unclosed',
      'Name\n"x"invalid',
    ]) {
      expect(
        () => definition.preview(csv),
        throwsA(isA<BeakValidationException>()),
      );
    }
    expect(
      () => BeakImportDefinition(
        model: const _Model(),
        fields: [_name],
        maximumRows: 1,
      ).preview('Name\nx\ny'),
      throwsA(isA<BeakValidationException>()),
    );
  });

  test(
    'bulk edits preserve baseline revisions and validate every candidate',
    () {
      final revision = DateTime.utc(2026, 1, 1);
      final records = [
        for (final id in ['one', 'two'])
          BeakRecord.fromRow({
            'id': id,
            'name': id,
            'qty': 1,
            'total': 2,
            'updated_at': revision,
          }),
      ];
      final preview = BeakBulkEdit.preview(
        model: const _Model(),
        records: records,
        changes: [const BeakFieldChange(_qty, 3)],
      );
      expect(preview.valid, isTrue);
      expect(
        preview
            .plans('bulk')
            .map((plan) => plan.operations.single.expectedUpdatedAt),
        [revision, revision],
      );
      expect(
        preview.rows.every((row) => row.values.values.keys.single == 'qty'),
        isTrue,
      );
      expect(records.first['qty']?.raw, 1);
      expect(
        BeakBulkEdit.preview(
          model: const _Model(),
          records: records,
          changes: [const BeakFieldChange(_qty, 0)],
        ).valid,
        isFalse,
      );
      expect(
        () => BeakBulkEdit.preview(
          model: const _Model(),
          records: records,
          changes: [],
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakBulkEdit.preview(
          model: const _Model(),
          records: records,
          changes: [
            const BeakFieldChange(_qty, 2),
            const BeakFieldChange(_qty, 3),
          ],
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );

  List<BeakSavePlan> plans() =>
      definition.preview('Name,Quantity\nOne,1\nTwo,2').plans('batch');
  test(
    'cancellation keeps confirmed receipts and resume skips completed rows',
    () async {
      final source = _Source();
      final repository = BeakBatchRepository(source);
      await repository.execute(
        plans(),
        onProgress: (count, total) => repository.cancel(),
      );
      expect(source.calls, ['batch-2']);
      await repository.execute(plans());
      expect(source.calls, ['batch-2', 'batch-3']);
      expect(repository.receipts.every((receipt) => receipt.complete), isTrue);
      final reused = definition
          .preview('Name,Quantity\nChanged,1')
          .plans('batch');
      expect(
        await repository.execute(reused),
        isA<BeakErr<List<BeakSaveResult>>>(),
      );
      expect(source.calls, hasLength(2));
    },
  );

  test(
    'uncertain writes require recovery before later records execute',
    () async {
      final source = _Source()..fail = true;
      final repository = BeakBatchRepository(source);
      await repository.execute(plans());
      expect(repository.receipts.single.hasUnknown, isTrue);
      await repository.execute(plans());
      expect(source.calls, hasLength(1));
      source.fail = false;
      await repository.recover('batch-2');
      await repository.execute(plans());
      expect(source.calls, ['batch-2', 'batch-3']);
      expect(
        await repository.recover('unknown'),
        isA<BeakErr<BeakSaveResult>>(),
      );
    },
  );

  test('overlapping executions cannot dispatch duplicate writes', () async {
    final source = _Source()..pending = Completer<void>();
    final repository = BeakBatchRepository(source);
    final first = repository.execute(plans());
    expect(
      await repository.execute(plans()),
      isA<BeakErr<List<BeakSaveResult>>>(),
    );
    repository.cancel();
    source.pending!.complete();
    await first;
    expect(source.calls, ['batch-2']);
  });
  test('quoted CSV headers accept a UTF8 byte-order mark', () {
    final preview = definition.preview(
      '\ufeff"Name","Quantity"\r\n"One",1\r\n',
    );
    expect(preview.valid, isTrue);
    expect(preview.rows.single.values['name']?.raw, 'One');
  });

  test(
    'bulk preview rejects missing and duplicate identities before submission',
    () {
      final identified = BeakRecord.fromRow({
        'id': 'one',
        'name': 'One',
        'qty': 1,
      });
      for (final records in [
        [
          BeakRecord.fromRow({'name': 'No identity', 'qty': 1}),
        ],
        [identified, identified],
      ]) {
        expect(
          () => BeakBulkEdit.preview(
            model: const _Model(),
            records: records,
            changes: [const BeakFieldChange(_qty, 2)],
          ),
          throwsA(isA<BeakConfigurationException>()),
        );
      }
    },
  );
}
