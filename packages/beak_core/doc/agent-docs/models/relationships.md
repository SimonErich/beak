# Relationships

> Declare typed connections and ownership for pickers and nested editing.

Use `@BelongsTo`, `@HasMany` and `@BelongsToMany` for to-one, owned or referenced collections, and pivot-backed connections. The generator resolves foreign-key identity types and emits typed relationship descriptors. Configure inverse relationships and deletion behavior deliberately.

A generated to-one descriptor provides `.inputCombobox()` and related field paths. A to-many descriptor provides `.tableForm()` and relation filters. Owned nested rows stay in the parent's draft until Save. Detaching a shared record is different from deleting an owned child; editor options and model ownership determine what is permitted.

`BeakExists` and `BeakFieldMatch` express eligibility. The picker infers filters and prerequisites from these rules, invalidates stale selections after a dependency changes, and supplies matching values when staging related creation. The backend checks eligibility independently.

Queries request eager relation loads explicitly. Related table and global-search paths use the same typed descriptors. See the order item and parent order models for ownership and optional product references.

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

- [Forms](../forms/form-screens.md)
- [Validation](validation.md)
