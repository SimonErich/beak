import 'dart:async';
import 'dart:typed_data';
import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import '../../support/panel_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final file = BeakUpload(
    filename: 'a.png',
    mimeType: 'image/png',
    bytes: Uint8List.fromList([1, 2]),
  );
  BeakSavePlan plan(String key) => BeakSavePlan(
    saveId: 'save',
    root: const BeakRecordRef.draft('products', 'root'),
    operations: [
      BeakSaveOperation(
        id: 'write',
        kind: BeakSaveOperationKind.create,
        target: const BeakRecordRef.draft('products', 'root'),
        values: BeakRecord.fromRow({'photo': key}),
      ),
    ],
  );
  BeakSaveResult receipt(BeakWriteOutcome status) => BeakSaveResult(
    saveId: 'save',
    mode: BeakSaveMode.atomic,
    outcomes: [BeakOperationResult(id: 'write', status: status)],
  );

  test(
    'closing during a commit waits for its receipt before upload cleanup',
    () async {
      final client = _Uploads();
      final source = _PendingSource();
      final session = BeakFormSession(
        model: const ArticleModel(),
        dataSource: source,
        uploader: client,
        layout: BeakFormLayout(
          children: [
            const BeakScalarField<String>(
              model: ArticleModel(),
              column: ArticleColumns.title,
            ).input(),
            const BeakScalarField<String>(
              model: ArticleModel(),
              column: ArticleColumns.avatar,
            ).input(),
          ],
        ),
      );
      session.root.controller.setValue<String>(ArticleColumns.title, 'Draft');
      final staged = await session.uploader!.upload('articles', 'avatar', file);
      session.root.controller.setValue<String>(
        ArticleColumns.avatar,
        staged.key,
      );
      final save = session.save();
      final submitted = await source.started.future;
      expect(client.uploads, 1);
      expect(submitted.operations.single.values['avatar']?.raw, 'remote/1.png');
      session.dispose();
      source.receipt.complete(
        BeakSaveResult(
          saveId: submitted.saveId,
          mode: BeakSaveMode.atomic,
          outcomes: [
            for (final op in submitted.operations)
              BeakOperationResult(id: op.id, status: BeakWriteOutcome.unknown),
          ],
        ),
      );
      await save;
      await session.uploadCleanup;
      expect(client.discarded, isEmpty);
    },
  );

  test('closing during recovery cleans files confirmed unapplied', () async {
    final client = _Uploads();
    final source = _PendingSource();
    final session = BeakFormSession(
      model: const ArticleModel(),
      dataSource: source,
      uploader: client,
      layout: BeakFormLayout(
        children: [
          const BeakScalarField<String>(
            model: ArticleModel(),
            column: ArticleColumns.title,
          ).input(),
          const BeakScalarField<String>(
            model: ArticleModel(),
            column: ArticleColumns.avatar,
          ).input(),
        ],
      ),
    );
    session.root.controller.setValue<String>(ArticleColumns.title, 'Draft');
    final staged = await session.uploader!.upload('articles', 'avatar', file);
    session.root.controller.setValue<String>(ArticleColumns.avatar, staged.key);
    final save = session.save();
    final submitted = await source.started.future;
    BeakSaveResult outcome(BeakWriteOutcome status) => BeakSaveResult(
      saveId: submitted.saveId,
      mode: BeakSaveMode.atomic,
      outcomes: [
        for (final op in submitted.operations)
          BeakOperationResult(id: op.id, status: status),
      ],
    );
    source.receipt.complete(outcome(BeakWriteOutcome.unknown));
    await save;
    final recovery = session.recover();
    await source.recoveryStarted.future;
    session.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(client.discarded, isEmpty);
    source.recovered.complete(outcome(BeakWriteOutcome.unapplied));
    await recovery;
    await session.uploadCleanup;
    expect(client.discarded, ['remote/1.png']);
  });

  test('closing during preparation waits and discards its upload', () async {
    final client = _Uploads()..releaseUpload = Completer<void>();
    final drafts = BeakDraftUploads(client);
    final chosen = await drafts.upload('products', 'photo', file);
    final preparing = drafts.prepare(plan(chosen.key));
    final failure = expectLater(
      preparing,
      throwsA(isA<BeakConfigurationException>()),
    );
    final cleanup = drafts.dispose();
    client.releaseUpload!.complete();
    await failure;
    expect(await cleanup, isEmpty);
    expect(client.discarded, ['remote/1.png']);
  });

  test('picking stays local; save uploads only referenced files', () async {
    final client = _Uploads();
    final drafts = BeakDraftUploads(client);
    await drafts.upload('products', 'photo', file);
    final chosen = await drafts.upload('products', 'photo', file);
    expect(client.uploads, 0);
    expect(chosen.url.scheme, 'data');
    expect(drafts.filename(chosen.key), 'a.png');
    final prepared = await drafts.prepare(plan(chosen.key));
    expect(client.uploads, 1);
    expect(drafts.filename('remote/1.png'), 'a.png');
    expect(prepared.operations.single.values['photo']?.raw, 'remote/1.png');
    await drafts.dispose();
    expect(client.discarded, ['remote/1.png']);
  });
  test(
    'failed save retries reuse uploads and cancellation cleans them',
    () async {
      final client = _Uploads();
      final drafts = BeakDraftUploads(client);
      final chosen = await drafts.upload('products', 'photo', file);
      final prepared = await drafts.prepare(plan(chosen.key));
      drafts.resolve(prepared, receipt(BeakWriteOutcome.unapplied));
      await drafts.prepare(plan(chosen.key));
      expect(client.uploads, 1);
      await drafts.dispose();
      expect(client.discarded, ['remote/1.png']);
    },
  );
  test(
    'applied and unknown outcomes never delete possibly committed files',
    () async {
      for (final status in [
        BeakWriteOutcome.applied,
        BeakWriteOutcome.unknown,
      ]) {
        final client = _Uploads();
        final drafts = BeakDraftUploads(client);
        final chosen = await drafts.upload('products', 'photo', file);
        final prepared = await drafts.prepare(plan(chosen.key));
        drafts.resolve(prepared, receipt(status));
        await drafts.dispose();
        expect(client.discarded, isEmpty);
      }
    },
  );
  test('unknown can recover as unapplied and then clean up', () async {
    final client = _Uploads();
    final drafts = BeakDraftUploads(client);
    final chosen = await drafts.upload('products', 'photo', file);
    final prepared = await drafts.prepare(plan(chosen.key));
    drafts.resolve(prepared, receipt(BeakWriteOutcome.unknown));
    drafts.resolve(prepared, receipt(BeakWriteOutcome.unapplied));
    await drafts.dispose();
    expect(client.discarded, ['remote/1.png']);
  });
  test('existing keys are never owned or discarded', () async {
    final client = _Uploads();
    final drafts = BeakDraftUploads(client);
    final prepared = await drafts.prepare(plan('existing.png'));
    drafts.resolve(prepared, receipt(BeakWriteOutcome.unapplied));
    await drafts.dispose();
    expect(client.uploads, 0);
    expect(client.discarded, isEmpty);
  });
  test('cleanup failure is reported and retryable', () async {
    final client = _Uploads()..failDiscard = true;
    final drafts = BeakDraftUploads(client);
    final chosen = await drafts.upload('products', 'photo', file);
    await drafts.prepare(plan(chosen.key));
    expect(await drafts.dispose(), hasLength(1));
    client.failDiscard = false;
    expect(await drafts.dispose(), isEmpty);
    expect(client.discarded, ['remote/1.png']);
  });
}

final class _Uploads implements BeakManagedUploadClient {
  int uploads = 0;
  Completer<void>? releaseUpload;
  bool failDiscard = false;
  final List<String> discarded = [];
  @override
  Future<BeakStoredFile> upload(
    String table,
    String columnKey,
    BeakUpload file,
  ) async {
    uploads++;
    await releaseUpload?.future;
    return BeakStoredFile(
      key: 'remote/$uploads.png',
      url: Uri.parse('https://test/$uploads.png'),
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
    if (failDiscard) throw const BeakStorageException('Unavailable');
    discarded.add(file.key);
  }
}

final class _PendingSource extends FakeDataSource
    implements BeakCommitDataSource {
  final started = Completer<BeakSavePlan>();
  final receipt = Completer<BeakSaveResult>();
  final recoveryStarted = Completer<void>();
  final recovered = Completer<BeakSaveResult>();
  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities(atomicGraph: true, durableReceipts: true);
  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) {
    started.complete(plan);
    return receipt.future;
  }

  @override
  Future<BeakSaveResult> recover(String saveId) {
    recoveryStarted.complete();
    return recovered.future;
  }
}
