# Colors and tokens

> Apply semantic colors consistently across built-in and custom content.

Beak UI uses the Obers UI theme for surfaces, borders, text and state colors. Column badges can map enum values to Beak colors while custom widgets resolve tokens from context.

Keep status meaning consistent between tables and forms. Use text or icons as well as color for important distinctions. Semantic formatting remains independent of theme colors. The order schema demonstrates state labels and shared metadata.

```dart title="examples/clean_beak_config/lib/resources/orders/models/order.dart"
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
```

## Continue reading

- [Theming basics](theming-basics.md)
- [Semantic fields](../models/semantic-fields.md)
