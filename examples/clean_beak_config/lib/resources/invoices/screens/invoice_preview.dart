import 'package:beak/panel.dart';
import '../../../domain/shop_totals.dart';
import '../../vouchers/models/voucher.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../models/invoice_voucher.dart';

/// A live calculation or actionable explanation while a draft is incomplete.
final class InvoicePreview {
  /// Creates a valid or incomplete preview.
  const InvoicePreview({this.totals, this.problem});

  /// Exact arithmetic shared with authoritative server saves.
  final ShopTotals? totals;

  /// Guidance for the next edit needed to calculate the document.
  final String? problem;
}

/// Adapts typed draft values to the shared, pure invoice calculator.
InvoicePreview invoicePreview(BeakFormReader state) {
  try {
    final lines = [
      for (final row in state.rows(InvoiceModel.items))
        ShopLineInput(
          id: row.draft.localId,
          label:
              row.asInvoiceItem.label ??
              row.asInvoiceItem.variant?.name ??
              row.asInvoiceItem.product?.name ??
              '',
          quantity: row.asInvoiceItem.quantity ?? 0,
          unitPrice: invoiceUnitPrice(row),
          lineDiscount: row.asInvoiceItem.discount ?? ShopMoney.zero,
          taxRate: invoiceTaxPercent(row),
        ),
    ];
    final voucherRows = [...state.rows(InvoiceModel.vouchers)]
      ..sort(
        (a, b) => (a.asInvoiceVoucher.position ?? 0).compareTo(
          b.asInvoiceVoucher.position ?? 0,
        ),
      );
    final vouchers = <ShopVoucherInput>[];
    final positions = <int>{};
    for (final row in voucherRows) {
      final position = row.asInvoiceVoucher.position;
      if (position == null || !positions.add(position)) {
        return const InvoicePreview(
          problem: 'Give each voucher a different position.',
        );
      }
      final voucher = row.asInvoiceVoucher.voucher;
      if (voucher == null) continue;
      final id = row.asInvoiceVoucher.voucherId ?? row.draft.localId;
      final minimum = voucher.minimumSubtotal ?? ShopMoney.zero;
      vouchers.add(
        voucher.kind == VoucherKind.percentage
            ? ShopVoucherInput.percentage(
                id: id,
                code: voucher.code,
                percent: voucher.value,
                minimumSubtotal: minimum,
                maximumDiscount: voucher.maximumDiscount,
              )
            : ShopVoucherInput.fixed(
                id: id,
                code: voucher.code,
                amount: voucher.value,
                minimumSubtotal: minimum,
                maximumDiscount: voucher.maximumDiscount,
              ),
      );
    }
    return InvoicePreview(
      totals: ShopTotals.calculate(lines: lines, vouchers: vouchers),
    );
  } on FormatException catch (error) {
    return InvoicePreview(problem: error.message);
  }
}

/// Explicit entered prices take priority over variant and catalog defaults.
BeakDecimal invoiceUnitPrice(BeakFormReader row) =>
    row.asInvoiceItem.unitPrice ??
    row.asInvoiceItem.variant?.price ??
    row.asInvoiceItem.product?.price ??
    ShopMoney.zero;

/// Preserves a saved rate until the product, variant or tax selection changes.
BeakDecimal invoiceTaxPercent(BeakFormReader row) {
  final initial = row.draft.initialRecord;
  final selectionUnchanged = [
    InvoiceItemModel.productId,
    InvoiceItemModel.variantId,
    InvoiceItemModel.taxRateId,
  ].every((field) => row.read(field) == field.readFrom(initial));
  if (row.draft.id != null && selectionUnchanged) {
    final saved = InvoiceItemModel.taxPercent.readFrom(initial);
    if (saved != null) return saved;
  }
  return row.asInvoiceItem.taxRate?.ratePercent ??
      row.asInvoiceItem.product?.taxRate?.ratePercent ??
      ShopMoney.zero;
}

/// Drafts preview the selected customer; issued invoices retain billed details.
String invoiceCustomerName(BeakFormReader state) => invoiceLocked(state)
    ? state.asInvoice.customerName ?? ''
    : '${state.asInvoice.customer?.firstName ?? ''} ${state.asInvoice.customer?.lastName ?? ''}'
          .trim();

/// Drafts preview the selected email; issued invoices retain the saved email.
String? invoiceCustomerEmail(BeakFormReader state) => invoiceLocked(state)
    ? state.asInvoice.customerEmail
    : state.asInvoice.customer?.email;

/// Existing issued documents expose their saved totals, not today's catalog.
bool invoiceLocked(BeakFormReader state) =>
    state.root.draft.id != null &&
    InvoiceModel.status.readFrom(state.root.draft.initialRecord) !=
        InvoiceStatus.draft;
