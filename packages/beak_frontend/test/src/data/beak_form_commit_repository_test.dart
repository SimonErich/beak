import 'dart:async';
import 'dart:io';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/src/data/beak_form_commit_repository.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Source implements BeakCommitDataSource {
  _Source({this.onCommit, this.onRecover});

  final Future<BeakSaveResult> Function(BeakSavePlan plan)? onCommit;
  final Future<BeakSaveResult> Function(String saveId)? onRecover;

  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities(durableReceipts: true);

  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) => onCommit!(plan);

  @override
  Future<BeakSaveResult> recover(String saveId) => onRecover!(saveId);
}

BeakSavePlan _plan() => BeakSavePlan(
  saveId: 'save-1',
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

Future<BeakSaveResult> _commitFailing(Object error) => BeakFormCommitRepository(
  _Source(onCommit: (_) => Future.error(error)),
).commit(_plan());

void main() {
  group('definite rejections are unapplied, never unknown', () {
    final rejections = <String, BeakException>{
      'a 422 the server refused to decode': const BeakValidationException(
        'Invalid or oversized save plan.',
      ),
      'a 413 body limit': const BeakPayloadTooLargeException('Too large.'),
      'a 401 expired session': const BeakAuthenticationException('Sign in.'),
      'a 403 denial': const BeakAuthorizationException('Not allowed.'),
      'a 404 missing route': const BeakNotFoundException('No such route.'),
      'a 409 reused save identity': const BeakConflictException('Reused.'),
    };
    for (final entry in rejections.entries) {
      test(entry.key, () async {
        final receipt = await _commitFailing(entry.value);
        expect(receipt.saveId, 'save-1');
        expect(receipt.hasUnknown, isFalse);
        expect(receipt.complete, isFalse);
        expect(receipt.outcomes.map((o) => o.id), ['note', 'label']);
        for (final outcome in receipt.outcomes) {
          expect(outcome.status, BeakWriteOutcome.unapplied);
          expect(outcome.reason, 'rejected');
          expect(outcome.error?.code, entry.value.code);
          expect(outcome.error?.message, entry.value.message);
        }
      });
    }

    test('field errors are attributed only to the form root', () async {
      final receipt = await _commitFailing(
        const BeakValidationException(
          'Fix the title.',
          fieldErrors: {
            'title': ['Required'],
          },
        ),
      );
      expect(receipt.outcomes.first.error?.fieldErrors, {
        'title': ['Required'],
      });
      expect(receipt.outcomes.last.error?.fieldErrors, isEmpty);
      expect(receipt.outcomes.last.error?.message, 'Fix the title.');
    });
  });

  group('an unproven outcome stays unknown', () {
    final unproven = <String, Object>{
      'a 5xx without a Beak body': const BeakInternalException('Bad gateway.'),
      'an unexpected status': const BeakTransportException('Status 302.'),
      'a storage failure mid-write': const BeakStorageException('Disk.'),
      'a server configuration failure': const BeakConfigurationException(
        'Broken.',
      ),
      'a dropped connection': const SocketException('Connection reset.'),
      'a timeout': TimeoutException('No reply.'),
    };
    for (final entry in unproven.entries) {
      test(entry.key, () async {
        final receipt = await _commitFailing(entry.value);
        expect(receipt.hasUnknown, isTrue);
        for (final outcome in receipt.outcomes) {
          expect(outcome.status, BeakWriteOutcome.unknown);
          expect(outcome.reason, 'responseUnavailable');
        }
      });
    }
  });

  group('the receipt mode names the real guarantee', () {
    test('an atomic source reports atomic', () async {
      final source = _AtomicSource();
      final receipt = await BeakFormCommitRepository(source).commit(_plan());
      expect(receipt.mode, BeakSaveMode.atomic);
    });

    test('a durable, non-atomic HTTP-shaped source reports staged', () async {
      final receipt = await _commitFailing(
        const BeakInternalException('Bad gateway.'),
      );
      expect(receipt.mode, BeakSaveMode.staged);
    });
  });

  group('recover', () {
    test('returns the stored receipt untouched', () async {
      final stored = BeakSaveResult(
        saveId: 'save-1',
        mode: BeakSaveMode.staged,
        outcomes: [
          BeakOperationResult(id: 'note', status: BeakWriteOutcome.applied),
        ],
      );
      final receipt = await BeakFormCommitRepository(
        _Source(onRecover: (_) async => stored),
      ).recover('save-1', operationIds: ['note']);
      expect(receipt, same(stored));
    });

    test('a 404 receipt lookup means the save never arrived', () async {
      final receipt = await BeakFormCommitRepository(
        _Source(
          onRecover: (_) =>
              Future.error(const BeakNotFoundException('No receipt.')),
        ),
      ).recover('save-1', operationIds: ['note', 'label']);
      expect(receipt.saveId, 'save-1');
      expect(receipt.hasUnknown, isFalse);
      expect(receipt.outcomes.map((o) => o.id), ['note', 'label']);
      for (final outcome in receipt.outcomes) {
        expect(outcome.status, BeakWriteOutcome.unapplied);
        expect(outcome.reason, 'notReceived');
      }
    });

    test('a network failure while recovering still throws', () async {
      final repository = BeakFormCommitRepository(
        _Source(onRecover: (_) => Future.error(const SocketException('Down.'))),
      );
      await expectLater(
        repository.recover('save-1', operationIds: ['note']),
        throwsA(isA<SocketException>()),
      );
    });

    test('a server failure while recovering still throws', () async {
      final repository = BeakFormCommitRepository(
        _Source(
          onRecover: (_) =>
              Future.error(const BeakInternalException('Bad gateway.')),
        ),
      );
      await expectLater(
        repository.recover('save-1', operationIds: ['note']),
        throwsA(isA<BeakInternalException>()),
      );
    });
  });
}

final class _AtomicSource implements BeakCommitDataSource {
  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities(atomicGraph: true);

  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) =>
      Future.error(const BeakInternalException('Bad gateway.'));

  @override
  Future<BeakSaveResult> recover(String saveId) => throw UnimplementedError();
}
