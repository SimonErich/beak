import 'dart:convert';
import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/src/data/http_beak_data_source.dart';
import 'package:beak_frontend/src/data/model_beak_data_source.dart';
import 'package:beak_frontend/src/data/beak_data_changes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/panel_fixtures.dart';

final class _CommitSource extends FakeDataSource
    implements BeakCommitDataSource {
  int commits = 0;
  BeakSavePlan? lastPlan;
  BeakWriteOutcome outcome = BeakWriteOutcome.applied;
  BeakSaveError? failure;
  bool loseResponse = false;
  int recoveries = 0;
  BeakSaveResult? result;
  String? derivedTable;
  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities(atomicGraph: true);
  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    commits++;
    lastPlan = plan;
    result = BeakSaveResult(
      saveId: plan.saveId,
      mode: BeakSaveMode.atomic,
      outcomes: [
        if (derivedTable != null)
          BeakOperationResult(
            id: 'derived',
            status: BeakWriteOutcome.applied,
            table: derivedTable,
          ),
        for (final op in plan.operations)
          BeakOperationResult(id: op.id, status: outcome, error: failure),
      ],
    );
    if (loseResponse) throw const BeakStorageException('Reply lost.');
    return result!;
  }

  @override
  Future<BeakSaveResult> recover(String saveId) async {
    recoveries++;
    return result!;
  }
}

final class _Capabilities extends FakeDataSource
    implements
        BeakValidationDataSource,
        BeakManagedUploadClient,
        BeakUploadUrlClient {
  final calls = <String>[];
  @override
  Future<BeakValidationReport> validateRecord(
    BeakValidationRequest request,
  ) async {
    calls.add('validate:${request.table}:${request.recordId}');
    return const BeakValidationReport(
      fieldErrors: {
        'title': ['Taken.'],
      },
    );
  }

  @override
  Future<BeakStoredFile> upload(
    String table,
    String columnKey,
    BeakUpload file,
  ) async {
    calls.add('upload:$table:$columnKey');
    return BeakStoredFile(
      key: 'file',
      url: Uri.parse('https://test/file'),
      sizeInBytes: file.sizeInBytes,
      mimeType: file.mimeType,
    );
  }

  @override
  Future<void> discardUpload(
    String table,
    String columnKey,
    BeakStoredFile file,
  ) async {
    calls.add('discard:$table:$columnKey:${file.key}');
  }

  @override
  Future<Uri> uploadUrl(String table, String columnKey, String key) async {
    calls.add('url:$table:$columnKey:$key');
    return Uri.parse('https://test/$key');
  }
}

final class _Model extends BeakModel {
  const _Model(this.table, this.dataSource);
  @override
  final String table;
  @override
  final BeakDataSource dataSource;
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => const NoteModel().columns;
}

void main() {
  test(
    'server-derived tables refresh on commit and recovery after a new session',
    () async {
      final backend = _CommitSource()..derivedTable = 'labels';
      final registry = BeakModelRegistry()
        ..register(const NoteModel())
        ..register(const LabelModel());
      final source = ModelBeakDataSource(registry: registry, fallback: backend);
      addTearDown(source.dispose);
      final changes = <BeakDataChange>[];
      final subscription = source.changes.listen(changes.add);
      addTearDown(subscription.cancel);
      await source.commit(
        BeakSavePlan(
          saveId: 'derived-refresh',
          root: const BeakRecordRef.existing('notes', 'n1'),
          operations: [
            BeakSaveOperation(
              id: 'root',
              kind: BeakSaveOperationKind.update,
              target: const BeakRecordRef.existing('notes', 'n1'),
              values: BeakRecord.fromRow({'title': 'New'}),
            ),
          ],
        ),
      );
      expect(changes.single.tables, containsAll(['notes', 'labels']));
      final resumed = ModelBeakDataSource(
        registry: registry,
        fallback: backend,
      );
      addTearDown(resumed.dispose);
      final recovered = <BeakDataChange>[];
      final recoverySubscription = resumed.changes.listen(recovered.add);
      addTearDown(recoverySubscription.cancel);
      await resumed.recover('derived-refresh');
      expect(recovered.single.tables, contains('labels'));
    },
  );
  test(
    'model routing preserves validation and managed upload capabilities',
    () async {
      final source = _Capabilities();
      final router = ModelBeakDataSource(
        registry: BeakModelRegistry()..register(_Model('notes', source)),
      );
      addTearDown(router.dispose);
      final candidate = BeakValidationRequest(
        table: 'notes',
        record: BeakRecord.fromRow({'title': 'Same'}),
        recordId: 'one',
      );
      expect((await router.validateRecord(candidate)).fieldErrors, {
        'title': ['Taken.'],
      });
      final upload = BeakUpload(
        filename: 'a.png',
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1]),
      );
      final stored = await router.upload('notes', 'photo', upload);
      expect(
        await router.uploadUrl('notes', 'photo', stored.key),
        Uri.parse('https://test/file'),
      );
      await router.discardUpload('notes', 'photo', stored);
      expect(source.calls, [
        'validate:notes:one',
        'upload:notes:photo',
        'url:notes:photo:file',
        'discard:notes:photo:file',
      ]);
      final unsupported = ModelBeakDataSource(
        registry: BeakModelRegistry()
          ..register(_Model('notes', FakeDataSource())),
      );
      addTearDown(unsupported.dispose);
      expect((await unsupported.validateRecord(candidate)).valid, isTrue);
      await expectLater(
        unsupported.upload('notes', 'photo', upload),
        throwsA(isA<BeakConfigurationException>()),
      );
      await expectLater(
        unsupported.discardUpload('notes', 'photo', stored),
        throwsA(isA<BeakConfigurationException>()),
      );
      await expectLater(
        unsupported.uploadUrl('notes', 'photo', stored.key),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );

  test(
    'native deletion uses a graph and publishes only confirmed changes',
    () async {
      final source = _CommitSource();
      final router = ModelBeakDataSource(
        registry: BeakModelRegistry()..register(_Model('notes', source)),
      );
      addTearDown(router.dispose);
      final changes = <BeakDataChange>[];
      final subscription = router.changes.listen(changes.add);
      addTearDown(subscription.cancel);
      await router.delete('notes', '1');
      expect(source.commits, 1);
      expect(
        source.lastPlan!.operations.single.kind,
        BeakSaveOperationKind.delete,
      );
      expect(source.deleteCalls, isEmpty);
      expect(changes.single.tables, {'notes'});
      source.outcome = BeakWriteOutcome.unapplied;
      source.failure = BeakSaveError(
        code: 'validation',
        message: 'Locked invoice',
      );
      changes.clear();
      await expectLater(
        router.delete('notes', '2'),
        throwsA(
          isA<BeakValidationException>().having(
            (e) => e.message,
            'message',
            'Locked invoice',
          ),
        ),
      );
      expect(changes, isEmpty);
    },
  );

  test(
    'a lost deletion response recovers the same receipt without replay',
    () async {
      final source = _CommitSource()..loseResponse = true;
      final router = ModelBeakDataSource(
        registry: BeakModelRegistry()..register(_Model('notes', source)),
      );
      addTearDown(router.dispose);
      await expectLater(
        router.delete('notes', '1'),
        throwsA(isA<BeakStorageException>()),
      );
      final identity = source.lastPlan!.saveId;
      await router.delete('notes', '1');
      expect(source.commits, 1);
      expect(source.recoveries, 1);
      expect(source.lastPlan!.saveId, identity);
    },
  );

  test(
    'a common source retains its graph capability and recovery route',
    () async {
      final source = _CommitSource();
      final router = ModelBeakDataSource(
        registry: BeakModelRegistry()..register(_Model('notes', source)),
      );
      final plan = BeakSavePlan(
        saveId: 'one',
        root: const BeakRecordRef.existing('notes', '1'),
        operations: [],
      );
      expect(router.commitCapabilities.atomicGraph, isTrue);
      expect((await router.commit(plan)).mode, BeakSaveMode.atomic);
      await router.recover('one');
      expect(source.commits, 1);
      expect(source.recoveries, 1);
    },
  );

  test(
    'distinct model sources stage writes and retain each resolved identity',
    () async {
      final notes = FakeDataSource();
      final other = FakeDataSource();
      final router = ModelBeakDataSource(
        registry: BeakModelRegistry()
          ..register(_Model('notes', notes))
          ..register(_Model('labels', other)),
      );
      final plan = BeakSavePlan(
        saveId: 'two',
        root: const BeakRecordRef.draft('notes', 'note'),
        operations: [
          BeakSaveOperation(
            id: 'note',
            kind: BeakSaveOperationKind.create,
            target: const BeakRecordRef.draft('notes', 'note'),
            values: BeakRecord.fromRow({'title': 'Note'}),
          ),
          BeakSaveOperation(
            id: 'label',
            kind: BeakSaveOperationKind.create,
            target: const BeakRecordRef.draft('labels', 'label'),
            values: BeakRecord.fromRow({'title': 'Label'}),
          ),
        ],
      );
      final result = await router.commit(plan);
      expect(result.mode, BeakSaveMode.staged);
      expect(result.complete, isTrue);
      expect(result.identities.keys, containsAll(['note', 'label']));
      expect((await router.recover('two')).toJson(), result.toJson());
    },
  );

  test(
    'HTTP graph submission and recovery use standard backend endpoints',
    () async {
      final paths = <String>[];
      final result = BeakSaveResult(
        saveId: 'receipt',
        mode: BeakSaveMode.atomic,
        outcomes: [],
      );
      final client = BeakClient(
        baseUrl: 'http://example.test',
        httpClient: MockClient((request) async {
          paths.add('${request.method} ${request.url.path}');
          return http.Response(jsonEncode(result.toJson()), 200);
        }),
      );
      addTearDown(client.close);
      final source = HttpBeakDataSource(client);
      final plan = BeakSavePlan(
        saveId: 'receipt',
        root: const BeakRecordRef.existing('notes', '1'),
        operations: [],
      );
      expect((await source.commit(plan)).complete, isTrue);
      expect((await source.recover('receipt')).complete, isTrue);
      expect(paths, ['POST /api/commits', 'GET /api/commits/receipt']);
    },
  );
}
