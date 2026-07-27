import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'order.dart';

part 'user.beak.dart';

/// Roles a customer account can hold.
enum UserRole {
  /// Sees only their own orders.
  customer,

  /// Sees everything.
  staff,
}

/// A customer of the store.
@Resource(timestamps: true)
final class User extends BeakSchema {
  /// Full name.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// Login email, unique across the store.
  @Column(searchable: true, sortable: true, unique: true, rules: [BeakEmail()])
  late final String email;

  /// What the account is allowed to see. Row policy reads this.
  @Column(filterable: true)
  late final UserRole role;

  /// Whether the account may sign in.
  @Column(filterable: true)
  late final bool active;

  /// The orders this customer placed.
  @HasMany(onDelete: BeakOnDelete.cascade)
  late final List<Order> orders;
}
