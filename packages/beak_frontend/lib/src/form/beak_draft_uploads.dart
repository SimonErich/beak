import 'dart:math';
import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';

/// Session-owned upload staging. Picking stays in memory until graph submission.
///
/// Confirmed writes adopt files; failed writes reuse uploads on retry. Unknown
/// outcomes retain files until receipt recovery, even if the form is closed.
/// Storage is not transactional with the database: a host should also expire
/// abandoned uploads after checking record references to cover process crashes.
final class BeakDraftUploads implements BeakUploadClient, BeakUploadUrlClient {
  /// Wraps the host's upload transport for a single form session.
  BeakDraftUploads(this._client);

  final BeakUploadClient _client;
  final Map<String, _DraftUpload> _files = {};
  final String _namespace =
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x3fffffff)}';
  int _sequence = 0;
  bool _closed = false;
  Future<BeakSavePlan>? _activePrepare;

  @override
  Future<Uri> uploadUrl(String table, String columnKey, String key) async {
    if (preview(key) case final BeakStoredFile file) return file.url;
    final client = _client;
    if (client case final BeakUploadUrlClient resolver) {
      return resolver.uploadUrl(table, columnKey, key);
    }
    throw const BeakConfigurationException(
      'This upload transport cannot resolve stored files.',
    );
  }

  @override
  Future<BeakStoredFile> upload(
    String table,
    String columnKey,
    BeakUpload file,
  ) async {
    if (_closed) throw const BeakConfigurationException('The draft is closed.');
    final frozen = BeakUpload(
      filename: file.filename,
      mimeType: file.mimeType,
      bytes: Uint8List.fromList(file.bytes),
    );
    final key = 'beak-draft:$_namespace:${++_sequence}';
    final preview = BeakStoredFile(
      key: key,
      url: Uri.dataFromBytes(frozen.bytes, mimeType: frozen.mimeType),
      sizeInBytes: file.sizeInBytes,
      mimeType: file.mimeType,
    );
    _files[key] = _DraftUpload(table, columnKey, frozen, preview);
    return preview;
  }

  /// Resolves both staged and already uploaded previews within this draft.
  BeakStoredFile? preview(String key) {
    for (final entry in _files.entries) {
      if (entry.key == key || entry.value.remote?.key == key) {
        return entry.value.remote ?? entry.value.preview;
      }
    }
    return null;
  }

  /// Original filename for a file selected in this draft, even after upload.
  String? filename(String key) {
    for (final entry in _files.entries) {
      if (entry.key == key || entry.value.remote?.key == key) {
        return entry.value.file.filename;
      }
    }
    return null;
  }

  /// Uploads referenced staged files and snapshots their final storage keys.
  /// No network request is made for replaced or removed selections.
  Future<BeakSavePlan> prepare(BeakSavePlan plan) {
    if (_activePrepare != null) {
      throw const BeakConfigurationException(
        'An upload preparation is already running.',
      );
    }
    final future = _prepare(plan).whenComplete(() => _activePrepare = null);
    _activePrepare = future;
    return future;
  }

  Future<BeakSavePlan> _prepare(BeakSavePlan plan) async {
    if (_closed) throw const BeakConfigurationException('The draft is closed.');
    final referenced = {
      for (final operation in plan.operations)
        for (final value in operation.values.values.values) value.raw,
    };
    _files.removeWhere(
      (key, draft) => draft.remote == null && !referenced.contains(key),
    );
    final operations = <BeakSaveOperation>[];
    for (final operation in plan.operations) {
      final values = {...operation.values.values};
      for (final entry in values.entries.toList()) {
        final draft = _files[entry.value.raw];
        if (draft == null) continue;
        if (draft.table != operation.target.table ||
            draft.columnKey != entry.key) {
          throw const BeakConfigurationException(
            'Upload belongs to another field.',
          );
        }
        try {
          draft.remote ??= await _client.upload(
            draft.table,
            draft.columnKey,
            draft.file,
          );
        } on BeakException {
          rethrow;
        } on Exception {
          throw const BeakStorageException(
            'Unable to upload the file. Please try again.',
          );
        }
        if (_closed) {
          throw const BeakConfigurationException('The draft is closed.');
        }
        values[entry.key] = BeakValue.of(draft.remote!.key);
      }
      operations.add(
        BeakSaveOperation(
          id: operation.id,
          kind: operation.kind,
          target: operation.target,
          values: BeakRecord(values: values),
          references: operation.references,
          dependsOn: operation.dependsOn,
          owner: operation.owner,
          relationKey: operation.relationKey,
          related: operation.related,
          expectedUpdatedAt: operation.expectedUpdatedAt,
        ),
      );
    }
    return BeakSavePlan(
      saveId: plan.saveId,
      root: plan.root,
      action: plan.action,
      arguments: plan.arguments,
      operations: operations,
    );
  }

  /// Marks a submitted plan uncertain before crossing the commit boundary.
  /// A thrown transport error cannot accidentally make its files disposable.
  void submitted(BeakSavePlan plan) {
    for (final draft in _referenced(plan)) {
      draft.unknownSaves.add(plan.saveId);
    }
  }

  /// Applies authoritative receipts, including receipts recovered after timeout.
  void resolve(BeakSavePlan plan, BeakSaveResult result) {
    if (plan.saveId != result.saveId) {
      throw const BeakConfigurationException(
        'Upload receipt has a different save identity.',
      );
    }
    for (final draft in _referenced(plan)) {
      var unknown = false;
      for (final operation in plan.operations) {
        if (!operation.values.values.values.any(
          (v) => v.raw == draft.remote?.key,
        )) {
          continue;
        }
        final outcome = result.outcomes
            .where((o) => o.id == operation.id)
            .firstOrNull;
        switch (outcome?.status) {
          case BeakWriteOutcome.applied:
            draft.adopted = true;
          case BeakWriteOutcome.unapplied:
            break;
          case BeakWriteOutcome.unknown || null:
            unknown = true;
        }
      }
      if (unknown) {
        draft.unknownSaves.add(plan.saveId);
      } else {
        draft.unknownSaves.remove(plan.saveId);
      }
    }
  }

  Iterable<_DraftUpload> _referenced(BeakSavePlan plan) sync* {
    final keys = {
      for (final op in plan.operations)
        for (final v in op.values.values.values) v.raw,
    };
    for (final draft in _files.values) {
      if (draft.remote != null && keys.contains(draft.remote!.key)) yield draft;
    }
  }

  /// Closes the draft and discards only definitely uncommitted remote files.
  /// Returns cleanup failures so hosts can log/retry them; repeat calls are safe.
  /// Basic upload-only transports retain their files for host-side collection.
  Future<List<BeakException>> dispose() async {
    _closed = true;
    try {
      await _activePrepare;
    } on Exception {
      // Preparation may have stopped after writing a file; clean that file too.
    }
    final failures = <BeakException>[];
    final client = _client;
    for (final entry in _files.entries.toList()) {
      final draft = entry.value;
      if (draft.adopted || draft.unknownSaves.isNotEmpty) continue;
      if (draft.remote case final BeakStoredFile file) {
        if (client is! BeakManagedUploadClient) continue;
        try {
          await client.discardUpload(draft.table, draft.columnKey, file);
        } on BeakException catch (error) {
          failures.add(error);
          continue;
        } on Exception {
          failures.add(
            const BeakStorageException('Unable to discard the pending upload.'),
          );
          continue;
        }
      }
      _files.remove(entry.key);
    }
    return failures;
  }
}

final class _DraftUpload {
  _DraftUpload(this.table, this.columnKey, this.file, this.preview);
  final String table;
  final String columnKey;
  final BeakUpload file;
  final BeakStoredFile preview;
  BeakStoredFile? remote;
  bool adopted = false;
  final Set<String> unknownSaves = {};
}
