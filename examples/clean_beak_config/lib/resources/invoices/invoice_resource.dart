import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import '../../shop_drafts.dart';
import 'models/invoice.dart';
import 'models/invoice_item.dart';
import 'models/invoice_voucher.dart';
import 'screens/invoice_form.dart';

/// Transactional invoicing with catalog snapshots and a guided review.
final class InvoiceResource extends BeakResource {
  /// Creates the invoicing section.
  InvoiceResource()
    : super(
        model: const InvoiceModel(),
        title: 'Invoices',
        icon: const BeakIconToken(OiIcons.receiptText),
        navigationGroup: 'Sales',
        navigationRank: 1,
        canDelete: false,
        globalSearchSources: [
          InvoiceModel.number,
          InvoiceModel.customerEmail,
          InvoiceModel.customerName,
          InvoiceModel.customer.email,
          InvoiceModel.items.search(InvoiceItemModel.label),
          InvoiceModel.vouchers.search(InvoiceVoucherModel.codeSnapshot),
        ],
        // --8<-- [start:listInvoiceFilters]
        filters: [
          InvoiceModel.status.selectFilter(),
          InvoiceModel.customer.relationFilter(),
          InvoiceModel.issuedAt.dateRangeFilter(label: 'Invoice date'),
        ],
        // --8<-- [end:listInvoiceFilters]
        screens: [
          // --8<-- [start:listInvoiceFields]
          BeakTableScreen(
            fields: [
              InvoiceModel.number,
              InvoiceModel.status,
              InvoiceModel.customerEmail,
              InvoiceModel.issuedAt,
              InvoiceModel.dueAt,
              InvoiceModel.total.formatted(
                BeakValueFormat.currency,
                label: 'Amount due',
              ),
            ],
          ),
          // --8<-- [end:listInvoiceFields]
          // --8<-- [start:invoiceWizardAndReadScreens]
          BeakWizardScreen(
            steps: invoiceSteps(),
            drafts: shopDrafts('invoice'),
            reviewBeforeSave: true,
          ),
          BeakFormScreen(
            roles: const {BeakScreenRole.read},
            layout: BeakFormLayout(
              children: [
                ...invoiceReview(),
                BeakFormSections(
                  sections: invoiceSections().sections.take(3).toList(),
                ).tabs,
              ],
            ),
          ),
          // --8<-- [end:invoiceWizardAndReadScreens]
        ],
      );
}
