import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../../users/models/user.dart';
import '../../users/models/user_profile_connection.dart';
import 'order_item.dart';
import 'order_discount.dart';

part 'order.beak.dart';

/// Fulfilment states of a shop order.
enum OrderStatus {
  /// Order still being prepared.
  draft,

  /// Order accepted for fulfilment.
  confirmed,

  /// Items being packed.
  packing,

  /// Dispatched to the customer.
  shipped,

  /// Delivered to the customer.
  delivered,

  /// Cancelled order retained for reference.
  cancelled,
}

/// Order schema; all metadata and typed helpers are generated.
@Resource()
final class Order extends BeakSchema {
  // --8<-- [start:OrderValidationRules]
  /// Shared delivery eligibility and complete-order validation.
  static List<BeakRecordRule> get validationRules => [
    BeakCount(OrderModel.items, min: 1),
    BeakExists(
      OrderModel.profileId,
      UserProfileConnectionModel.id,
      matching: [
        BeakFieldMatch(
          target: UserProfileConnectionModel.userId,
          source: OrderModel.customerId,
        ),
      ],
    ),
  ];
  // --8<-- [end:OrderValidationRules]

  /// Human-readable order reference.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(80)])
  late final String reference;

  /// Current fulfilment state.
  @Column(defaultValue: OrderStatus.draft, filterable: true)
  late final OrderStatus status;

  /// Internal fulfilment notes.
  late final String? notes;

  /// The customer placing the order.
  @BelongsTo(
    searchOn: [#email, #firstName, #lastName],
    inverse: false,
    onDelete: BeakOnDelete.restrict,
  )
  late final User customer;

  /// One of the selected customer's profile associations.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final UserProfileConnection profile;

  /// Requested delivery instant; historical orders remain editable.
  @Column(sortable: true)
  late final DateTime deliveryDate;

  /// Owned line items, committed with the order.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<OrderItem> items;

  /// Owned discount adjustments, committed with the order.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<OrderDiscount> discounts;
}
