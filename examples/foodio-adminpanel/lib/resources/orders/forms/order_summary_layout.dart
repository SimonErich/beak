import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';

import '../../../models/models.dart';
import '../../../domain/foodio_clock.dart';
import '../../../theme/gabel_theme.dart';
import '../presentations/order_presentations.dart';
import 'order_totals.dart';

/// A declarative aside observes the same staged graph as every wizard step.
BeakFormLayout orderSummary() => BeakFormLayout(
  visibleIf: (state) => state.stepIndex != 4,
  children: [
    BeakFormLayout(
      children: [
        BeakFormTemplate(
          template: BeakRecordTemplate(
            title: BeakValueBinding<String>.computed(
              dependencies: const [],
              compute: (_) => 'Order summary',
              textStyle: _summaryTitle,
            ),
            trailing: [
              BeakValueBinding<String>.computed(
                dependencies: const [],
                compute: (_) => 'Draft',
                badge: true,
                badgeDot: true,
              ),
            ],
          ),
        ),
        BeakSection(
          title: 'Customer and profile',
          titleStyle: _summaryLabel,
          titleColor: BeakColor.muted,
          gap: 12,
          children: [
            BeakFormTemplate(
              template: BeakRecordTemplate(
                title: BeakValueBinding.field(
                  OrderModel.customer.name,
                  strong: true,
                ),
                subtitle: [
                  BeakValueBinding.field(OrderModel.profile.name),
                  BeakValueBinding.field(OrderModel.profile.role),
                ],
                inlineSubtitle: true,
                avatar: true,
                avatarSize: OiAvatarSize.md,
                avatarPalette: identityPalette,
                identityGap: 12,
                textGap: 0,
                detailsSpacing: 12,
                details: [
                  BeakValueBinding<String>.computed(
                    dependencies: [OrderModel.paymentMode],
                    icon: OiIcons.landmark,
                    maxLines: null,
                    compute: (state) => switch (state.read(
                      OrderModel.paymentMode,
                    )) {
                      'monthlyInvoice' =>
                        'Company invoice · monthly collective',
                      'weeklyInvoice' => 'Company invoice · weekly collective',
                      final mode => paymentLabels[mode] ?? 'Select a profile',
                    },
                  ),
                  BeakValueBinding.field(
                    OrderModel.costCenter,
                    icon: OiIcons.briefcaseBusiness,
                    label: 'Cost centre',
                    maxLines: null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
    BeakSection(
      title: 'Delivery',
      titleStyle: _summaryLabel,
      titleColor: BeakColor.muted,
      gap: 12,
      divider: true,
      dividerAfterSpacing: 4,
      children: [
        BeakFormPlaceholder(
          label: 'Delivery not set',
          height: 76,
          visibleIf: (state) => state.asOrder.slotId == null,
        ),
        BeakFormTemplate(
          visibleIf: (state) => state.asOrder.slotId != null,
          template: BeakRecordTemplate(
            title: BeakValueBinding.field(
              OrderModel.deliveryDate.formatted(BeakValueFormat.date),
              icon: OiIcons.calendar,
              strong: true,
            ),
            inlineBadges: true,
            textGap: 0,
            detailsSpacing: 8,
            badges: [BeakValueBinding.field(OrderModel.slot.name)],
            details: [
              BeakValueBinding<String>.computed(
                dependencies: [
                  OrderModel.location.name,
                  OrderModel.handover,
                  ...orderAddress().dependencies,
                ],
                icon: OiIcons.mapPin,
                maxLines: null,
                compute: (state) =>
                    [
                          state.read(OrderModel.location.name),
                          if (state.read(OrderModel.addressOverride) == true)
                            orderAddress().read(state),
                          state.read(OrderModel.handover),
                        ]
                        .whereType<String>()
                        .where((part) => part.isNotEmpty)
                        .join(' – '),
              ),
              BeakValueBinding<String>.computed(
                dependencies: [
                  OrderModel.location.method,
                  OrderModel.location.routeCode,
                ],
                icon: OiIcons.truck,
                maxLines: null,
                compute: (state) {
                  final route = state.read(OrderModel.location.routeCode) ?? '';
                  return [
                    state.read(OrderModel.location.method) == 'office'
                        ? 'Office delivery'
                        : 'Home delivery',
                    route.toLowerCase().startsWith('bike')
                        ? 'Bike courier'
                        : 'Cooled van',
                    if (route.isNotEmpty) 'Route $route',
                  ].join(' · ');
                },
              ),
              BeakValueBinding<String>.computed(
                dependencies: [OrderModel.deliveryNote],
                compute: (state) =>
                    '“${state.read(OrderModel.deliveryNote) ?? ''}”',
                icon: OiIcons.messageSquare,
                maxLines: null,
                visibleIf: (state) =>
                    state.read(OrderModel.deliveryNote)?.isNotEmpty == true,
              ),
            ],
          ),
        ),
      ],
    ),
    BeakSection(
      title: 'Dishes',
      titleStyle: _summaryLabel,
      titleColor: BeakColor.muted,
      gap: 12,
      divider: true,
      dividerAfterSpacing: 4,
      children: [
        BeakFormPlaceholder(
          label: 'No dishes yet',
          visibleIf: (state) => state.rows(OrderModel.items).isEmpty,
        ),
        BeakFormSummary(
          source: OrderModel.items,
          gap: 8,
          visibleIf: (state) => state.rows(OrderModel.items).isNotEmpty,
          lines: [
            BeakSummaryLine(
              label: 'Dish',
              dependencies: [
                OrderItemModel.quantity,
                OrderItemModel.label,
                OrderItemModel.variantName,
                OrderItemModel.unitPriceCents,
                OrderItemModel.fields.options,
              ],
              labelBuilder: (state, _) =>
                  '${state.asOrderItem.quantity ?? 0} × ${_basketLabel(state.asOrderItem.label)} · ${state.asOrderItem.variantName ?? ''}',
              value: (state) => money(
                (state.asOrderItem.quantity ?? 0) *
                    ((state.asOrderItem.unitPriceCents ?? 0) +
                        state
                            .rows(OrderItemModel.fields.options)
                            .fold<int>(
                              0,
                              (sum, option) =>
                                  sum +
                                  (option.asOrderItemOption.unitPriceCents ??
                                      0),
                            )),
              ),
              format: BeakValueFormat.currency,
              valueStyle: gabelNumericBodyStyle,
            ),
          ],
        ),
      ],
    ),
  ],
);

// Keep the basket scan-friendly; the catalog, review and invoice retain each
// full dish name, including its accompaniment.
String _basketLabel(String? label) =>
    (label ?? 'Dish').split(RegExp(r'\s+with\s+')).first;

/// Totals stay visible while longer customer, delivery and dish summaries scroll.
BeakFormLayout orderSummaryFooter() => BeakFormLayout(
  spacing: 12,
  children: [
    BeakSection(
      title: 'Total and budget',
      titleStyle: _summaryLabel,
      titleColor: BeakColor.muted,
      gap: 12,
      visibleIf: (state) => state.rows(OrderModel.items).isEmpty,
      children: const [
        BeakFormPlaceholder(label: 'Total not calculated yet', height: 56),
      ],
    ),
    BeakFormTemplate(
      visibleIf: (state) =>
          state.rows(OrderModel.items).isEmpty && budgetFor(state) != null,
      template: BeakRecordTemplate(
        detailsSpacing: 8,
        title: BeakValueBinding<String>.computed(
          dependencies: [OrderModel.profile.budgets],
          icon: OiIcons.wallet,
          textStyle: _summaryLabel,
          compute: (row) {
            final period = const FoodioClock().today.toString().substring(0, 7);
            final budget =
                (row.read(OrderModel.profile.budgets) ?? const <BeakRecord>[])
                    .map((record) => record.asBudgetAccount)
                    .where((budget) => budget.period == period)
                    .firstOrNull;
            if (budget == null) return 'No budget set for this month';
            final remaining =
                budget.allowanceCents -
                budget.reservedCents -
                budget.spentCents;
            return '€${BeakDecimal(remaining, scale: 2)} of €${BeakDecimal(budget.allowanceCents, scale: 2)} budget left this month';
          },
        ),
        details: [
          BeakValueBinding<String>.computed(
            dependencies: [
              OrderModel.profile.approvalThresholdCents,
              OrderModel.profile.approver.name,
            ],
            icon: OiIcons.info,
            maxLines: null,
            textStyle: _summaryLabel,
            compute: (row) =>
                'Orders over €${BeakDecimal(row.read(OrderModel.profile.approvalThresholdCents) ?? 0, scale: 2)} need approval by ${row.read(OrderModel.profile.approver.name) ?? 'the company approver'}.',
          ),
        ],
      ),
    ),
    BeakFormSummary(
      title: 'Total and budget',
      headingGap: 12,
      titleStyle: _summaryLabel,
      titleColor: BeakColor.muted,
      labelColor: BeakColor.muted,
      gap: 8,
      visibleIf: (state) => state.rows(OrderModel.items).isNotEmpty,
      lines: [
        BeakSummaryLine(
          label: 'Subtotal',
          visibleIf: (state) => state.stepIndex != 4,
          labelBuilder: (state, _) =>
              'Subtotal · ${state.rows(OrderModel.items).fold<int>(0, (sum, row) => sum + (row.asOrderItem.quantity ?? 0))} dishes',
          value: (state) => money(orderTotals(state).subtotalCents),
          format: BeakValueFormat.currency,
          valueStyle: gabelNumericBodyStyle,
        ),
        BeakSummaryLine(
          label: 'Discounts',
          labelBuilder: (state, _) =>
              (state.asOrder.manualDiscountCents ?? 0) > 0
              ? 'Discounts'
              : 'Voucher ${state.asOrder.voucher?.code ?? ''} · ${(state.asOrder.voucher?.percentBasisPoints ?? 0) / 100}% ',
          dependencies: [
            OrderModel.voucher.code,
            OrderModel.voucher.percentBasisPoints,
          ],
          value: (state) => money(-orderTotals(state).discountCents),
          visibleIf: (state) =>
              state.stepIndex != 4 && orderTotals(state).discountCents > 0,
          format: BeakValueFormat.currency,
          valueStyle: gabelNumericBodyStyle,
        ),
        BeakSummaryLine(
          label: 'Delivery · framework agreement',
          visibleIf: (state) => state.stepIndex != 4,
          value: (_) => money(0),
          format: BeakValueFormat.currency,
          valueStyle: gabelNumericBodyStyle,
        ),
        BeakSummaryLine(
          label: 'Total',
          visibleIf: (state) => state.stepIndex != 4,
          labelBuilder: (state, _) =>
              state.stepIndex < 3 ? 'Total so far' : 'Total',
          value: (state) => money(orderTotals(state).grossCents),
          format: BeakValueFormat.currency,
          emphasized: true,
          valueAlignment: CrossAxisAlignment.end,
          subtitleGap: 0,
          afterSpacing: 4,
          dividerBefore: true,
          dividerSpacing: 4,
          subtitleStyle: gabelNumericCaptionStyle,
          valueStyle: gabelNumericTotalStyle,
          labelStyle: gabelNumericMediumStyle,
          subtitle: (state, format) {
            if (state.stepIndex < 3) return null;
            final totals = orderTotals(state);
            final taxes = [
              for (final entry in totals.taxByRate.entries)
                if (entry.value != 0)
                  '${format.number(entry.key / 100)}% ${format.format(money(entry.value), BeakValueFormat.currency)}',
            ];
            return 'incl. VAT ${taxes.join(' + ')} · net ${format.format(money(totals.netCents), BeakValueFormat.currency)}';
          },
        ),
        BeakSummaryLine(
          label: 'Total',
          visibleIf: (state) => state.stepIndex == 4,
          value: (state) => money(orderTotals(state).grossCents),
          format: BeakValueFormat.currency,
          emphasized: true,
          valueAlignment: CrossAxisAlignment.end,
          subtitleGap: 0,
          afterSpacing: 4,
          subtitleStyle: gabelNumericCaptionStyle,
          valueStyle: gabelNumericTotalStyle,
          labelStyle: gabelNumericMediumStyle,
          subtitle: (state, format) {
            final totals = orderTotals(state);
            return 'incl. VAT ${[for (final entry in totals.taxByRate.entries)
              if (entry.value != 0) '${format.number(entry.key / 100)}% ${format.format(money(entry.value), BeakValueFormat.currency)}'].join(' + ')} · net ${format.format(money(totals.netCents), BeakValueFormat.currency)}';
          },
        ),
        BeakSummaryLine(
          label: 'Budget after this order',
          valueLabel: (state, format) =>
              '${format.format(money((budgetFor(state)?.allowanceCents ?? 0) - projectedBudgetUsed(state)), BeakValueFormat.currency)} left',
          value: (state) => money(
            (budgetFor(state)?.allowanceCents ?? 0) -
                projectedBudgetUsed(state),
          ),
          format: BeakValueFormat.currency,
          valueStyle: gabelNumericMediumStyle,
          visibleIf: (state) => budgetFor(state) != null,
          dependencies: [OrderModel.profile.budgets],
        ),
      ],
    ),
    BeakFormCapacity(
      label: 'Company budget this month',
      dependencies: [OrderModel.profile.budgets],
      visibleIf: (state) =>
          budgetFor(state) != null && state.rows(OrderModel.items).isNotEmpty,
      value: (state) => companyBudgetContribution(state) / 100,
      max: (state) => availableBudgetForOrder(state) / 100,
      format: BeakValueFormat.currency,
      showLabel: false,
      showValue: false,
      height: 8,
      caption: (state, format) {
        final current = companyBudgetContribution(state);
        final available = availableBudgetForOrder(state);
        return 'Uses ${format.format(money(current), BeakValueFormat.currency)} of the ${format.format(money(available), BeakValueFormat.currency)} left this month';
      },
    ),
    BeakFormNotice(
      title: 'Needs approval',
      titleBuilder: (state) =>
          'Needs approval by ${state.asOrder.profile?.approver?.name ?? 'the company approver'}',
      tone: BeakColor.warning,
      visibleIf: (state) =>
          state.stepIndex != 4 &&
          state.asOrder.profile?.kind == 'company' &&
          orderTotals(state).grossCents >
              (state.asOrder.profile?.approvalThresholdCents ?? 4000),
      dependencies: [OrderModel.profile.approver.name],
      message: (state) =>
          '€${BeakDecimal(orderTotals(state).grossCents, scale: 2)} is over the €${BeakDecimal(state.asOrder.profile?.approvalThresholdCents ?? 0, scale: 2)} rule.',
    ),
  ],
);

/// Amounts reconcile exactly with the saved invoice and line allocations.
BeakFormSummary orderMoneySummary({
  String? title = 'Total and budget',
  BeakVisibility? visibleIf,
  bool compact = false,
  bool breakdown = true,
}) => BeakFormSummary(
  title: title,
  visibleIf: visibleIf,
  maxWidth: compact ? 320 : null,
  alignment: compact
      ? AlignmentDirectional.centerEnd
      : AlignmentDirectional.centerStart,
  gap: compact ? 8 : 12,
  lines: [
    if (breakdown) ...[
      BeakSummaryLine(
        label: 'Subtotal',
        value: (state) => money(orderTotals(state).subtotalCents),
        format: BeakValueFormat.currency,
      ),
      BeakSummaryLine(
        label: 'Discounts',
        value: (state) => money(-orderTotals(state).discountCents),
        format: BeakValueFormat.currency,
      ),
      BeakSummaryLine(
        label: 'Net',
        value: (state) => money(orderTotals(state).netCents),
        format: BeakValueFormat.currency,
      ),
      BeakSummaryLine(
        label: 'VAT 10%',
        value: (state) => money(orderTotals(state).taxByRate[1000] ?? 0),
        format: BeakValueFormat.currency,
      ),
      BeakSummaryLine(
        label: 'VAT 20%',
        value: (state) => money(orderTotals(state).taxByRate[2000] ?? 0),
        format: BeakValueFormat.currency,
      ),
    ],
    BeakSummaryLine(
      label: 'Total',
      value: (state) => money(orderTotals(state).grossCents),
      format: BeakValueFormat.currency,
      emphasized: true,
    ),
  ],
);

const _summaryTitle = TextStyle(
  fontSize: 16,
  height: 1.5,
  fontWeight: FontWeight.w600,
);
const _summaryLabel = TextStyle(
  fontSize: 12,
  height: 4 / 3,
  fontWeight: FontWeight.w500,
);
