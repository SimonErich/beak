import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';
import '../domain/order_behavior.dart';

part 'order.beak.dart';

/// Order configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class Order extends BeakSchema {
  /// Named transactional actions and shared client-side workflow availability.
  static BeakModelBehavior get behavior => foodioOrderBehavior;

  /// Selected profile and payment identities belong to the chosen customer.
  static List<BeakRecordRule> get validationRules => [
    BeakExists(
      OrderModel.paymentMethodId,
      PaymentMethodModel.id,
      where: PaymentMethodModel.active.eq(true),
      matching: [
        BeakFieldMatch(
          target: PaymentMethodModel.customerId,
          source: OrderModel.customerId,
        ),
      ],
    ),
    BeakExists(
      OrderModel.profileId,
      DeliveryProfileModel.id,
      matching: [
        BeakFieldMatch(
          target: DeliveryProfileModel.customerId,
          source: OrderModel.customerId,
        ),
      ],
    ),
  ];

  /// Reference.
  @Display()
  @Column(searchable: true, sortable: true, defaultValue: 'Draft')
  late final String reference;

  /// Number.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int number;

  /// Series.
  @Column(defaultValue: '2026')
  late final String series;

  /// Status.
  @Column(defaultValue: OrderStatus.draft, filterable: true)
  @EnumLabels<OrderStatus>({
    OrderStatus.draft: 'Draft',
    OrderStatus.confirmed: 'Confirmed',
    OrderStatus.inKitchen: 'In kitchen',
    OrderStatus.outForDelivery: 'Out for delivery',
    OrderStatus.delivered: 'Delivered',
    OrderStatus.cancelled: 'Cancelled',
    OrderStatus.onHold: 'On hold',
  })
  @Badges<OrderStatus>({
    OrderStatus.draft: BeakColor.muted,
    OrderStatus.confirmed: BeakColor.info,
    OrderStatus.inKitchen: BeakColor.warning,
    OrderStatus.outForDelivery: BeakColor.primary,
    OrderStatus.delivered: BeakColor.success,
    OrderStatus.cancelled: BeakColor.muted,
    OrderStatus.onHold: BeakColor.error,
  })
  late final OrderStatus status;

  /// Payment status.
  @Column(defaultValue: PaymentStatus.unpaid, filterable: true)
  @EnumLabels<PaymentStatus>({
    PaymentStatus.unpaid: 'Unpaid',
    PaymentStatus.pending: 'Pending',
    PaymentStatus.paid: 'Paid',
    PaymentStatus.failed: 'Failed',
    PaymentStatus.invoiced: 'Company invoice',
    PaymentStatus.refunded: 'Refunded',
  })
  @Badges<PaymentStatus>({
    PaymentStatus.unpaid: BeakColor.muted,
    PaymentStatus.pending: BeakColor.warning,
    PaymentStatus.paid: BeakColor.success,
    PaymentStatus.failed: BeakColor.error,
    PaymentStatus.invoiced: BeakColor.info,
    PaymentStatus.refunded: BeakColor.muted,
  })
  late final PaymentStatus paymentStatus;

  /// Approval status.
  @Column(defaultValue: ApprovalStatus.notRequired, filterable: true)
  @EnumLabels<ApprovalStatus>({
    ApprovalStatus.notRequired: 'Not required',
    ApprovalStatus.pending: 'Pending approval',
    ApprovalStatus.approved: 'Approved',
    ApprovalStatus.rejected: 'Rejected',
  })
  @Badges<ApprovalStatus>({
    ApprovalStatus.notRequired: BeakColor.muted,
    ApprovalStatus.pending: BeakColor.warning,
    ApprovalStatus.approved: BeakColor.success,
    ApprovalStatus.rejected: BeakColor.error,
  })
  late final ApprovalStatus approvalStatus;

  /// Attention reason.
  @Column(defaultValue: '')
  late final String? attentionReason;

  /// Next action.
  @Column(defaultValue: '')
  late final String? nextAction;

  /// Scheduled orders awaiting operational release.
  @Column(defaultValue: false, filterable: true)
  late final bool awaitingRelease;

  /// Needs attention.
  @Column(defaultValue: false)
  late final bool needsAttention;

  /// Source.
  @Column(defaultValue: 'Admin')
  late final String source;

  /// Created by.
  @Column(defaultValue: 'Marie Novak')
  late final String createdBy;

  /// Placed at.
  @Column(sortable: true, filterable: true)
  late final DateTime? placedAt;

  /// Kitchen started at.
  @Column(sortable: true, filterable: true)
  late final DateTime? kitchenStartedAt;

  /// Dispatched at.
  @Column(sortable: true, filterable: true)
  late final DateTime? dispatchedAt;

  /// Delivered at.
  @Column(sortable: true, filterable: true)
  late final DateTime? deliveredAt;

  /// Cancelled at.
  @Column(sortable: true, filterable: true)
  late final DateTime? cancelledAt;

  /// Customer.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Customer? customer;

  /// Profile.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final DeliveryProfile? profile;

  /// Organization.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Organization? organization;

  /// Location.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final DeliveryLocation? location;

  /// Slot.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final DeliverySlot? slot;

  /// Budget account.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final BudgetAccount? budgetAccount;

  /// Voucher.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Voucher? voucher;

  /// Payment method.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final PaymentMethod? paymentMethod;

  /// Invoice.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Invoice? invoice;

  /// Delivery date.
  @Column(sortable: true, filterable: true)
  late final BeakDate? deliveryDate;

  /// Delivery method.
  @Column(defaultValue: 'office')
  late final String deliveryMethod;

  /// Route code.
  @Column(defaultValue: '')
  late final String? routeCode;

  /// Driver name.
  @Column(defaultValue: '')
  late final String? driverName;

  /// Use an order-only address inside the selected location’s delivery area.
  @Column(defaultValue: false)
  late final bool addressOverride;

  /// Street.
  @Column(defaultValue: '')
  late final String? street;

  /// Postal code.
  @Column(defaultValue: '')
  late final String? postalCode;

  /// City.
  @Column(defaultValue: 'Wien')
  late final String city;

  /// Handover.
  @Column(defaultValue: '')
  late final String? handover;

  /// Delivery note printed for the driver.
  @Column(defaultValue: '', rules: [BeakMaxLength(200)])
  late final String? deliveryNote;

  /// Contact phone.
  @Column(
    defaultValue: '',
    rules: [
      BeakPattern(
        r'^(?:|\+?[0-9][0-9 ()-]{9,20})$',
        message:
            'Enter a complete phone number, including the country code for international numbers.',
      ),
    ],
  )
  late final String? contactPhone;

  /// Cost center.
  @Column(defaultValue: '')
  late final String? costCenter;

  /// Payment mode.
  @Column(defaultValue: 'monthlyInvoice')
  late final String paymentMode;

  /// Customer name.
  @Column(defaultValue: '')
  late final String? customerName;

  /// Customer email.
  @Column(defaultValue: '')
  late final String? customerEmail;

  /// Organization name.
  @Column(defaultValue: '')
  late final String? organizationName;

  /// Profile name.
  @Column(defaultValue: '')
  late final String? profileName;

  /// Voucher code.
  @Column(defaultValue: '')
  late final String? voucherCode;

  /// Voucher percentage captured when this selection is placed.
  @Column(defaultValue: 0, rules: [BeakMin(0), BeakMax(10000)])
  late final int voucherRateBasisPoints;

  /// Captured voucher cap; null means unlimited.
  late final int? voucherMaximumDiscountCents;

  /// Captured restriction to food instead of beverages.
  @Column(defaultValue: true)
  late final bool voucherFoodOnly;

  /// Allergen note.
  @Column(defaultValue: '')
  late final String? allergenNote;

  /// Allergy acknowledged.
  @Column(defaultValue: false)
  late final bool allergyAcknowledged;

  /// Strict allergy.
  @Column(defaultValue: false)
  late final bool strictAllergy;

  /// Customer note.
  @Column(defaultValue: '')
  late final String? customerNote;

  /// Purchase order.
  @Column(defaultValue: '')
  late final String? purchaseOrder;

  /// Invoice text.
  @Column(defaultValue: '')
  late final String? invoiceText;

  /// Client info.
  @Column(defaultValue: '')
  late final String? clientInfo;

  /// Send confirmation.
  @Column(defaultValue: true)
  late final bool sendConfirmation;

  /// Capacity reserved.
  @Column(defaultValue: false)
  late final bool capacityReserved;

  /// Budget reserved.
  @Column(defaultValue: false)
  late final bool budgetReserved;

  /// Budget amount cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int budgetAmountCents;

  /// Subtotal cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int subtotalCents;

  /// Voucher discount cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int voucherDiscountCents;

  /// Manual discount cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int manualDiscountCents;

  /// Discount cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int discountCents;

  /// Gross cents.
  @Column(sortable: true, defaultValue: 0, rules: [BeakMin(0)])
  late final int grossCents;

  /// Net cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int netCents;

  /// Tax cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int taxCents;

  /// Food tax cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int foodTaxCents;

  /// Drink tax cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int drinkTaxCents;

  /// Item count.
  @Column(sortable: true, defaultValue: 0, rules: [BeakMin(0)])
  late final int itemCount;

  /// Payment link.
  @Column(defaultValue: '')
  late final String? paymentLink;

  /// Items.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<OrderItem> items;

  /// Notes.
  @HasMany(onDelete: BeakOnDelete.restrict)
  late final List<OrderNote> notes;

  /// Activities.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<OrderActivity> activities;
}
