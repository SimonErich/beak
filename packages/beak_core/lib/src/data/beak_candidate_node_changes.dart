import '../columns/beak_column.dart';
import '../model/beak_field_ref.dart';
import 'beak_candidate_graph.dart';

/// Which columns of a candidate the transaction changes.
extension BeakCandidateNodeChanges on BeakCandidateNode {
  /// The columns whose proposed value differs from the persisted one, in the
  /// model's declaration order, skipping the [except] fields.
  ///
  /// Meant for an existing record: a new one has no persisted values to
  /// compare with, so every value it holds counts as changed. The way a
  /// preparer describes an edit without listing column keys.
  List<BeakColumn> changedColumns({
    Iterable<BeakFieldRef<Object>> except = const [],
  }) {
    final ignored = {for (final field in except) field.key};
    return [
      for (final column in model.columns)
        if (!ignored.contains(column.key) &&
            record[column.key] != initial?[column.key])
          column,
    ];
  }
}
