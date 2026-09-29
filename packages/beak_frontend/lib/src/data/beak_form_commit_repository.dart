import 'package:beak_core/beak_core.dart';

// --8<-- [start:BeakFormCommitRepository]
/// Records a lost commit response as uncertain instead of permitting a replay.
/// The same save identity remains available to the transport's recovery API.
final class BeakFormCommitRepository {
  /// Wraps a commit-capable source at the exception boundary.
  const BeakFormCommitRepository(this.source);

  /// Transport owning the save receipt.
  final BeakCommitDataSource source;

  /// A thrown transport failure cannot prove that the server wrote nothing.
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    try {
      return await source.commit(plan);
    } on Exception catch (error) {
      return BeakSaveResult(
        saveId: plan.saveId,
        mode: source.commitCapabilities.atomicGraph
            ? BeakSaveMode.atomic
            : BeakSaveMode.staged,
        outcomes: [
          for (final operation in plan.operations)
            BeakOperationResult(
              id: operation.id,
              status: BeakWriteOutcome.unknown,
              reason: 'responseUnavailable',
              error: BeakSaveError.fromException(error),
            ),
        ],
      );
    }
  }
}
// --8<-- [end:BeakFormCommitRepository]
