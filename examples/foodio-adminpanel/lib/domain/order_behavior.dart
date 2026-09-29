import 'package:beak/beak.dart';

import '../models/models.dart';
import '_order_note_input.dart';
import '_redelivery_input.dart';
import 'foodio_clock.dart';

/// The order commands, each declared once. Screens, lists and the server
/// preparer refer to these objects, never to their wire names.
abstract final class OrderActions {
  /// Saves edits to an order that has not left the kitchen.
  static final amend = BeakModelAction(
    name: 'amend',
    label: 'Save changes',
    inputModel: const OrderNoteInputModel(required: false),
    availableWhen: (record) => !{
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
      OrderStatus.cancelled,
    }.contains(OrderModel.status.readFrom(record)),
  );

  /// Adds an internal note without changing the order.
  static const addNote = BeakModelAction(
    name: 'addNote',
    label: 'Add note',
    inputModel: OrderNoteInputModel(),
  );

  /// Confirms a draft order; allowed while creating it.
  static final place = BeakModelAction(
    name: 'place',
    label: 'Place order',
    allowOnCreate: true,
    availableWhen: (record) =>
        OrderModel.status.readFrom(record) == OrderStatus.draft,
    values: [
      BeakValueBehavior.derived(
        field: OrderModel.status,
        resolve: (_) => OrderStatus.confirmed,
      ),
    ],
  );

  /// Approves an order waiting for approval.
  static final approve = BeakModelAction(
    name: 'approve',
    label: 'Approve order',
    availableWhen: (record) =>
        _activeOrder(record) &&
        OrderModel.approvalStatus.readFrom(record) == ApprovalStatus.pending,
    values: [
      BeakValueBehavior.derived(
        field: OrderModel.approvalStatus,
        resolve: (_) => ApprovalStatus.approved,
      ),
    ],
  );

  /// Rejects an order waiting for approval and cancels it.
  static final reject = BeakModelAction(
    name: 'reject',
    label: 'Reject order',
    availableWhen: (record) =>
        _activeOrder(record) &&
        OrderModel.approvalStatus.readFrom(record) == ApprovalStatus.pending,
    values: [
      BeakValueBehavior.derived(
        field: OrderModel.approvalStatus,
        resolve: (_) => ApprovalStatus.rejected,
      ),
      BeakValueBehavior.derived(
        field: OrderModel.status,
        resolve: (_) => OrderStatus.cancelled,
      ),
    ],
  );

  /// Cancels a confirmed, held or in-kitchen order.
  static final cancel = BeakModelAction(
    name: 'cancel',
    label: 'Cancel order',
    availableWhen: (record) => {
      OrderStatus.confirmed,
      OrderStatus.onHold,
      OrderStatus.inKitchen,
    }.contains(OrderModel.status.readFrom(record)),
    values: [
      BeakValueBehavior.derived(
        field: OrderModel.status,
        resolve: (_) => OrderStatus.cancelled,
      ),
    ],
  );

  /// Moves a paid or invoiced order into the kitchen.
  static final startKitchen = BeakModelAction(
    name: 'startKitchen',
    label: 'Start preparation',
    availableWhen: (record) =>
        OrderModel.status.readFrom(record) == OrderStatus.confirmed &&
        OrderModel.approvalStatus.readFrom(record) != ApprovalStatus.pending &&
        {
          PaymentStatus.paid,
          PaymentStatus.invoiced,
        }.contains(OrderModel.paymentStatus.readFrom(record)),
    values: [
      BeakValueBehavior.derived(
        field: OrderModel.status,
        resolve: (_) => OrderStatus.inKitchen,
      ),
    ],
  );

  /// Sends a prepared order out for delivery.
  static final dispatch = BeakModelAction(
    name: 'dispatch',
    label: 'Out for delivery',
    availableWhen: (record) =>
        OrderModel.status.readFrom(record) == OrderStatus.inKitchen,
    values: [
      BeakValueBehavior.derived(
        field: OrderModel.status,
        resolve: (_) => OrderStatus.outForDelivery,
      ),
    ],
  );

  /// Marks an order in transit as delivered.
  static final deliver = BeakModelAction(
    name: 'deliver',
    label: 'Mark delivered',
    availableWhen: (record) =>
        OrderModel.status.readFrom(record) == OrderStatus.outForDelivery,
    values: [
      BeakValueBehavior.derived(
        field: OrderModel.status,
        resolve: (_) => OrderStatus.delivered,
      ),
    ],
  );

  /// Asks for a payment link to be sent to the customer.
  static final sendPaymentLink = BeakModelAction(
    name: 'sendPaymentLink',
    label: 'Send payment link',
    availableWhen: (record) =>
        _activeOrder(record) &&
        {
          PaymentStatus.unpaid,
          PaymentStatus.pending,
          PaymentStatus.failed,
        }.contains(OrderModel.paymentStatus.readFrom(record)),
  );

  /// Asks for a failed card payment to be retried.
  static final retryPayment = BeakModelAction(
    name: 'retryPayment',
    label: 'Retry payment',
    availableWhen: (record) =>
        _activeOrder(record) &&
        OrderModel.paymentStatus.readFrom(record) == PaymentStatus.failed,
  );

  /// Asks the approver to review a pending order.
  static final requestApproval = BeakModelAction(
    name: 'requestApproval',
    label: 'Ask for approval',
    availableWhen: (record) =>
        _activeOrder(record) &&
        OrderModel.approvalStatus.readFrom(record) == ApprovalStatus.pending,
  );

  /// Records that the kitchen confirmed a strict allergy.
  static final acknowledgeAllergy = BeakModelAction(
    name: 'acknowledgeAllergy',
    label: 'Confirm with kitchen',
    availableWhen: (record) =>
        _activeOrder(record) &&
        OrderModel.strictAllergy.readFrom(record) == true &&
        OrderModel.allergyAcknowledged.readFrom(record) != true,
    values: [
      BeakValueBehavior.derived(
        field: OrderModel.allergyAcknowledged,
        resolve: (_) => true,
      ),
    ],
  );

  /// Schedules the redelivery of an order on hold.
  static final reschedule = BeakModelAction(
    name: 'reschedule',
    label: 'Schedule redelivery',
    inputModel: const RedeliveryInputModel(),
    availableWhen: (record) =>
        OrderModel.status.readFrom(record) == OrderStatus.onHold,
    values: [
      BeakValueBehavior.derived(
        field: OrderModel.status,
        resolve: (_) => OrderStatus.confirmed,
      ),
    ],
  );

  /// Accepts changes the customer requested.
  static final resolveChange = BeakModelAction(
    name: 'resolveChange',
    label: 'Accept requested changes',
    availableWhen: (record) =>
        _activeOrder(record) &&
        OrderModel.nextAction.readFrom(record) == 'reviewChange',
  );

  /// Every order command, in the order menus offer them.
  static final List<BeakModelAction> all = [
    amend,
    addNote,
    place,
    approve,
    reject,
    cancel,
    startKitchen,
    dispatch,
    deliver,
    sendPaymentLink,
    retryPayment,
    requestApproval,
    acknowledgeAllergy,
    reschedule,
    resolveChange,
  ];
}

/// The same transitions drive action menus and authoritative API validation.
BeakModelBehavior get foodioOrderBehavior => BeakModelBehavior(
  values: [
    BeakValueBehavior.initial(
      field: OrderModel.deliveryDate,
      resolve: (_) => BeakDate.fromDateTime(
        const FoodioClock().local.add(const Duration(days: 1)),
      ),
    ),
    BeakValueBehavior.suggested(
      field: OrderModel.profileId,
      dependencies: [OrderModel.customer.profiles],
      resolve: (state) {
        final profiles = state.read(OrderModel.customer.profiles) ?? const [];
        return profiles
            .where(
              (profile) =>
                  DeliveryProfileModel.active.readFrom(profile) == true &&
                  DeliveryProfileModel.isDefault.readFrom(profile) == true,
            )
            .map(DeliveryProfileModel.id.readFrom)
            .firstOrNull;
      },
    ),
    BeakValueBehavior.suggested(
      field: OrderModel.locationId,
      dependencies: [OrderModel.profile.locationId],
      resolve: (state) => state.read(OrderModel.profile.locationId),
    ),
    BeakValueBehavior.suggested(
      field: OrderModel.organizationId,
      dependencies: [OrderModel.profile.organizationId],
      resolve: (state) => state.read(OrderModel.profile.organizationId),
    ),
    BeakValueBehavior.suggested(
      field: OrderModel.paymentMode,
      dependencies: [OrderModel.profile.paymentMode],
      resolve: (state) =>
          state.read(OrderModel.profile.paymentMode) ?? 'monthlyInvoice',
    ),
    BeakValueBehavior.suggested(
      field: OrderModel.paymentMethodId,
      dependencies: [
        OrderModel.customer.paymentMethods,
        OrderModel.paymentMode,
      ],
      resolve: (state) {
        final mode = state.read(OrderModel.paymentMode);
        final kind = switch (mode) {
          'card' || 'subsidyCard' => 'card',
          'paypal' => 'paypal',
          _ => null,
        };
        if (kind == null) return null;
        final methods =
            (state.read(OrderModel.customer.paymentMethods) ??
                    const <BeakRecord>[])
                .where(
                  (method) =>
                      PaymentMethodModel.active.readFrom(method) == true &&
                      PaymentMethodModel.kind.readFrom(method) == kind,
                )
                .toList();
        final selected = state.read(OrderModel.paymentMethodId);
        if (methods.any(
          (method) => PaymentMethodModel.id.readFrom(method) == selected,
        )) {
          return selected;
        }
        final preferred = methods
            .where(
              (method) => PaymentMethodModel.isDefault.readFrom(method) == true,
            )
            .firstOrNull;
        return PaymentMethodModel.id.readFrom(
          preferred ?? (methods.firstOrNull ?? const BeakRecord(values: {})),
        );
      },
    ),
    BeakValueBehavior.suggested(
      field: OrderModel.costCenter,
      dependencies: [OrderModel.profile.costCenter],
      resolve: (state) => state.read(OrderModel.profile.costCenter) ?? '',
    ),
    BeakValueBehavior.suggested(
      field: OrderModel.contactPhone,
      dependencies: [OrderModel.customer.phone],
      resolve: (state) => state.read(OrderModel.customer.phone) ?? '',
    ),
    BeakValueBehavior.suggested(
      field: OrderModel.street,
      dependencies: [
        OrderModel.locationId,
        OrderModel.location.street,
        OrderModel.profile.locationId,
        OrderModel.profile.location.street,
      ],
      resolve: (state) =>
          state.read(OrderModel.locationId) ==
              state.read(OrderModel.profile.locationId)
          ? state.read(OrderModel.profile.location.street) ?? ''
          : state.read(OrderModel.location.street) ?? '',
    ),
    BeakValueBehavior.suggested(
      field: OrderModel.postalCode,
      dependencies: [
        OrderModel.locationId,
        OrderModel.location.postalCode,
        OrderModel.profile.locationId,
        OrderModel.profile.location.postalCode,
      ],
      resolve: (state) =>
          state.read(OrderModel.locationId) ==
              state.read(OrderModel.profile.locationId)
          ? state.read(OrderModel.profile.location.postalCode) ?? ''
          : state.read(OrderModel.location.postalCode) ?? '',
    ),
    BeakValueBehavior.suggested(
      field: OrderModel.city,
      dependencies: [
        OrderModel.locationId,
        OrderModel.location.city,
        OrderModel.profile.locationId,
        OrderModel.profile.location.city,
      ],
      resolve: (state) =>
          state.read(OrderModel.locationId) ==
              state.read(OrderModel.profile.locationId)
          ? state.read(OrderModel.profile.location.city) ?? 'Wien'
          : state.read(OrderModel.location.city) ?? 'Wien',
    ),
    BeakValueBehavior.suggested(
      field: OrderModel.handover,
      dependencies: [
        OrderModel.location.handover,
        OrderModel.profile.location.handover,
      ],
      resolve: (state) =>
          state.read(OrderModel.location.handover) ??
          state.read(OrderModel.profile.location.handover) ??
          '',
    ),
    BeakValueBehavior.suggested(
      field: OrderModel.deliveryMethod,
      dependencies: [OrderModel.profile.location.method],
      resolve: (state) =>
          state.read(OrderModel.profile.location.method) ?? 'office',
    ),
    BeakValueBehavior.suggested(
      field: OrderModel.routeCode,
      dependencies: [OrderModel.profile.location.routeCode],
      resolve: (state) =>
          state.read(OrderModel.profile.location.routeCode) ?? '',
    ),
  ],
  editableWhen: (record) => !{
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
    OrderStatus.cancelled,
  }.contains(OrderModel.status.readFrom(record)),
  deletableWhen: (record) =>
      OrderModel.status.readFrom(record) == OrderStatus.draft,
  actions: OrderActions.all,
);

// Operational commands exclude incomplete and terminal records. Notes are audit
// additions and intentionally retain their independent availability.
bool _activeOrder(BeakRecord record) => {
  OrderStatus.confirmed,
  OrderStatus.inKitchen,
  OrderStatus.outForDelivery,
  OrderStatus.onHold,
}.contains(OrderModel.status.readFrom(record));
