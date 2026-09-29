import 'package:beak_core/beak_core.dart';

/// Runs a typed custom workflow through Beak's result boundary.
///
/// A [BeakException] becomes [BeakErr]; successful values remain typed in
/// [BeakOk]. Unmapped exceptions and programming errors propagate unchanged.
/// [mapException] can translate expected host RPC exceptions into Beak failures.
/// Existing [BeakException] values bypass the mapper. A missing mapper or a null
/// mapping rethrows the original exception with its stack; [Error] values and
/// failures thrown by the mapper propagate unchanged.
/// No resource, repository or dummy data source is required.
// --8<-- [start:beakRun]
Future<BeakResult<T>> beakRun<T>(
  Future<T> Function() operation, {
  BeakException? Function(Exception exception, StackTrace stack)? mapException,
}) async {
  try {
    return BeakOk(await operation());
  } on BeakException catch (exception) {
    return BeakErr(exception);
  } on Exception catch (exception, stack) {
    final mapped = mapException?.call(exception, stack);
    if (mapped != null) return BeakErr(mapped);
    rethrow;
  }
}
// --8<-- [end:beakRun]
