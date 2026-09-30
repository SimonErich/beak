import 'package:beak/panel.dart';
import '../../../domain/foodio_money.dart';
import '../../../domain/foodio_payment.dart';
import '../../../models/models.dart';

/// Shared exact money engine; the form contributes only its typed draft lines.
FoodioTotals orderTotals(BeakFormReader state) {
  final lines = [
    for (final row in state.rows(OrderModel.items))
      FoodioMoneyLine(
        key: row.draft.localId,
        grossCents:
            (row.asOrderItem.quantity ?? 0) *
            ((row.asOrderItem.unitPriceCents ??
                    row.asOrderItem.variant?.priceCents ??
                    0) +
                row
                    .rows(OrderItemModel.fields.options)
                    .fold<int>(
                      0,
                      (sum, option) =>
                          sum + (option.asOrderItemOption.unitPriceCents ?? 0),
                    )),
        taxBasisPoints: row.asOrderItem.taxBasisPoints ?? 1000,
        food: row.asOrderItem.food ?? true,
      ),
  ];
  final voucher = state.asOrder.voucher;
  final initial = state.draft.initialRecord.asOrder;
  final snapshot =
      state.draft.id != null &&
      initial.status != OrderStatus.draft &&
      initial.voucherId == state.asOrder.voucherId;
  final rate = snapshot
      ? state.asOrder.voucherRateBasisPoints ?? 0
      : voucher?.percentBasisPoints ?? 0;
  final cap = snapshot
      ? state.asOrder.voucherMaximumDiscountCents
      : voucher?.maximumDiscountCents;
  final foodOnly = snapshot
      ? state.asOrder.voucherFoodOnly ?? true
      : voucher?.foodOnly ?? true;
  final beforeManual = FoodioTotals.calculate(
    lines,
    voucherBasisPoints: rate,
    voucherCapCents: cap,
    voucherFoodOnly: foodOnly,
  );
  // Keep the preview renderable while an invalid discount is being corrected.
  // Authoritative validation still rejects amounts above the payable total.
  return FoodioTotals.calculate(
    lines,
    voucherBasisPoints: rate,
    voucherCapCents: cap,
    voucherFoodOnly: foodOnly,
    manualDiscountCents: (state.asOrder.manualDiscountCents ?? 0).clamp(
      0,
      beforeManual.grossCents,
    ),
  );
}

/// Avoid floating-point amounts at every presentation boundary.
BeakDecimal money(int cents) => BeakDecimal(cents, scale: 2);

/// The selected profile's accounting period is queried through its relationship.
BudgetAccountRecord? budgetFor(BeakFormReader state) {
  final period = (state.asOrder.deliveryDate ?? const BeakDate(2026, 9, 28))
      .toString()
      .substring(0, 7);
  for (final row
      in state.read(OrderModel.profile.budgets) ?? const <BeakRecord>[]) {
    final account = row.asBudgetAccount;
    if (account.period == period) return account;
  }
  return null;
}

/// Reserved and spent money are both unavailable to new company orders.
int budgetUsed(BeakFormReader state) {
  final account = budgetFor(state);
  return (account?.spentCents ?? 0) + (account?.reservedCents ?? 0);
}

/// The current monthly collective draft shown before the order is placed.
/// It is a preview only; invoice ownership remains authoritative at save time.
InvoiceRecord? draftInvoiceForOrder(BeakDraftReader state) {
  if (state.read(OrderModel.paymentMode) != 'monthlyInvoice') return null;
  final period = state
      .read(OrderModel.deliveryDate)
      ?.toString()
      .substring(0, 7);
  if (period == null) return null;
  for (final row
      in state.read(OrderModel.profile.organization.invoices) ??
          const <BeakRecord>[]) {
    final invoice = row.asInvoice;
    if (invoice.period == period && invoice.status == InvoiceStatus.draft) {
      return invoice;
    }
  }
  return null;
}

/// The portion of this order paid from its company's budget, in cents.
int companyBudgetContribution(BeakFormReader state) {
  final current = state.asOrder;
  final companyBilling =
      current.profile?.organizationId != null &&
      foodioCompanyPaymentModes.contains(current.paymentMode);
  return companyBilling ? orderTotals(state).grossCents : 0;
}

/// Budget available to this draft before charging its current company portion.
/// Editing an order makes its own reservation available exactly once.
int availableBudgetForOrder(BeakFormReader state) =>
    (budgetFor(state)?.allowanceCents ?? 0) -
    _budgetUsedWithoutCurrentReservation(state);

/// Existing reservations are replaced by the edited amount, never counted twice.
int projectedBudgetUsed(BeakFormReader state) =>
    _budgetUsedWithoutCurrentReservation(state) +
    companyBudgetContribution(state);

int _budgetUsedWithoutCurrentReservation(BeakFormReader state) {
  if (OrderModel.id.readFrom(state.draft.initialRecord) == null) {
    return budgetUsed(state);
  }
  final current = state.asOrder;
  final initial = state.draft.initialRecord.asOrder;
  final sameBudget =
      initial.profileId == current.profileId &&
      initial.deliveryDate?.toString().substring(0, 7) ==
          current.deliveryDate?.toString().substring(0, 7);
  final replaced = sameBudget && initial.budgetReserved == true
      ? initial.budgetAmountCents
      : 0;
  return budgetUsed(state) - replaced;
}
