import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import '../../models/models.dart';
import '../../supporting_forms.dart';

/// Billing documents, promotions and monthly budget ledgers.
List<BeakResource> financeResources() => [
  BeakResource(
    model: const InvoiceModel(),
    title: 'Invoices',
    navigationGroup: 'Finance',
    icon: const BeakIconToken(OiIcons.receipt),
    globalSearchSources: [
      InvoiceModel.reference,
      InvoiceModel.organization.name,
      InvoiceModel.customer.email,
    ],
    screens: [
      BeakTableScreen(
        fields: [
          InvoiceModel.reference,
          InvoiceModel.organization.name,
          InvoiceModel.period,
          InvoiceModel.status,
          InvoiceModel.grossCents.currency(minorUnits: true, label: 'Total'),
          InvoiceModel.dueDate,
        ],
      ),
      supportingForm([
        BeakTabs(
          tabs: [
            BeakTab(
              title: 'Invoice',
              children: [
                BeakColumns(
                  children: [
                    BeakCard(
                      title: 'Billing document',
                      children: [
                        InvoiceModel.reference.inputText(),
                        InvoiceModel.organization.inputCombobox(),
                        InvoiceModel.customer.inputCombobox(),
                        InvoiceModel.period.inputText(
                          description: 'Billing month, for example 2026-09.',
                        ),
                        InvoiceModel.issueDate.inputDate(),
                        InvoiceModel.dueDate.inputDate(),
                        InvoiceModel.status.input(readOnly: true),
                      ],
                    ),
                    BeakCard(
                      title: 'Calculated totals',
                      children: [
                        InvoiceModel.grossCents.inputCurrency(
                          minorUnits: true,
                          label: 'Total including VAT',
                          readOnly: true,
                        ),
                        InvoiceModel.netCents.inputCurrency(
                          minorUnits: true,
                          label: 'Net amount',
                          readOnly: true,
                        ),
                        InvoiceModel.taxCents.inputCurrency(
                          minorUnits: true,
                          label: 'VAT',
                          readOnly: true,
                        ),
                        InvoiceModel.billingEmail.input(readOnly: true),
                        InvoiceModel.billingAddress.input(readOnly: true),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            BeakTab(
              title: 'Included orders',
              children: [
                BeakCard(
                  title: 'Order snapshots',
                  description:
                      'Assign placed orders through their Billing section. Issuing the invoice locks these amounts.',
                  children: [
                    InvoiceModel.orders.tableForm(
                      allowAdding: false,
                      allowEdit: false,
                      allowRemove: false,
                      children: [
                        OrderModel.reference.input(readOnly: true),
                        OrderModel.customerName.input(readOnly: true),
                        OrderModel.deliveryDate.input(readOnly: true),
                        OrderModel.grossCents.inputCurrency(
                          minorUnits: true,
                          label: 'Total',
                          readOnly: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ]),
    ],
  ),
  BeakResource(
    model: const VoucherModel(),
    title: 'Vouchers',
    navigationRank: 1,
    navigationGroup: 'Finance',
    icon: const BeakIconToken(OiIcons.ticket),
    globalSearchSources: [VoucherModel.code, VoucherModel.description],
    screens: [
      BeakTableScreen(
        fields: [
          VoucherModel.code,
          VoucherModel.description,
          VoucherModel.maximumDiscountCents.currency(
            minorUnits: true,
            label: 'Maximum discount',
          ),
          VoucherModel.validUntil,
          VoucherModel.active,
        ],
      ),
      supportingForm([
        BeakColumns(
          children: [
            BeakCard(
              title: 'Promotion',
              children: [
                VoucherModel.code.inputText(),
                VoucherModel.description.inputText(),
                VoucherModel.active.inputToggle(),
                VoucherModel.validFrom.inputDate(),
                VoucherModel.validUntil.inputDate(),
              ],
            ),
            BeakCard(
              title: 'Discount rules',
              children: [
                VoucherModel.percentBasisPoints.inputSelect(
                  label: 'Discount',
                  options: (_) => [
                    for (var percent = 0; percent <= 100; percent++)
                      BeakInputOption(percent * 100, '$percent%'),
                  ],
                ),
                VoucherModel.maximumDiscountCents.inputCurrency(
                  minorUnits: true,
                  label: 'Maximum discount',
                ),
                VoucherModel.foodOnly.inputToggle(label: 'Apply to food only'),
              ],
            ),
          ],
        ),
      ]),
    ],
  ),
  BeakResource(
    model: const BudgetAccountModel(),
    title: 'Budgets',
    navigationRank: 2,
    navigationGroup: 'Finance',
    icon: const BeakIconToken(OiIcons.wallet),
    canDelete: false,
    globalSearchSources: [
      BudgetAccountModel.name,
      BudgetAccountModel.profile.name,
      BudgetAccountModel.period,
    ],
    screens: [
      BeakTableScreen(
        fields: [
          BudgetAccountModel.name,
          BudgetAccountModel.profile.customer.name,
          BudgetAccountModel.period,
          BudgetAccountModel.allowanceCents.currency(
            minorUnits: true,
            label: 'Allowance',
          ),
          BudgetAccountModel.reservedCents.currency(
            minorUnits: true,
            label: 'Reserved',
          ),
          BudgetAccountModel.spentCents.currency(
            minorUnits: true,
            label: 'Spent',
          ),
        ],
      ),
      supportingForm([
        BeakColumns(
          children: [
            BeakCard(
              title: 'Monthly allowance',
              children: [
                BudgetAccountModel.name.inputText(),
                BudgetAccountModel.profile.inputCombobox(),
                BudgetAccountModel.period.inputText(
                  label: 'Month',
                  description: 'Use YYYY-MM, for example 2026-09.',
                ),
                BudgetAccountModel.allowanceCents.inputCurrency(
                  minorUnits: true,
                  label: 'Allowance',
                ),
              ],
            ),
            BeakCard(
              title: 'Order commitments',
              description:
                  'Reservations and spending are maintained automatically by order actions.',
              children: [
                BudgetAccountModel.reservedCents.inputCurrency(
                  minorUnits: true,
                  label: 'Reserved',
                  readOnly: true,
                ),
                BudgetAccountModel.spentCents.inputCurrency(
                  minorUnits: true,
                  label: 'Spent',
                  readOnly: true,
                ),
              ],
            ),
          ],
        ),
      ]),
    ],
  ),
];
