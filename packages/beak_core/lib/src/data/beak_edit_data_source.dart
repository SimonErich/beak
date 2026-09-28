import '../query/beak_record.dart';

/// Optional data-source capability for an edit command with a distinct shape.
///
/// Sources without this capability prefill forms from the ordinary read record.
/// Implementations must apply the same error and authorization boundary as get.
abstract interface class BeakEditDataSource {
  /// Fetches [id] and projects the input accepted by the update operation.
  Future<BeakRecord> loadEditValues(String table, Object id);
}
