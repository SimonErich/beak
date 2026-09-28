import 'package:beak/migrations.dart';

import '../models/models.dart';
import 'foodio_clock.dart';
import 'foodio_money.dart';
import 'foodio_invoice_rules.dart';
import '_redelivery_input.dart';
import 'foodio_payment.dart';

/// Order invariants evaluated against the complete proposed graph, in its transaction.
final class FoodioOrderPreparer {
  /// Binds the shared model registry and deterministic clock.
  const FoodioOrderPreparer(this.registry, {this.clock = const FoodioClock()});

  /// Registered models used to interpret typed graph relationships.
  final BeakModelRegistry registry;

  /// Source for cutoffs and audit timestamps.
  final FoodioClock clock;

  /// Validates the full candidate and reserves capacity inside its transaction.
  Future<BeakSavePlan> prepare(
    BeakSavePlan plan,
    WormDataSource source,
    BeakPrincipal? principal,
  ) async {
    var graph = await BeakCandidateGraph.open(
      plan: plan,
      source: source,
      registry: registry,
    );
    final orders = <BeakRecordRef>{};
    for (final operation in plan.operations) {
      final node = await graph.load(operation.target);
      if (operation.kind == BeakSaveOperationKind.create) {
        graph.patch(
          node,
          const BeakValidation().applyDefaults(node.model, node.record),
        );
      }
      if ({
        'order_activities',
        'payment_attempts',
        'message_deliveries',
      }.contains(operation.target.table)) {
        _invalid('activities', 'Activity history is written by the server.');
      }
      if (operation.target.table == 'budget_accounts' &&
          ['reserved_cents', 'spent_cents'].any(
            (key) =>
                operation.values.values.containsKey(key) &&
                operation.values[key]?.raw != (node.initial?[key]?.raw ?? 0),
          )) {
        _invalid(
          'reserved_cents',
          'Budget reservations are managed by order actions.',
        );
      }
      if (operation.target.table == 'delivery_slots' &&
          operation.values.values.containsKey('reserved_orders') &&
          operation.values['reserved_orders']?.raw !=
              (node.initial?['reserved_orders']?.raw ?? 0)) {
        _invalid(
          'reserved_orders',
          'Slot reservations are managed by order actions.',
        );
      }
      if (operation.target.table == 'app_settings' &&
          [
            node.read(AppSettingModel.key),
            node.original(AppSettingModel.key),
          ].any({'nextOrderNumber', 'foodioSeedVersion'}.contains)) {
        _invalid(
          'key',
          'Internal sequence and seed settings are managed by the server.',
        );
      }
      switch (operation.target.table) {
        case 'orders':
          orders.add(node.ref);
        case 'order_items':
          final owner = node.reference(OrderItemModel.order);
          if (owner != null) orders.add(owner);
          if (node.initial != null && node.hasChanged(OrderItemModel.orderId)) {
            _invalid(
              'order_id',
              'An existing item cannot move between orders.',
            );
          }
        case 'order_item_options':
          final item = await graph.linked(node, OrderItemOptionModel.orderItem);
          final owner = item?.reference(OrderItemModel.order);
          if (owner != null) orders.add(owner);
        case 'order_notes':
          if (node.deleted ||
              node.initial != null && node.materiallyChanged()) {
            _invalid('notes', 'Saved notes are part of the audit trail.');
          }
          if (node.initial == null) {
            graph.write(node, OrderNoteModel.author, _actor(principal));
            graph.write(node, OrderNoteModel.occurredAt, clock.now);
          }
        case 'delivery_slots':
          if ((node.read(DeliverySlotModel.capacity) ?? 0) <
              (node.read(DeliverySlotModel.reservedOrders) ?? 0)) {
            _invalid(
              'capacity',
              'Capacity cannot be lower than booked orders.',
            );
          }
          if ((node.read(DeliverySlotModel.endMinute) ?? 0) <=
              (node.read(DeliverySlotModel.startMinute) ?? 0)) {
            _invalid('end_minute', 'A slot must end after it starts.');
          }
        case 'budget_accounts':
          if ((node.read(BudgetAccountModel.allowanceCents) ?? 0) <
              (node.read(BudgetAccountModel.reservedCents) ?? 0) +
                  (node.read(BudgetAccountModel.spentCents) ?? 0)) {
            _invalid(
              'allowance_cents',
              'The allowance cannot be lower than committed spending.',
            );
          }
      }
    }
    graph = await _initializeProfileBudgets(graph, source, orders);
    final activities = <BeakSaveOperation>[];
    for (final ref in orders) {
      final order = await graph.load(ref);
      if (order.deleted) {
        continue; // The shared workflow allows deleting only drafts.
      }
      final command = ref == plan.root ? plan.action : null;
      if (command == 'reschedule') {
        graph.write(
          order,
          OrderModel.deliveryDate,
          RedeliveryInputModel.deliveryDate.readFrom(plan.arguments),
        );
        graph.write(
          order,
          OrderModel.slotId,
          RedeliveryInputModel.slotId.readFrom(plan.arguments),
        );
      }
      if (command == 'addNote') {
        for (final operation in plan.operations) {
          final candidate = await graph.load(operation.target);
          if (operation.kind != BeakSaveOperationKind.update ||
              candidate.materiallyChanged()) {
            _invalid('notes', 'Save order changes before adding a note.');
          }
        }
      } else {
        await _order(graph, order, source, command, principal);
      }
      final note = OrderNoteModel.body.readFrom(plan.arguments)?.trim() ?? '';
      if (command == 'addNote' || command == 'amend' && note.isNotEmpty) {
        activities.add(
          BeakSaveOperation(
            id: 'note',
            kind: BeakSaveOperationKind.create,
            target: BeakRecordRef.draft('order_notes', 'note:${plan.saveId}'),
            references: {'order_id': ref},
            values: BeakRecord.fromRow({
              'body': note,
              'author': _actor(principal),
              'occurred_at': clock.now,
              'visibility': 'internal',
            }),
          ),
        );
      }
      if (order.initial == null ||
          order.materiallyChanged() ||
          command != null) {
        activities.add(
          BeakSaveOperation(
            id: 'audit:${activities.length}',
            kind: BeakSaveOperationKind.create,
            target: BeakRecordRef.draft(
              'order_activities',
              'audit:${plan.saveId}:${activities.length}',
            ),
            references: {'order_id': order.ref},
            values: BeakRecord.fromRow({
              'title': command == null
                  ? (order.initial == null ? 'Draft created' : 'Order updated')
                  : _actionTitle(command),
              'actor': _actor(principal),
              'kind': command ?? 'edited',
              'description': command == null || command == 'amend'
                  ? _changeDescription(order)
                  : '',
              'save_key': plan.saveId,
              'occurred_at': clock.now,
            }),
          ),
        );
      }
    }
    await FoodioInvoiceRules.prepare(graph, source);
    final prepared = graph.build();
    return BeakSavePlan(
      saveId: prepared.saveId,
      root: prepared.root,
      action: prepared.action,
      arguments: prepared.arguments,
      operations: [...prepared.operations, ...activities],
    );
  }

  Future<BeakCandidateGraph> _initializeProfileBudgets(
    BeakCandidateGraph graph,
    WormDataSource source,
    Set<BeakRecordRef> orders,
  ) async {
    final additions = <BeakSaveOperation>[];
    final occupied = graph.plan.operations.map((op) => op.id).toSet();
    for (final profile in graph.nodes.where(
      (node) =>
          node.model.table == 'delivery_profiles' &&
          node.initial == null &&
          !node.deleted &&
          node.read(DeliveryProfileModel.kind) == 'company' &&
          node.reference(DeliveryProfileModel.organization) != null,
    )) {
      final periods = {clock.today.toString().substring(0, 7)};
      for (final ref in orders) {
        final order = await graph.load(ref);
        final date = order.read(OrderModel.deliveryDate);
        if (order.reference(OrderModel.profile) == profile.ref &&
            order.read(OrderModel.status) != OrderStatus.draft &&
            date != null) {
          periods.add(date.toString().substring(0, 7));
        }
      }
      final ledgers = await graph.children(
        profile,
        DeliveryProfileModel.budgets,
      );
      for (final period in periods) {
        if (ledgers.any(
          (row) => row.read(BudgetAccountModel.period) == period,
        )) {
          continue;
        }
        var suffix = additions.length;
        while (occupied.contains('profile-budget:$suffix')) {
          suffix++;
        }
        final id = 'profile-budget:$suffix';
        occupied.add(id);
        additions.add(
          BeakSaveOperation(
            id: id,
            kind: BeakSaveOperationKind.create,
            target: BeakRecordRef.draft('budget_accounts', id),
            references: {'profile_id': profile.ref},
            values: BeakRecord.fromRow({
              'name': '${profile.read(DeliveryProfileModel.name)} · $period',
              'period': period,
              'allowance_cents': profile.read(
                DeliveryProfileModel.monthlyBudgetCents,
              ),
              'reserved_cents': 0,
              'spent_cents': 0,
            }),
          ),
        );
      }
    }
    if (additions.isEmpty) return graph;
    final prepared = graph.build();
    return BeakCandidateGraph.open(
      plan: BeakSavePlan(
        saveId: prepared.saveId,
        root: prepared.root,
        action: prepared.action,
        arguments: prepared.arguments,
        operations: [...prepared.operations, ...additions],
      ),
      source: source,
      registry: registry,
    );
  }

  Future<void> _order(
    BeakCandidateGraph graph,
    BeakCandidateNode order,
    WormDataSource source,
    String? action,
    BeakPrincipal? principal,
  ) async {
    final previousStatus =
        order.original(OrderModel.status) ?? OrderStatus.draft;
    final status = order.read(OrderModel.status) ?? OrderStatus.draft;
    final draft = status == OrderStatus.draft;
    final items = await graph.children(
      order,
      OrderModel.items,
      includeDeleted: true,
    );
    var linesChanged = items.any((item) => item.changed || item.deleted);
    for (final item in items.where((item) => !item.deleted)) {
      if ((await graph.children(
        item,
        OrderItemModel.fields.options,
        includeDeleted: true,
      )).any((option) => option.changed || option.deleted)) {
        linesChanged = true;
      }
    }
    final contentChanged =
        linesChanged ||
        order.materiallyChanged(
          except: {
            OrderModel.status,
            OrderModel.approvalStatus,
            OrderModel.allergyAcknowledged,
            OrderModel.updatedAt,
          },
        );
    if (order.initial != null &&
        previousStatus != OrderStatus.draft &&
        contentChanged &&
        action != 'reschedule') {
      final date = order.original(OrderModel.deliveryDate);
      if (date != null && clock.changesClosed(date)) {
        _invalid('delivery_date', 'The 10:30 change cutoff has passed.');
      }
      if ({
        OrderStatus.outForDelivery,
        OrderStatus.delivered,
        OrderStatus.cancelled,
      }.contains(previousStatus)) {
        _invalid('status', 'This order has finished editing.');
      }
      if (previousStatus == OrderStatus.inKitchen &&
          (order.hasChanged(OrderModel.customerId) ||
              order.hasChanged(OrderModel.profileId) ||
              order.hasChanged(OrderModel.deliveryDate))) {
        _invalid(
          'delivery_date',
          'Customer, profile and delivery date are locked once preparation starts.',
        );
      }
    }
    graph.write(
      order,
      OrderModel.paymentStatus,
      order.original(OrderModel.paymentStatus) ?? PaymentStatus.unpaid,
    );
    if (order.initial == null) {
      graph.write(order, OrderModel.number, 0);
      graph.write(order, OrderModel.reference, 'Draft');
      graph.write(order, OrderModel.series, '2026');
    } else {
      _retain(graph, order, [
        'number',
        'reference',
        'series',
        'placed_at',
        'kitchen_started_at',
        'dispatched_at',
        'delivered_at',
        'cancelled_at',
        'payment_link',
      ]);
    }
    final oldInvoice = order.originalReference(OrderModel.invoice);
    if (order.hasChanged(OrderModel.invoiceId) && oldInvoice != null) {
      final previousInvoice = await graph.load(oldInvoice);
      if (previousInvoice.read(InvoiceModel.status) != InvoiceStatus.draft) {
        _invalid(
          'invoice_id',
          'An order cannot be removed from an issued invoice.',
        );
      }
    }
    final invoice = await graph.linked(order, OrderModel.invoice);
    if (invoice != null &&
        invoice.read(InvoiceModel.status) != InvoiceStatus.draft &&
        (contentChanged || {'cancel', 'reject'}.contains(action))) {
      _invalid(
        'invoice_id',
        'Issued invoice amounts are locked. Resolve billing before changing this order.',
      );
    }
    final customer = await graph.linked(order, OrderModel.customer);
    final profile = await graph.linked(order, OrderModel.profile);
    if (profile != null &&
        profile.reference(DeliveryProfileModel.customer) !=
            order.reference(OrderModel.customer)) {
      _invalid('profile_id', 'Choose a profile belonging to this customer.');
    }
    if (profile != null && profile.read(DeliveryProfileModel.active) != true) {
      _invalid('profile_id', 'This delivery profile is inactive.');
    }
    final location = await graph.linked(order, OrderModel.location);
    final company = profile == null
        ? null
        : await graph.linked(profile, DeliveryProfileModel.organization);
    final paymentMode = order.read(OrderModel.paymentMode);
    if (!foodioPaymentLabels.containsKey(paymentMode)) {
      _invalid('payment_mode', 'Choose a supported payment method.');
    }
    if (!draft &&
        (action == 'place' || contentChanged) &&
        company == null &&
        foodioCompanyPaymentModes.contains(paymentMode)) {
      _invalid('payment_mode', 'Company billing requires a company profile.');
    }
    if (location != null &&
        location.reference(DeliveryLocationModel.organization) != null &&
        location.reference(DeliveryLocationModel.organization) !=
            profile?.reference(DeliveryProfileModel.organization)) {
      _invalid(
        'location_id',
        'This location does not belong to the selected company.',
      );
    }
    // Parent identity and labels are snapshots, never trusted caller projections.
    if (previousStatus == OrderStatus.draft ||
        order.hasChanged(OrderModel.profileId)) {
      graph.write(
        order,
        OrderModel.customerName,
        customer?.read(CustomerModel.name) ?? '',
      );
      graph.write(
        order,
        OrderModel.customerEmail,
        customer?.read(CustomerModel.email) ?? '',
      );
      graph.write(
        order,
        OrderModel.profileName,
        profile?.read(DeliveryProfileModel.name) ?? '',
      );
      graph.write(
        order,
        OrderModel.organizationName,
        company?.read(OrganizationModel.name) ?? '',
      );
      graph.link(order, OrderModel.organization, company?.ref);
    } else {
      _retain(graph, order, [
        'customer_name',
        'customer_email',
        'profile_name',
        'organization_name',
        'organization_id',
      ]);
    }
    if (location != null &&
        (order.initial == null || order.hasChanged(OrderModel.locationId)) &&
        location.read(DeliveryLocationModel.active) != true) {
      _invalid('location_id', 'Choose an active delivery location.');
    }
    final overrideAddress = order.read(OrderModel.addressOverride) ?? false;
    if (overrideAddress && location == null) {
      _invalid('location_id', 'Select a delivery location for this address.');
    }
    if (overrideAddress && location != null) {
      // A shipment may use another entrance/address inside the location's
      // delivery area, but must not silently move onto an unsupported route.
      if ((order.read(OrderModel.street) ?? '').trim().isEmpty) {
        _invalid('street', 'Enter the one-time delivery address.');
      }
      if ((order.read(OrderModel.postalCode) ?? '').trim() !=
              (location.read(DeliveryLocationModel.postalCode) ?? '').trim() ||
          (order.read(OrderModel.city) ?? '').trim().toLowerCase() !=
              (location.read(DeliveryLocationModel.city) ?? '')
                  .trim()
                  .toLowerCase()) {
        _invalid(
          'postal_code',
          'One-time addresses must stay in the selected location’s city and postal area.',
        );
      }
    }
    if (location != null &&
        (order.initial == null ||
            order.hasChanged(OrderModel.locationId) ||
            order.hasChanged(OrderModel.addressOverride) ||
            order.hasChanged(OrderModel.routeCode) ||
            order.hasChanged(OrderModel.deliveryMethod) ||
            !overrideAddress &&
                (order.hasChanged(OrderModel.street) ||
                    order.hasChanged(OrderModel.postalCode) ||
                    order.hasChanged(OrderModel.city)))) {
      if (!overrideAddress) {
        graph.write(
          order,
          OrderModel.street,
          location.read(DeliveryLocationModel.street),
        );
        graph.write(
          order,
          OrderModel.postalCode,
          location.read(DeliveryLocationModel.postalCode),
        );
        graph.write(
          order,
          OrderModel.city,
          location.read(DeliveryLocationModel.city),
        );
        graph.write(
          order,
          OrderModel.handover,
          location.read(DeliveryLocationModel.handover),
        );
      }
      graph.write(
        order,
        OrderModel.routeCode,
        location.read(DeliveryLocationModel.routeCode),
      );
      graph.write(
        order,
        OrderModel.deliveryMethod,
        location.read(DeliveryLocationModel.method),
      );
    }
    final money = <FoodioMoneyLine>[];
    final liveItems = items.where((line) => !line.deleted).toList();
    var count = 0;
    var menuChecked = false;
    for (final item in liveItems) {
      final dish = item.reference(OrderItemModel.dish);
      if (dish != null &&
          (action == 'place' ||
              item.initial == null ||
              item.hasChanged(OrderItemModel.dishId) ||
              item.hasChanged(OrderItemModel.variantId))) {
        if (!menuChecked) {
          final menu = profile == null
              ? null
              : await graph.linked(profile, DeliveryProfileModel.menuPlan);
          if (menu == null || menu.read(MenuPlanModel.active) != true) {
            _invalid(
              'profile_id',
              'Choose a profile with an active menu plan before adding dishes.',
            );
          }
          // The menu plan is a curated catalog tab, not an ordering restriction.
          // All dishes, Drinks and Desserts share the same active catalog;
          // _line validates the selected dish and variant authoritatively.
          menuChecked = true;
        }
      }
      await _line(graph, item);
      final quantity = item.read(OrderItemModel.quantity) ?? 0;
      if (quantity < 1) _invalid('quantity', 'Choose at least one portion.');
      count += quantity;
      money.add(
        FoodioMoneyLine(
          key: _key(item.ref),
          grossCents:
              ((item.read<int>(OrderItemModel.unitPriceCents) ?? 0) +
                  (item.read<int>(OrderItemModel.optionsPriceCents) ?? 0)) *
              quantity,
          taxBasisPoints: item.read(OrderItemModel.taxBasisPoints) ?? 1000,
          food: item.read(OrderItemModel.food) ?? true,
        ),
      );
    }
    final voucher = await graph.linked(order, OrderModel.voucher);
    final deliveryDate = order.read(OrderModel.deliveryDate);
    if (voucher != null && (draft || contentChanged || action == 'place')) {
      if (voucher.read(VoucherModel.active) != true) {
        _invalid('voucher_id', 'This voucher is inactive.');
      }
      final from = voucher.read(VoucherModel.validFrom);
      final until = voucher.read(VoucherModel.validUntil);
      if (deliveryDate != null &&
          (from != null &&
                  deliveryDate.toString().compareTo(from.toString()) < 0 ||
              until != null &&
                  deliveryDate.toString().compareTo(until.toString()) > 0)) {
        _invalid(
          'voucher_id',
          'This voucher is not valid for the delivery date.',
        );
      }
    }
    final refreshVoucher =
        previousStatus == OrderStatus.draft ||
        order.hasChanged(OrderModel.voucherId);
    if (refreshVoucher) {
      graph.write(
        order,
        OrderModel.voucherRateBasisPoints,
        voucher?.read(VoucherModel.percentBasisPoints) ?? 0,
      );
      graph.write(
        order,
        OrderModel.voucherMaximumDiscountCents,
        voucher?.read(VoucherModel.maximumDiscountCents),
      );
      graph.write(
        order,
        OrderModel.voucherFoodOnly,
        voucher?.read(VoucherModel.foodOnly) ?? true,
      );
      graph.write(
        order,
        OrderModel.voucherCode,
        voucher?.read(VoucherModel.code) ?? '',
      );
    } else {
      _retain(graph, order, [
        'voucher_rate_basis_points',
        'voucher_maximum_discount_cents',
        'voucher_food_only',
        'voucher_code',
      ]);
    }
    final FoodioTotals totals;
    try {
      totals = FoodioTotals.calculate(
        money,
        voucherBasisPoints: order.read(OrderModel.voucherRateBasisPoints) ?? 0,
        voucherCapCents: order.read(OrderModel.voucherMaximumDiscountCents),
        voucherFoodOnly: order.read(OrderModel.voucherFoodOnly) ?? true,
        manualDiscountCents: order.read(OrderModel.manualDiscountCents) ?? 0,
      );
    } on ArgumentError catch (error) {
      _invalid('manual_discount_cents', '${error.message}');
    }
    if (order.original(OrderModel.paymentStatus) == PaymentStatus.paid &&
        (totals.grossCents != order.original(OrderModel.grossCents) ||
            order.hasChanged(OrderModel.paymentMode) ||
            order.hasChanged(OrderModel.paymentMethodId))) {
      _invalid(
        'payment_mode',
        'Cancel and refund this paid order before changing its amount or payment method.',
      );
    }
    for (var index = 0; index < liveItems.length; index++) {
      final line = totals.lines[index];
      final node = liveItems[index];
      graph.write(node, OrderItemModel.grossCents, line.grossCents);
      graph.write(node, OrderItemModel.discountCents, line.discountCents);
      graph.write(node, OrderItemModel.netCents, line.netCents);
      graph.write(node, OrderItemModel.taxCents, line.taxCents);
    }
    graph.write(order, OrderModel.itemCount, count);
    graph.write(order, OrderModel.subtotalCents, totals.subtotalCents);
    graph.write(
      order,
      OrderModel.voucherDiscountCents,
      totals.voucherDiscountCents,
    );
    graph.write(order, OrderModel.discountCents, totals.discountCents);
    graph.write(order, OrderModel.grossCents, totals.grossCents);
    graph.write(order, OrderModel.netCents, totals.netCents);
    graph.write(order, OrderModel.taxCents, totals.taxCents);
    graph.write(order, OrderModel.foodTaxCents, totals.taxByRate[1000] ?? 0);
    graph.write(order, OrderModel.drinkTaxCents, totals.taxByRate[2000] ?? 0);
    if (!draft && status != OrderStatus.cancelled) {
      if (customer == null || profile == null) {
        _invalid(
          'customer_id',
          'Select a customer and profile before placing the order.',
        );
      }
      if (deliveryDate == null) {
        _invalid('delivery_date', 'Select a delivery date.');
      }
      if (liveItems.isEmpty) {
        _invalid('items', 'Add at least one dish or custom item.');
      }
      if ((order.read(OrderModel.deliveryNote) ?? '').length > 200) {
        _invalid('delivery_note', 'Use at most 200 characters.');
      }
      if (action == 'place' || contentChanged) {
        if (deliveryDate.toString().compareTo(clock.today.toString()) < 0) {
          _invalid('delivery_date', 'Delivery must not be in the past.');
        }
        if (clock.changesClosed(deliveryDate)) {
          _invalid('delivery_date', 'The 10:30 ordering cutoff has passed.');
        }
        if (!RegExp(
          r'^\+?[0-9][0-9 ()-]{9,20}$',
        ).hasMatch(order.read(OrderModel.contactPhone) ?? '')) {
          _invalid(
            'contact_phone',
            'Enter a complete phone number, including the country code for international numbers.',
          );
        }
        if ((order.read(OrderModel.street) ?? '').trim().isEmpty ||
            (order.read(OrderModel.postalCode) ?? '').trim().isEmpty) {
          _invalid('street', 'Enter the complete delivery address.');
        }
      }
      if (company != null &&
          (order.read(OrderModel.costCenter) ?? '').trim().isEmpty) {
        _invalid('cost_center', 'Choose a company cost center.');
      }
      if (company != null && (action == 'place' || contentChanged)) {
        final allowed = (company.read(OrganizationModel.costCenters) ?? '')
            .split(',')
            .map((value) => value.trim());
        if (!allowed.contains(
          (order.read(OrderModel.costCenter) ?? '').trim(),
        )) {
          _invalid(
            'cost_center',
            'Choose an allowed cost center for this company.',
          );
        }
      }
    }
    if (!draft && foodioSavedPaymentModes.contains(paymentMode)) {
      final method = await graph.linked(order, OrderModel.paymentMethod);
      if (method == null ||
          method.reference(PaymentMethodModel.customer) !=
              order.reference(OrderModel.customer) ||
          method.read(PaymentMethodModel.active) != true) {
        _invalid(
          'payment_method_id',
          'Choose an active payment method belonging to this customer.',
        );
      }
      final requiredKind = paymentMode == 'paypal' ? 'paypal' : 'card';
      if (method.read(PaymentMethodModel.kind) != requiredKind) {
        _invalid(
          'payment_method_id',
          'Choose a $requiredKind payment method for this payment mode.',
        );
      }
    }
    if (action == 'place') graph.write(order, OrderModel.placedAt, clock.now);
    if (action == 'place' ||
        !draft && order.hasChanged(OrderModel.paymentMode)) {
      graph.write(
        order,
        OrderModel.paymentStatus,
        foodioInvoicePaymentModes.contains(paymentMode)
            ? PaymentStatus.invoiced
            : PaymentStatus.pending,
      );
    }
    if (action == 'startKitchen') {
      graph.write(order, OrderModel.kitchenStartedAt, clock.now);
      graph.write(order, OrderModel.awaitingRelease, false);
    }
    if (action == 'dispatch') {
      graph.write(order, OrderModel.dispatchedAt, clock.now);
    }
    if (action == 'deliver') {
      graph.write(order, OrderModel.deliveredAt, clock.now);
    }
    if (action == 'cancel' || action == 'reject') {
      graph.write(order, OrderModel.cancelledAt, clock.now);
    }
    final exceedsThreshold =
        company != null &&
        totals.grossCents >
            (profile?.read(DeliveryProfileModel.approvalThresholdCents) ??
                4000);
    if (action == 'place' ||
        previousStatus == OrderStatus.draft ||
        contentChanged &&
            totals.grossCents > (order.original(OrderModel.grossCents) ?? 0)) {
      graph.write(
        order,
        OrderModel.approvalStatus,
        exceedsThreshold ? ApprovalStatus.pending : ApprovalStatus.notRequired,
      );
    }
    if (action == 'startKitchen' &&
        order.read(OrderModel.strictAllergy) == true &&
        order.read(OrderModel.allergyAcknowledged) != true) {
      _invalid(
        'allergy_acknowledged',
        'The kitchen must acknowledge this allergy note first.',
      );
    }
    if (action == 'place' && (order.read(OrderModel.number) ?? 0) == 0) {
      final rows = await source.adapter.select(
        QueryDescriptor(
          table: 'app_settings',
          where: const Field<String>('key').eq('nextOrderNumber'),
          limit: 1,
        ),
      );
      if (rows.isEmpty) {
        throw const BeakConfigurationException(
          'Order sequence is not configured.',
        );
      }
      final row = rows.first;
      final number = int.parse('${row['value']}');
      final changed = await source.adapter.update(
        UpdateDescriptor(
          table: 'app_settings',
          values: {'value': '${number + 1}'},
          where: const Field<Object>(
            'id',
          ).eq(row['id']!).and(const Field<Object>('value').eq(row['value']!)),
        ),
      );
      if (changed != 1) {
        throw const BeakConflictException(
          'The order sequence changed. Retry with a fresh save.',
        );
      }
      graph.write(order, OrderModel.number, number);
      graph.write(order, OrderModel.reference, 'ORD-$number');
    }
    await _reserve(graph, order, source, profile, totals.grossCents);
    _attention(graph, order, action);
  }

  Future<void> _line(BeakCandidateGraph graph, BeakCandidateNode item) async {
    final dish = await graph.linked(item, OrderItemModel.dish);
    final variant = await graph.linked(item, OrderItemModel.variant);
    final selected =
        item.initial == null ||
        item.hasChanged(OrderItemModel.dishId) ||
        item.hasChanged(OrderItemModel.variantId);
    if (dish != null && selected) {
      if (dish.read(DishModel.active) != true ||
          variant == null ||
          variant.read(DishVariantModel.active) != true) {
        _invalid('variant_id', 'Choose an active dish variant.');
      }
      if (variant.reference(DishVariantModel.dish) != dish.ref) {
        _invalid('variant_id', 'The variant belongs to another dish.');
      }
      graph.write(item, OrderItemModel.label, dish.read(DishModel.name));
      graph.write(
        item,
        OrderItemModel.unitPriceCents,
        variant.read(DishVariantModel.priceCents),
      );
      graph.write(
        item,
        OrderItemModel.variantName,
        variant.read(DishVariantModel.name),
      );
      graph.write(
        item,
        OrderItemModel.taxBasisPoints,
        dish.read(DishModel.taxBasisPoints),
      );
      graph.write(
        item,
        OrderItemModel.allergens,
        dish.read(DishModel.allergens),
      );
      graph.write(item, OrderItemModel.food, dish.read(DishModel.food));
    } else if (dish != null) {
      _retain(graph, item, [
        'label',
        'unit_price_cents',
        'variant_name',
        'tax_basis_points',
        'allergens',
        'food',
      ]);
    } else if ((item.read(OrderItemModel.label) ?? '').trim().isEmpty) {
      _invalid('label', 'Describe the custom item.');
    }
    var optionPrice = 0;
    for (final row in await graph.children(
      item,
      OrderItemModel.fields.options,
    )) {
      if (row.deleted) continue;
      final option = await graph.linked(row, OrderItemOptionModel.option);
      if (option == null ||
          option.reference(DishOptionModel.dish) != dish?.ref) {
        _invalid('option_id', 'Choose an option belonging to this dish.');
      }
      if (row.initial == null ||
          row.hasChanged(OrderItemOptionModel.optionId)) {
        if (option.read(DishOptionModel.active) != true) {
          _invalid('option_id', 'This option is inactive.');
        }
        graph.write(
          row,
          OrderItemOptionModel.label,
          option.read(DishOptionModel.name),
        );
        graph.write(
          row,
          OrderItemOptionModel.unitPriceCents,
          option.read(DishOptionModel.priceCents),
        );
        graph.write(
          row,
          OrderItemOptionModel.allergens,
          option.read(DishOptionModel.allergens),
        );
      } else {
        _retain(graph, row, ['label', 'unit_price_cents', 'allergens']);
      }
      optionPrice += row.read(OrderItemOptionModel.unitPriceCents) ?? 0;
    }
    graph.write(item, OrderItemModel.optionsPriceCents, optionPrice);
  }

  Future<void> _reserve(
    BeakCandidateGraph graph,
    BeakCandidateNode order,
    WormDataSource source,
    BeakCandidateNode? profile,
    int amount,
  ) async {
    final status = order.read(OrderModel.status) ?? OrderStatus.draft;
    final active =
        status != OrderStatus.draft && status != OrderStatus.cancelled;
    final consumed = order.original(OrderModel.kitchenStartedAt) != null;
    final hadCapacity = order.original(OrderModel.capacityReserved) ?? false;
    final oldSlot = order.originalReference(OrderModel.slot);
    final newSlot = order.reference(OrderModel.slot);
    final needsCapacity = active || consumed;
    if (active && newSlot == null) {
      _invalid('slot_id', 'Select a delivery slot.');
    }
    if (needsCapacity && newSlot != null) {
      final slot = await graph.load(newSlot);
      if (active &&
          (slot.read(DeliverySlotModel.active) != true ||
              slot.read(DeliverySlotModel.date) !=
                  order.read(OrderModel.deliveryDate))) {
        _invalid(
          'slot_id',
          'Choose an available slot for the selected delivery date.',
        );
      }
      if (!hadCapacity || oldSlot != newSlot) {
        await _counter(
          source,
          newSlot,
          'reserved_orders',
          1,
          'capacity',
          'slot_id',
        );
      }
    }
    if (hadCapacity &&
        oldSlot != null &&
        (!needsCapacity || oldSlot != newSlot)) {
      await _counter(
        source,
        oldSlot,
        'reserved_orders',
        -1,
        'capacity',
        'slot_id',
      );
    }
    graph.write(
      order,
      OrderModel.capacityReserved,
      needsCapacity && newSlot != null,
    );
    final companyBilling =
        profile?.reference(DeliveryProfileModel.organization) != null &&
        foodioCompanyPaymentModes.contains(order.read(OrderModel.paymentMode));
    final hadBudget = order.original(OrderModel.budgetReserved) ?? false;
    final previousAmount = order.original(OrderModel.budgetAmountCents) ?? 0;
    final oldBudget = order.originalReference(OrderModel.budgetAccount);
    BeakRecordRef? budget;
    final delivered = order.read(OrderModel.status) == OrderStatus.delivered;
    if (active && companyBilling && !delivered) {
      final date = order.read(OrderModel.deliveryDate)!;
      final period = date.toString().substring(0, 7);
      final rows = (await graph.children(
        profile!,
        DeliveryProfileModel.budgets,
      )).where((row) => row.read(BudgetAccountModel.period) == period).toList();
      if (rows.isEmpty) {
        _invalid(
          'profile_id',
          'This profile has no budget for the delivery month.',
        );
      }
      budget = rows.first.ref;
    }
    if (hadBudget && oldBudget != null && oldBudget != budget) {
      await _counter(
        source,
        oldBudget,
        'reserved_cents',
        -previousAmount,
        'allowance_cents',
        'profile_id',
        spentKey: 'spent_cents',
      );
    }
    if (delivered && hadBudget && oldBudget != null) {
      await _counter(
        source,
        oldBudget,
        'spent_cents',
        previousAmount,
        'allowance_cents',
        'profile_id',
        spentKey: 'reserved_cents',
      );
    }
    if (budget != null) {
      final delta =
          amount - (hadBudget && oldBudget == budget ? previousAmount : 0);
      if (delta != 0) {
        if (budget.id == null) {
          final ledger = await graph.load(budget);
          final reserved =
              (ledger.read(BudgetAccountModel.reservedCents) ?? 0) + delta;
          if (reserved < 0 ||
              reserved + (ledger.read(BudgetAccountModel.spentCents) ?? 0) >
                  (ledger.read(BudgetAccountModel.allowanceCents) ?? 0)) {
            _invalid(
              'profile_id',
              'Insufficient company budget. Choose an eligible private payment profile.',
            );
          }
          graph.write(ledger, BudgetAccountModel.reservedCents, reserved);
        } else {
          await _counter(
            source,
            budget,
            'reserved_cents',
            delta,
            'allowance_cents',
            'profile_id',
            spentKey: 'spent_cents',
          );
        }
      }
    }
    graph.link(order, OrderModel.budgetAccount, delivered ? oldBudget : budget);
    graph.write(order, OrderModel.budgetReserved, budget != null);
    graph.write(
      order,
      OrderModel.budgetAmountCents,
      budget == null ? 0 : amount,
    );
  }

  Future<void> _counter(
    WormDataSource source,
    BeakRecordRef ref,
    String key,
    int delta,
    String limitKey,
    String errorKey, {
    String? spentKey,
  }) async {
    final row = await source.adapter.selectOne(
      QueryDescriptor(
        table: ref.table,
        where: const Field<Object>('id').eq(ref.id!),
      ),
    );
    if (row == null) {
      _invalid(errorKey, 'The reservation account no longer exists.');
    }
    final before = row[key] as int;
    final after = before + delta;
    final used = spentKey == null ? 0 : row[spentKey] as int;
    if (after < 0 || after + used > (row[limitKey] as int)) {
      _invalid(
        errorKey,
        key == 'reserved_orders'
            ? 'This delivery slot is full.'
            : 'Insufficient company budget. Choose an eligible private payment profile.',
      );
    }
    final changed = await source.adapter.update(
      UpdateDescriptor(
        table: ref.table,
        values: {key: after},
        where: const Field<Object>(
          'id',
        ).eq(ref.id!).and(Field<int>(key).eq(before)),
      ),
    );
    if (changed != 1) {
      throw const BeakConflictException(
        'The reservation changed. Reload before trying again.',
      );
    }
  }

  void _attention(
    BeakCandidateGraph graph,
    BeakCandidateNode order,
    String? action,
  ) {
    var reason = '';
    var next = '';
    if (order.read(OrderModel.status) != OrderStatus.cancelled &&
        order.read(OrderModel.status) != OrderStatus.draft) {
      if (order.read(OrderModel.paymentStatus) == PaymentStatus.failed) {
        reason = 'Payment failed';
        next = 'retryPayment';
      } else if ({
        PaymentStatus.unpaid,
        PaymentStatus.pending,
      }.contains(order.read(OrderModel.paymentStatus))) {
        reason = 'Awaiting payment';
        next = 'sendPaymentLink';
      } else if (order.read(OrderModel.approvalStatus) ==
          ApprovalStatus.pending) {
        reason = 'Approval needed';
        next = 'requestApproval';
      } else if (order.read(OrderModel.status) == OrderStatus.onHold) {
        reason =
            order.original(OrderModel.attentionReason) ?? 'Delivery on hold';
        next = order.original(OrderModel.nextAction) ?? 'editAddress';
      } else if (order.read(OrderModel.strictAllergy) == true &&
          order.read(OrderModel.allergyAcknowledged) != true) {
        reason = 'Allergy note needs kitchen confirmation';
        next = 'acknowledgeAllergy';
      } else if (action != 'resolveChange' &&
          order.original(OrderModel.nextAction) == 'reviewChange') {
        reason = 'Change requested';
        next = 'reviewChange';
      }
    }
    graph.write(order, OrderModel.needsAttention, next.isNotEmpty);
    graph.write(order, OrderModel.attentionReason, reason);
    graph.write(order, OrderModel.nextAction, next);
  }

  static void _retain(
    BeakCandidateGraph graph,
    BeakCandidateNode node,
    List<String> keys,
  ) {
    if (node.initial == null) return;
    graph.patch(
      node,
      BeakRecord(
        values: {
          for (final key in keys)
            if (node.initial!.values.containsKey(key))
              key: node.initial!.values[key]!,
        },
      ),
    );
  }

  static String _key(BeakRecordRef ref) => '${ref.id ?? ref.draftId}';
  static String _actor(BeakPrincipal? principal) =>
      principal?.id == 'demo-worker' ? 'Automatic' : 'Marie Novak';
  static String _changeDescription(BeakCandidateNode node) {
    if (node.initial == null) return '';
    final derived = {
      for (final field in [
        OrderModel.budgetAccountId,
        OrderModel.budgetAmountCents,
        OrderModel.budgetReserved,
        OrderModel.capacityReserved,
        OrderModel.subtotalCents,
        OrderModel.voucherDiscountCents,
        OrderModel.discountCents,
        OrderModel.grossCents,
        OrderModel.netCents,
        OrderModel.taxCents,
        OrderModel.foodTaxCents,
        OrderModel.drinkTaxCents,
        OrderModel.itemCount,
      ])
        field.key,
    };
    final labels = {
      if (node.hasChanged(OrderModel.subtotalCents) ||
          node.hasChanged(OrderModel.itemCount))
        OrderModel.items.relation.label,
      for (final column in node.model.columns)
        if (!derived.contains(column.key) &&
            node.record[column.key] != node.initial![column.key])
          column.label,
    };
    return labels.join(', ');
  }

  static String _actionTitle(String action) =>
      const {
        'addNote': 'Internal note added',
        'amend': 'Order updated',
        'place': 'Order placed',
        'approve': 'Order approved',
        'reject': 'Order rejected',
        'cancel': 'Order cancelled',
        'startKitchen': 'Moved to in kitchen',
        'dispatch': 'Out for delivery',
        'deliver': 'Order delivered',
        'requestApproval': 'Approval requested',
        'sendPaymentLink': 'Payment link requested',
        'retryPayment': 'Payment retry requested',
        'acknowledgeAllergy': 'Allergy confirmed with kitchen',
        'reschedule': 'Redelivery scheduled',
        'resolveChange': 'Requested changes accepted',
      }[action] ??
      action;
  static Never _invalid(String field, String message) =>
      throw BeakValidationException(
        message,
        fieldErrors: {
          field: [message],
        },
      );
}
