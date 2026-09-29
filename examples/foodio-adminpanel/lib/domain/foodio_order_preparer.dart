import 'package:beak/migrations.dart';

import '../models/models.dart';
import 'foodio_clock.dart';
import 'foodio_money.dart';
import 'foodio_invoice_rules.dart';
import '_redelivery_input.dart';
import 'foodio_payment.dart';
import 'order_behavior.dart';

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
      if (_serverWritten.any(operation.target.isOf)) {
        throw OrderModel.activities.invalid(
          'Activity history is written by the server.',
        );
      }
      if (node.isOf(const BudgetAccountModel()) &&
          [BudgetAccountModel.reservedCents, BudgetAccountModel.spentCents].any(
            (field) =>
                operation.sets(field) &&
                field.readFrom(operation.values) != (node.original(field) ?? 0),
          )) {
        throw BudgetAccountModel.reservedCents.invalid(
          'Budget reservations are managed by order actions.',
        );
      }
      if (node.isOf(const DeliverySlotModel()) &&
          operation.sets(DeliverySlotModel.reservedOrders) &&
          DeliverySlotModel.reservedOrders.readFrom(operation.values) !=
              (node.original(DeliverySlotModel.reservedOrders) ?? 0)) {
        throw DeliverySlotModel.reservedOrders.invalid(
          'Slot reservations are managed by order actions.',
        );
      }
      if (node.isOf(const AppSettingModel()) &&
          [
            node.read(AppSettingModel.key),
            node.original(AppSettingModel.key),
          ].any(_serverSettings.contains)) {
        throw AppSettingModel.key.invalid(
          'Internal sequence and seed settings are managed by the server.',
        );
      }
      switch (node.model) {
        case OrderModel():
          orders.add(node.ref);
        case OrderItemModel():
          final owner = node.reference(OrderItemModel.order);
          if (owner != null) orders.add(owner);
          if (node.initial != null && node.hasChanged(OrderItemModel.orderId)) {
            throw OrderItemModel.orderId.invalid(
              'An existing item cannot move between orders.',
            );
          }
        case OrderItemOptionModel():
          final item = await graph.linked(node, OrderItemOptionModel.orderItem);
          final owner = item?.reference(OrderItemModel.order);
          if (owner != null) orders.add(owner);
        case OrderNoteModel():
          if (node.deleted ||
              node.initial != null && node.materiallyChanged()) {
            throw OrderModel.notes.invalid(
              'Saved notes are part of the audit trail.',
            );
          }
          if (node.initial == null) {
            graph.write(node, OrderNoteModel.author, _actor(principal));
            graph.write(node, OrderNoteModel.occurredAt, clock.now);
          }
        case DeliverySlotModel():
          if ((node.read(DeliverySlotModel.capacity) ?? 0) <
              (node.read(DeliverySlotModel.reservedOrders) ?? 0)) {
            throw DeliverySlotModel.capacity.invalid(
              'Capacity cannot be lower than booked orders.',
            );
          }
          if ((node.read(DeliverySlotModel.endMinute) ?? 0) <=
              (node.read(DeliverySlotModel.startMinute) ?? 0)) {
            throw DeliverySlotModel.endMinute.invalid(
              'A slot must end after it starts.',
            );
          }
        case BudgetAccountModel():
          if ((node.read(BudgetAccountModel.allowanceCents) ?? 0) <
              (node.read(BudgetAccountModel.reservedCents) ?? 0) +
                  (node.read(BudgetAccountModel.spentCents) ?? 0)) {
            throw BudgetAccountModel.allowanceCents.invalid(
              'The allowance cannot be lower than committed spending.',
            );
          }
        default:
          break;
      }
    }
    graph = await _initializeProfileBudgets(graph, source, orders);
    final activities = <BeakSaveOperation>[];
    for (final ref in orders) {
      final order = await graph.load(ref);
      if (order.deleted) {
        continue; // The shared workflow allows deleting only drafts.
      }
      final command = ref == plan.root ? _commandOf(plan) : null;
      if (command == OrderActions.reschedule) {
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
      if (command == OrderActions.addNote) {
        for (final operation in plan.operations) {
          final candidate = await graph.load(operation.target);
          if (operation.kind != BeakSaveOperationKind.update ||
              candidate.materiallyChanged()) {
            throw OrderModel.notes.invalid(
              'Save order changes before adding a note.',
            );
          }
        }
      } else {
        await _order(graph, order, source, command, principal);
      }
      final note = OrderNoteModel.body.readFrom(plan.arguments)?.trim() ?? '';
      if (command == OrderActions.addNote ||
          command == OrderActions.amend && note.isNotEmpty) {
        activities.add(
          BeakSaveOperation.create(
            id: 'note',
            model: const OrderNoteModel(),
            draftId: 'note:${plan.saveId}',
            values: [
              OrderNoteModel.body.to(note),
              OrderNoteModel.author.to(_actor(principal)),
              OrderNoteModel.occurredAt.to(clock.now),
              OrderNoteModel.visibility.to('internal'),
            ],
            links: [OrderNoteModel.order.linkTo(ref)],
          ),
        );
      }
      if (order.initial == null ||
          order.materiallyChanged() ||
          command != null) {
        activities.add(
          BeakSaveOperation.create(
            id: 'audit:${activities.length}',
            model: const OrderActivityModel(),
            draftId: 'audit:${plan.saveId}:${activities.length}',
            values: [
              OrderActivityModel.title.to(
                command == null
                    ? (order.initial == null
                          ? 'Draft created'
                          : 'Order updated')
                    : _actionTitle(command),
              ),
              OrderActivityModel.actor.to(_actor(principal)),
              OrderActivityModel.kind.to(command?.name ?? 'edited'),
              OrderActivityModel.description.to(
                command == null || command == OrderActions.amend
                    ? _changeDescription(order)
                    : '',
              ),
              OrderActivityModel.saveKey.to(plan.saveId),
              OrderActivityModel.occurredAt.to(clock.now),
            ],
            links: [OrderActivityModel.order.linkTo(order.ref)],
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
          node.isOf(const DeliveryProfileModel()) &&
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
          BeakSaveOperation.create(
            id: id,
            model: const BudgetAccountModel(),
            draftId: id,
            values: [
              BudgetAccountModel.name.to(
                '${profile.read(DeliveryProfileModel.name)} · $period',
              ),
              BudgetAccountModel.period.to(period),
              BudgetAccountModel.allowanceCents.to(
                profile.read(DeliveryProfileModel.monthlyBudgetCents),
              ),
              BudgetAccountModel.reservedCents.to(0),
              BudgetAccountModel.spentCents.to(0),
            ],
            links: [BudgetAccountModel.profile.linkTo(profile.ref)],
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
    BeakModelAction? action,
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
        action != OrderActions.reschedule) {
      final date = order.original(OrderModel.deliveryDate);
      if (date != null && clock.changesClosed(date)) {
        throw OrderModel.deliveryDate.invalid(
          'The 10:30 change cutoff has passed.',
        );
      }
      if ({
        OrderStatus.outForDelivery,
        OrderStatus.delivered,
        OrderStatus.cancelled,
      }.contains(previousStatus)) {
        throw OrderModel.status.invalid('This order has finished editing.');
      }
      if (previousStatus == OrderStatus.inKitchen &&
          (order.hasChanged(OrderModel.customerId) ||
              order.hasChanged(OrderModel.profileId) ||
              order.hasChanged(OrderModel.deliveryDate))) {
        throw OrderModel.deliveryDate.invalid(
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
      graph.restore(order, [
        OrderModel.number,
        OrderModel.reference,
        OrderModel.series,
        OrderModel.placedAt,
        OrderModel.kitchenStartedAt,
        OrderModel.dispatchedAt,
        OrderModel.deliveredAt,
        OrderModel.cancelledAt,
        OrderModel.paymentLink,
      ]);
    }
    final oldInvoice = order.originalReference(OrderModel.invoice);
    if (order.hasChanged(OrderModel.invoiceId) && oldInvoice != null) {
      final previousInvoice = await graph.load(oldInvoice);
      if (previousInvoice.read(InvoiceModel.status) != InvoiceStatus.draft) {
        throw OrderModel.invoiceId.invalid(
          'An order cannot be removed from an issued invoice.',
        );
      }
    }
    final invoice = await graph.linked(order, OrderModel.invoice);
    if (invoice != null &&
        invoice.read(InvoiceModel.status) != InvoiceStatus.draft &&
        (contentChanged ||
            {OrderActions.cancel, OrderActions.reject}.contains(action))) {
      throw OrderModel.invoiceId.invalid(
        'Issued invoice amounts are locked. Resolve billing before changing this order.',
      );
    }
    final customer = await graph.linked(order, OrderModel.customer);
    final profile = await graph.linked(order, OrderModel.profile);
    if (profile != null &&
        profile.reference(DeliveryProfileModel.customer) !=
            order.reference(OrderModel.customer)) {
      throw OrderModel.profileId.invalid(
        'Choose a profile belonging to this customer.',
      );
    }
    if (profile != null && profile.read(DeliveryProfileModel.active) != true) {
      throw OrderModel.profileId.invalid('This delivery profile is inactive.');
    }
    final location = await graph.linked(order, OrderModel.location);
    final company = profile == null
        ? null
        : await graph.linked(profile, DeliveryProfileModel.organization);
    final paymentMode = order.read(OrderModel.paymentMode);
    if (!foodioPaymentLabels.containsKey(paymentMode)) {
      throw OrderModel.paymentMode.invalid(
        'Choose a supported payment method.',
      );
    }
    if (!draft &&
        (action == OrderActions.place || contentChanged) &&
        company == null &&
        foodioCompanyPaymentModes.contains(paymentMode)) {
      throw OrderModel.paymentMode.invalid(
        'Company billing requires a company profile.',
      );
    }
    if (location != null &&
        location.reference(DeliveryLocationModel.organization) != null &&
        location.reference(DeliveryLocationModel.organization) !=
            profile?.reference(DeliveryProfileModel.organization)) {
      throw OrderModel.locationId.invalid(
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
      graph.restore(order, [
        OrderModel.customerName,
        OrderModel.customerEmail,
        OrderModel.profileName,
        OrderModel.organizationName,
        OrderModel.organizationId,
      ]);
    }
    if (location != null &&
        (order.initial == null || order.hasChanged(OrderModel.locationId)) &&
        location.read(DeliveryLocationModel.active) != true) {
      throw OrderModel.locationId.invalid(
        'Choose an active delivery location.',
      );
    }
    final overrideAddress = order.read(OrderModel.addressOverride) ?? false;
    if (overrideAddress && location == null) {
      throw OrderModel.locationId.invalid(
        'Select a delivery location for this address.',
      );
    }
    if (overrideAddress && location != null) {
      // A shipment may use another entrance/address inside the location's
      // delivery area, but must not silently move onto an unsupported route.
      if ((order.read(OrderModel.street) ?? '').trim().isEmpty) {
        throw OrderModel.street.invalid('Enter the one-time delivery address.');
      }
      if ((order.read(OrderModel.postalCode) ?? '').trim() !=
              (location.read(DeliveryLocationModel.postalCode) ?? '').trim() ||
          (order.read(OrderModel.city) ?? '').trim().toLowerCase() !=
              (location.read(DeliveryLocationModel.city) ?? '')
                  .trim()
                  .toLowerCase()) {
        throw OrderModel.postalCode.invalid(
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
          (action == OrderActions.place ||
              item.initial == null ||
              item.hasChanged(OrderItemModel.dishId) ||
              item.hasChanged(OrderItemModel.variantId))) {
        if (!menuChecked) {
          final menu = profile == null
              ? null
              : await graph.linked(profile, DeliveryProfileModel.menuPlan);
          if (menu == null || menu.read(MenuPlanModel.active) != true) {
            throw OrderModel.profileId.invalid(
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
      if (quantity < 1) {
        throw OrderItemModel.quantity.invalid('Choose at least one portion.');
      }
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
    if (voucher != null &&
        (draft || contentChanged || action == OrderActions.place)) {
      if (voucher.read(VoucherModel.active) != true) {
        throw OrderModel.voucherId.invalid('This voucher is inactive.');
      }
      final from = voucher.read(VoucherModel.validFrom);
      final until = voucher.read(VoucherModel.validUntil);
      if (deliveryDate != null &&
          (from != null &&
                  deliveryDate.toString().compareTo(from.toString()) < 0 ||
              until != null &&
                  deliveryDate.toString().compareTo(until.toString()) > 0)) {
        throw OrderModel.voucherId.invalid(
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
      graph.restore(order, [
        OrderModel.voucherRateBasisPoints,
        OrderModel.voucherMaximumDiscountCents,
        OrderModel.voucherFoodOnly,
        OrderModel.voucherCode,
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
      throw OrderModel.manualDiscountCents.invalid('${error.message}');
    }
    if (order.original(OrderModel.paymentStatus) == PaymentStatus.paid &&
        (totals.grossCents != order.original(OrderModel.grossCents) ||
            order.hasChanged(OrderModel.paymentMode) ||
            order.hasChanged(OrderModel.paymentMethodId))) {
      throw OrderModel.paymentMode.invalid(
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
        throw OrderModel.customerId.invalid(
          'Select a customer and profile before placing the order.',
        );
      }
      if (deliveryDate == null) {
        throw OrderModel.deliveryDate.invalid('Select a delivery date.');
      }
      if (liveItems.isEmpty) {
        throw OrderModel.items.invalid('Add at least one dish or custom item.');
      }
      if ((order.read(OrderModel.deliveryNote) ?? '').length > 200) {
        throw OrderModel.deliveryNote.invalid('Use at most 200 characters.');
      }
      if (action == OrderActions.place || contentChanged) {
        if (deliveryDate.toString().compareTo(clock.today.toString()) < 0) {
          throw OrderModel.deliveryDate.invalid(
            'Delivery must not be in the past.',
          );
        }
        if (clock.changesClosed(deliveryDate)) {
          throw OrderModel.deliveryDate.invalid(
            'The 10:30 ordering cutoff has passed.',
          );
        }
        if (!RegExp(
          r'^\+?[0-9][0-9 ()-]{9,20}$',
        ).hasMatch(order.read(OrderModel.contactPhone) ?? '')) {
          throw OrderModel.contactPhone.invalid(
            'Enter a complete phone number, including the country code for international numbers.',
          );
        }
        if ((order.read(OrderModel.street) ?? '').trim().isEmpty ||
            (order.read(OrderModel.postalCode) ?? '').trim().isEmpty) {
          throw OrderModel.street.invalid(
            'Enter the complete delivery address.',
          );
        }
      }
      if (company != null &&
          (order.read(OrderModel.costCenter) ?? '').trim().isEmpty) {
        throw OrderModel.costCenter.invalid('Choose a company cost center.');
      }
      if (company != null && (action == OrderActions.place || contentChanged)) {
        final allowed = (company.read(OrganizationModel.costCenters) ?? '')
            .split(',')
            .map((value) => value.trim());
        if (!allowed.contains(
          (order.read(OrderModel.costCenter) ?? '').trim(),
        )) {
          throw OrderModel.costCenter.invalid(
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
        throw OrderModel.paymentMethodId.invalid(
          'Choose an active payment method belonging to this customer.',
        );
      }
      final requiredKind = paymentMode == 'paypal' ? 'paypal' : 'card';
      if (method.read(PaymentMethodModel.kind) != requiredKind) {
        throw OrderModel.paymentMethodId.invalid(
          'Choose a $requiredKind payment method for this payment mode.',
        );
      }
    }
    if (action == OrderActions.place) {
      graph.write(order, OrderModel.placedAt, clock.now);
    }
    if (action == OrderActions.place ||
        !draft && order.hasChanged(OrderModel.paymentMode)) {
      graph.write(
        order,
        OrderModel.paymentStatus,
        foodioInvoicePaymentModes.contains(paymentMode)
            ? PaymentStatus.invoiced
            : PaymentStatus.pending,
      );
    }
    if (action == OrderActions.startKitchen) {
      graph.write(order, OrderModel.kitchenStartedAt, clock.now);
      graph.write(order, OrderModel.awaitingRelease, false);
    }
    if (action == OrderActions.dispatch) {
      graph.write(order, OrderModel.dispatchedAt, clock.now);
    }
    if (action == OrderActions.deliver) {
      graph.write(order, OrderModel.deliveredAt, clock.now);
    }
    if (action == OrderActions.cancel || action == OrderActions.reject) {
      graph.write(order, OrderModel.cancelledAt, clock.now);
    }
    final exceedsThreshold =
        company != null &&
        totals.grossCents >
            (profile?.read(DeliveryProfileModel.approvalThresholdCents) ??
                4000);
    if (action == OrderActions.place ||
        previousStatus == OrderStatus.draft ||
        contentChanged &&
            totals.grossCents > (order.original(OrderModel.grossCents) ?? 0)) {
      graph.write(
        order,
        OrderModel.approvalStatus,
        exceedsThreshold ? ApprovalStatus.pending : ApprovalStatus.notRequired,
      );
    }
    if (action == OrderActions.startKitchen &&
        order.read(OrderModel.strictAllergy) == true &&
        order.read(OrderModel.allergyAcknowledged) != true) {
      throw OrderModel.allergyAcknowledged.invalid(
        'The kitchen must acknowledge this allergy note first.',
      );
    }
    if (action == OrderActions.place &&
        (order.read(OrderModel.number) ?? 0) == 0) {
      final sequence = await source.findWhere(
        const AppSettingModel(),
        AppSettingModel.key.eq(_orderSequenceSetting),
      );
      if (sequence == null) {
        throw const BeakConfigurationException(
          'Order sequence is not configured.',
        );
      }
      final current = AppSettingModel.value.require(sequence);
      final number = int.parse(current);
      final changed = await _compareAndSet(
        source,
        AppSettingModel.id.require(sequence),
        AppSettingModel.value,
        expected: current,
        next: '${number + 1}',
      );
      if (!changed) {
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
        throw OrderItemModel.variantId.invalid(
          'Choose an active dish variant.',
        );
      }
      if (variant.reference(DishVariantModel.dish) != dish.ref) {
        throw OrderItemModel.variantId.invalid(
          'The variant belongs to another dish.',
        );
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
      graph.restore(item, [
        OrderItemModel.label,
        OrderItemModel.unitPriceCents,
        OrderItemModel.variantName,
        OrderItemModel.taxBasisPoints,
        OrderItemModel.allergens,
        OrderItemModel.food,
      ]);
    } else if ((item.read(OrderItemModel.label) ?? '').trim().isEmpty) {
      throw OrderItemModel.label.invalid('Describe the custom item.');
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
        throw OrderItemOptionModel.optionId.invalid(
          'Choose an option belonging to this dish.',
        );
      }
      if (row.initial == null ||
          row.hasChanged(OrderItemOptionModel.optionId)) {
        if (option.read(DishOptionModel.active) != true) {
          throw OrderItemOptionModel.optionId.invalid(
            'This option is inactive.',
          );
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
        graph.restore(row, [
          OrderItemOptionModel.label,
          OrderItemOptionModel.unitPriceCents,
          OrderItemOptionModel.allergens,
        ]);
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
      throw OrderModel.slotId.invalid('Select a delivery slot.');
    }
    if (needsCapacity && newSlot != null) {
      final slot = await graph.load(newSlot);
      if (active &&
          (slot.read(DeliverySlotModel.active) != true ||
              slot.read(DeliverySlotModel.date) !=
                  order.read(OrderModel.deliveryDate))) {
        throw OrderModel.slotId.invalid(
          'Choose an available slot for the selected delivery date.',
        );
      }
      if (!hadCapacity || oldSlot != newSlot) {
        await _counter(
          source,
          newSlot,
          DeliverySlotModel.reservedOrders,
          1,
          limit: DeliverySlotModel.capacity,
          errorField: OrderModel.slotId,
        );
      }
    }
    if (hadCapacity &&
        oldSlot != null &&
        (!needsCapacity || oldSlot != newSlot)) {
      await _counter(
        source,
        oldSlot,
        DeliverySlotModel.reservedOrders,
        -1,
        limit: DeliverySlotModel.capacity,
        errorField: OrderModel.slotId,
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
        throw OrderModel.profileId.invalid(
          'This profile has no budget for the delivery month.',
        );
      }
      budget = rows.first.ref;
    }
    if (hadBudget && oldBudget != null && oldBudget != budget) {
      await _counter(
        source,
        oldBudget,
        BudgetAccountModel.reservedCents,
        -previousAmount,
        limit: BudgetAccountModel.allowanceCents,
        errorField: OrderModel.profileId,
        used: BudgetAccountModel.spentCents,
      );
    }
    if (delivered && hadBudget && oldBudget != null) {
      await _counter(
        source,
        oldBudget,
        BudgetAccountModel.spentCents,
        previousAmount,
        limit: BudgetAccountModel.allowanceCents,
        errorField: OrderModel.profileId,
        used: BudgetAccountModel.reservedCents,
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
            throw OrderModel.profileId.invalid(
              'Insufficient company budget. Choose an eligible private payment profile.',
            );
          }
          graph.write(ledger, BudgetAccountModel.reservedCents, reserved);
        } else {
          await _counter(
            source,
            budget,
            BudgetAccountModel.reservedCents,
            delta,
            limit: BudgetAccountModel.allowanceCents,
            errorField: OrderModel.profileId,
            used: BudgetAccountModel.spentCents,
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

  /// Moves a guarded [counter] of the [ref] account by [delta] when it stays
  /// within [limit] (less [used] already committed elsewhere).
  Future<void> _counter(
    WormDataSource source,
    BeakRecordRef ref,
    BeakScalarField<int> counter,
    int delta, {
    required BeakScalarField<int> limit,
    required BeakFieldRef<Object> errorField,
    BeakScalarField<int>? used,
  }) async {
    final row = await source.find(counter.model, ref.id!);
    if (row == null) {
      throw errorField.invalid('The reservation account no longer exists.');
    }
    final before = counter.require(row);
    final after = before + delta;
    final committed = used == null ? 0 : used.require(row);
    if (after < 0 || after + committed > limit.require(row)) {
      throw errorField.invalid(
        counter == DeliverySlotModel.reservedOrders
            ? 'This delivery slot is full.'
            : 'Insufficient company budget. Choose an eligible private payment profile.',
      );
    }
    final changed = await _compareAndSet(
      source,
      ref.id!,
      counter,
      expected: before,
      next: after,
    );
    if (!changed) {
      throw const BeakConflictException(
        'The reservation changed. Reload before trying again.',
      );
    }
  }

  void _attention(
    BeakCandidateGraph graph,
    BeakCandidateNode order,
    BeakModelAction? action,
  ) {
    var reason = '';
    var next = '';
    if (order.read(OrderModel.status) != OrderStatus.cancelled &&
        order.read(OrderModel.status) != OrderStatus.draft) {
      if (order.read(OrderModel.paymentStatus) == PaymentStatus.failed) {
        reason = 'Payment failed';
        next = OrderActions.retryPayment.name;
      } else if ({
        PaymentStatus.unpaid,
        PaymentStatus.pending,
      }.contains(order.read(OrderModel.paymentStatus))) {
        reason = 'Awaiting payment';
        next = OrderActions.sendPaymentLink.name;
      } else if (order.read(OrderModel.approvalStatus) ==
          ApprovalStatus.pending) {
        reason = 'Approval needed';
        next = OrderActions.requestApproval.name;
      } else if (order.read(OrderModel.status) == OrderStatus.onHold) {
        reason =
            order.original(OrderModel.attentionReason) ?? 'Delivery on hold';
        next = order.original(OrderModel.nextAction) ?? 'editAddress';
      } else if (order.read(OrderModel.strictAllergy) == true &&
          order.read(OrderModel.allergyAcknowledged) != true) {
        reason = 'Allergy note needs kitchen confirmation';
        next = OrderActions.acknowledgeAllergy.name;
      } else if (action != OrderActions.resolveChange &&
          order.original(OrderModel.nextAction) == 'reviewChange') {
        reason = 'Change requested';
        next = 'reviewChange';
      }
    }
    graph.write(order, OrderModel.needsAttention, next.isNotEmpty);
    graph.write(order, OrderModel.attentionReason, reason);
    graph.write(order, OrderModel.nextAction, next);
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
        field,
    };
    final labels = {
      if (node.hasChanged(OrderModel.subtotalCents) ||
          node.hasChanged(OrderModel.itemCount))
        OrderModel.items.label,
      for (final column in node.changedColumns(except: derived)) column.label,
    };
    return labels.join(', ');
  }

  /// The declared order command a plan runs on its root, if any.
  static BeakModelAction? _commandOf(BeakSavePlan plan) =>
      OrderActions.all.where(plan.runs).firstOrNull;

  static String _actionTitle(BeakModelAction action) =>
      {
        OrderActions.addNote: 'Internal note added',
        OrderActions.amend: 'Order updated',
        OrderActions.place: 'Order placed',
        OrderActions.approve: 'Order approved',
        OrderActions.reject: 'Order rejected',
        OrderActions.cancel: 'Order cancelled',
        OrderActions.startKitchen: 'Moved to in kitchen',
        OrderActions.dispatch: 'Out for delivery',
        OrderActions.deliver: 'Order delivered',
        OrderActions.requestApproval: 'Approval requested',
        OrderActions.sendPaymentLink: 'Payment link requested',
        OrderActions.retryPayment: 'Payment retry requested',
        OrderActions.acknowledgeAllergy: 'Allergy confirmed with kitchen',
        OrderActions.reschedule: 'Redelivery scheduled',
        OrderActions.resolveChange: 'Requested changes accepted',
      }[action] ??
      action.label;
}

/// Models whose rows only the server writes.
const List<BeakModel> _serverWritten = [
  OrderActivityModel(),
  PaymentAttemptModel(),
  MessageDeliveryModel(),
];

/// The setting holding the next order number.
const String _orderSequenceSetting = 'nextOrderNumber';

/// Settings that no caller may create or edit.
const Set<String> _serverSettings = {
  _orderSequenceSetting,
  'foodioSeedVersion',
};

/// Sets [field] of the [id] row to [next] only while it still holds [expected].
///
/// The one raw worm write here: Beak's data source has no conditional update,
/// so an optimistic guard needs worm's predicate on the transaction's adapter.
Future<bool> _compareAndSet<T extends Object>(
  WormDataSource source,
  Object id,
  BeakScalarField<T> field, {
  required T expected,
  required T next,
}) async {
  final model = field.model;
  final changed = await source.adapter.update(
    UpdateDescriptor(
      table: model.table,
      values: {field.key: next},
      where: Field<Object>(
        model.primaryKey.key,
      ).eq(id).and(Field<Object>(field.key).eq(expected)),
    ),
  );
  return changed == 1;
}
