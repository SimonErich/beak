import '../model/beak_model.dart';
import '../query/beak_filter.dart';
import '../query/beak_pagination.dart';
import '../query/beak_record.dart';
import 'beak_data_source.dart';

/// Reads by model instead of by table name.
///
/// The typed way for server code to fetch a record: the table is derived from
/// the generated model, so nothing spells it out.
extension BeakDataSourceLookup on BeakDataSource {
  /// The record of [model] with primary key [id], or null when it is absent.
  Future<BeakRecord?> find(BeakModel model, Object id) =>
      getOne(model.table, id);

  /// The first record of [model] matching [filter], or null when none does.
  Future<BeakRecord?> findWhere(BeakModel model, BeakFilter filter) async {
    final page = await query(
      model.query(filter: filter, pagination: const BeakPagination(perPage: 1)),
    );
    return page.items.firstOrNull;
  }
}
