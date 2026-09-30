import '../model/beak_field_value.dart';
import '../model/beak_model.dart';
import '../query/beak_record.dart';
import 'beak_data_source.dart';

/// Writes by model and typed field instead of by table and column key.
///
/// The typed way for server code to store a record: the table comes from the
/// generated model and every value from a field, so nothing spells either out.
extension BeakDataSourceWrites on BeakDataSource {
  /// Stores a new record of [model] holding [values].
  ///
  /// ```dart
  /// await source.insert(const OrderNoteModel(), [
  ///   OrderNoteModel.body.to('Call the customer'),
  ///   OrderNoteModel.orderId.to(orderId),
  /// ]);
  /// ```
  Future<BeakRecord> insert(BeakModel model, Iterable<BeakFieldValue> values) =>
      create(model.table, model.record(values));

  /// Changes only [values] on the record of [model] with primary key [id].
  Future<BeakRecord> patch(
    BeakModel model,
    Object id,
    Iterable<BeakFieldValue> values,
  ) => update(model.table, id, model.record(values));
}
