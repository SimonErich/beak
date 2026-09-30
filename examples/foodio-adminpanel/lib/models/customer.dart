import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../domain/foodio_clock.dart';
import 'delivery_profile.dart';
import 'payment_method.dart';
import 'order.dart';

part 'customer.beak.dart';

/// Customer configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class Customer extends BeakSchema {
  /// Order history supplies real customer totals to configured detail views.
  @HasMany(foreignKey: 'customer_id')
  late final List<Order> orders;

  /// Available profiles also supply the default for declarative order creation.
  @HasMany(foreignKey: 'customer_id')
  late final List<DeliveryProfile> profiles;

  /// Saved methods supply declarative payment choices for customer orders.
  @HasMany(foreignKey: 'customer_id')
  late final List<PaymentMethod> paymentMethods;

  // --8<-- [start:FoodioCustomerBehavior]
  /// Common identity and enrollment values are supplied in every presentation.
  static BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior.derived(
        field: CustomerModel.name,
        dependencies: [CustomerModel.firstName, CustomerModel.lastName],
        resolve: (state) => [
          state.read(CustomerModel.firstName),
          state.read(CustomerModel.lastName),
        ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' '),
      ),
      BeakValueBehavior.initial(
        field: CustomerModel.joinedAt,
        resolve: (_) => const FoodioClock().now,
      ),
    ],
  );
  // --8<-- [end:FoodioCustomerBehavior]

  /// Name.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// First name.
  @Column(searchable: true)
  late final String firstName;

  /// Last name.
  @Column(searchable: true)
  late final String lastName;

  /// Email.
  @Column(searchable: true, rules: [BeakEmail()])
  late final String email;

  /// Phone.
  @Column(searchable: true)
  late final String? phone;

  /// Allergens.
  @Column(defaultValue: '')
  late final String? allergens;

  /// Preferences.
  @Column(defaultValue: '')
  late final String? preferences;

  /// Joined at.
  @Column(sortable: true, filterable: true)
  late final DateTime joinedAt;

  /// Active.
  @Column(defaultValue: true)
  late final bool active;
}
