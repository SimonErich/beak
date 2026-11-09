import 'package:beak_core/beak_core.dart';
import 'package:meta/meta.dart';

/// The rows of one model a principal may touch, as a typed filter.
///
/// A scope narrows what an otherwise admitted model shows: every read and
/// write of the model is intersected with the filter built for the signed-in
/// principal. Build the filter from the model's own typed fields, so a rename
/// is a compile error and not a rule that silently matches nothing.
///
/// ```dart
/// final activeOrders = BeakRowScope(
///   const OrderModel(),
///   (principal) => OrderModel.cancelledAt.eq(null),
/// );
/// ```
///
/// Hand scopes to [BeakPolicies.admitted]. A scope returning `null` leaves
/// every row visible to that principal, and an anonymous request, which has no
/// principal to build the filter for, sees no rows at all.
@immutable
final class BeakRowScope {
  /// Scopes [model] by the filter [filter] builds for a principal.
  const BeakRowScope(this.model, this.filter);

  /// The model whose rows this scope narrows.
  final BeakModel model;

  /// The filter for [principal], or `null` for every row.
  final BeakFilter? Function(BeakPrincipal principal) filter;
}

/// The scope filters of [scopes] keyed by table.
///
/// Throws a [BeakConfigurationException] when a scope names a model outside
/// [registry] (it would never apply) or two scopes name the same model.
Map<String, BeakFilter? Function(BeakPrincipal principal)> beakRowScopesByTable(
  BeakModelRegistry registry,
  List<BeakRowScope> scopes,
) {
  final byTable = <String, BeakFilter? Function(BeakPrincipal principal)>{};
  for (final scope in scopes) {
    final table = scope.model.table;
    if (registry.byTable(table) == null) {
      throw BeakConfigurationException(
        'A row scope names the model "$table", which is not registered. '
        'Remove it, or register the model.',
      );
    }
    if (byTable.containsKey(table)) {
      throw BeakConfigurationException(
        'Model "$table" has more than one row scope.',
      );
    }
    byTable[table] = scope.filter;
  }
  return byTable;
}
