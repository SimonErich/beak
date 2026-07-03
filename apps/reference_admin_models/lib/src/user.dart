import 'package:beak_core/beak_core.dart';

/// Typed column constants of the users resource.
abstract final class UserColumns {
  /// Primary key.
  static const id = BeakStringColumn(
    key: 'id',
    label: 'Id',
    visibleOn: {BeakContext.detail},
  );

  /// Full name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(120)],
  );

  /// Login email.
  static const email = BeakStringColumn(
    key: 'email',
    label: 'Email',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakEmail()],
  );

  /// Whether the account may sign in.
  static const active = BeakBoolColumn(
    key: 'active',
    label: 'Active',
    filterable: true,
    trueLabel: 'Active',
    falseLabel: 'Disabled',
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [id, name, email, active];
}

/// Typed relationship constants of the users resource.
abstract final class UserRelations {
  /// The orders a user placed.
  static const orders = BeakHasMany(
    key: 'orders',
    label: 'Orders',
    relatedTable: 'orders',
    displayColumnKey: 'reference',
    foreignKey: 'user_id',
  );
}

/// The users resource: the store's customers.
final class UserModel extends BeakModel {
  /// Creates the users model.
  const UserModel();

  @override
  String get table => 'users';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => UserColumns.values;

  @override
  List<BeakRelationship> get relationships => const [UserRelations.orders];
}
