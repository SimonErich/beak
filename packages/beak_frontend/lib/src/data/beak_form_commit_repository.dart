import 'package:beak_core/beak_core.dart';

// --8<-- [start:BeakFormCommitRepository]
/// Turns a failed commit into a receipt that says exactly what is known.
///
/// A response the server never sent cannot prove that nothing was written, so
/// a lost connection, a timeout or an opaque 5xx becomes an `unknown` outcome
/// that only receipt recovery may resolve. A typed rejection (validation, size
/// limit, authentication, authorization, missing route, conflict) means the
/// server refused the request before running any write, so it becomes an
/// `unapplied` outcome and the form stays editable. The same save identity
/// remains available to the transport's recovery API.
final class BeakFormCommitRepository {
  /// Wraps a commit-capable source at the exception boundary.
  const BeakFormCommitRepository(this.source);

  /// Transport owning the save receipt.
  final BeakCommitDataSource source;

  /// Commits [plan], describing a failure as a receipt instead of throwing.
  ///
  /// The receipt of a failure the transport cannot classify claims
  /// [BeakSaveMode.staged] unless the source declares an atomic graph: it is
  /// the weaker guarantee, and the recovered receipt carries the real one.
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    try {
      return await source.commit(plan);
    } on Exception catch (error) {
      final rejected = error is BeakException && _isDefiniteRejection(error);
      return BeakSaveResult(
        saveId: plan.saveId,
        mode: source.commitCapabilities.atomicGraph
            ? BeakSaveMode.atomic
            : BeakSaveMode.staged,
        outcomes: [
          for (final operation in plan.operations)
            BeakOperationResult(
              id: operation.id,
              status: rejected
                  ? BeakWriteOutcome.unapplied
                  : BeakWriteOutcome.unknown,
              reason: rejected ? 'rejected' : 'responseUnavailable',
              error: _failureFor(error, isRoot: operation.target == plan.root),
            ),
        ],
      );
    }
  }

  /// Reads the receipt of [saveId] without repeating any mutation.
  ///
  /// A missing receipt proves the server never received the plan, so every id
  /// in [operationIds] is reported `unapplied` with the reason `notReceived`
  /// and the form may save again. Any other failure is rethrown: the outcome
  /// is still unknown.
  Future<BeakSaveResult> recover(
    String saveId, {
    required Iterable<String> operationIds,
  }) async {
    try {
      return await source.recover(saveId);
    } on BeakNotFoundException {
      return BeakSaveResult(
        saveId: saveId,
        mode: source.commitCapabilities.atomicGraph
            ? BeakSaveMode.atomic
            : BeakSaveMode.staged,
        outcomes: [
          for (final id in operationIds)
            BeakOperationResult(
              id: id,
              status: BeakWriteOutcome.unapplied,
              reason: 'notReceived',
            ),
        ],
      );
    }
  }

  /// The failure recorded on one operation.
  ///
  /// A rejection of the whole plan cannot say which record a field error
  /// belongs to, so only the form root keeps them.
  static BeakSaveError _failureFor(Object error, {required bool isRoot}) {
    final failure = BeakSaveError.fromException(error);
    return isRoot
        ? failure
        : BeakSaveError(code: failure.code, message: failure.message);
  }

  /// Whether the server refused the request before it ran any write.
  static bool _isDefiniteRejection(BeakException error) => switch (error) {
    BeakValidationException() ||
    BeakPayloadTooLargeException() ||
    BeakAuthenticationException() ||
    BeakAuthorizationException() ||
    BeakNotFoundException() ||
    BeakConflictException() => true,
    BeakConfigurationException() ||
    BeakStorageException() ||
    BeakInternalException() ||
    BeakTransportException() => false,
  };
}
// --8<-- [end:BeakFormCommitRepository]
