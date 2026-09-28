import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';

import '../../../models/models.dart';
import '../../../theme/gabel_theme.dart';
import '../../../domain/foodio_clock.dart';
import 'order_items_table.dart';
import '../presentations/order_presentations.dart';
import 'order_totals.dart';

/// The review reuses the same draft and points back to its owning wizard steps.
BeakWizardStep orderReviewStep() => BeakWizardStep(
  title: 'Review',
  heading: 'Check and place the order',
  introduction: 'Nothing is sent until you place the order.',
  description: 'Check, then place the order',
  footerHintBuilder: (state, _) => _needsApproval(state)
      ? 'Placing sends the approval request to ${state.asOrder.profile?.approver?.name ?? 'the company approver'}.'
      : 'Placing sends the order confirmation.',
  children: [
    approvalNotice(),
    BeakFormLayout(
      spacing: 0,
      children: [
        BeakReviewSection(
          title: 'Customer & profile',
          stepIndex: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          contentPadding: const EdgeInsets.only(top: 2),
          dividerSpacing: 0,
          titleStyle: _reviewHeading,
          children: [
            BeakFormTemplate(
              template: BeakRecordTemplate(
                title: BeakValueBinding.field(
                  OrderModel.customer.name,
                  strong: true,
                ),
                textGap: 0,
                titleMetadata: [
                  BeakValueBinding.field(
                    OrderModel.customer.email,
                    textStyle: _reviewText,
                  ),
                ],
                inlineSubtitle: true,
                subtitle: [
                  BeakValueBinding.field(
                    OrderModel.profile.name,
                    textStyle: _reviewText,
                  ),
                  BeakValueBinding.field(
                    OrderModel.profile.role,
                    textStyle: _reviewText,
                  ),
                ],
              ),
            ),
          ],
        ),
        BeakReviewSection(
          title: 'Delivery',
          stepIndex: 1,
          padding: const EdgeInsets.symmetric(vertical: 12),
          contentPadding: const EdgeInsets.only(top: 2),
          dividerSpacing: 0,
          titleStyle: _reviewHeading,
          children: [
            BeakFormTemplate(
              template: BeakRecordTemplate(
                title: BeakValueBinding<String>.computed(
                  dependencies: [OrderModel.deliveryDate, OrderModel.slot.name],
                  compute: (state) =>
                      '${const BeakFormatPolicy(locale: 'en_US', datePattern: 'EEE d MMM yyyy').format(state.read(OrderModel.deliveryDate), BeakValueFormat.date)} · ${state.read(OrderModel.slot.name) ?? '—'}',
                  strong: true,
                ),
                textGap: 0,
                subtitle: [
                  BeakValueBinding<String>.computed(
                    dependencies: [
                      OrderModel.location.name,
                      OrderModel.handover,
                      OrderModel.location.street,
                      OrderModel.street,
                      OrderModel.addressOverride,
                    ],
                    compute: (state) =>
                        [
                              state.read(OrderModel.location.name),
                              state.read(OrderModel.handover),
                              state.read(OrderModel.addressOverride) == true
                                  ? state.read(OrderModel.street)
                                  : state.read(OrderModel.location.street),
                            ]
                            .whereType<String>()
                            .where((part) => part.isNotEmpty)
                            .join(' – '),
                    textStyle: _reviewText,
                    maxLines: null,
                  ),
                  BeakValueBinding<String>.computed(
                    dependencies: [
                      OrderModel.location.method,
                      OrderModel.location.routeCode,
                    ],
                    compute: (state) =>
                        '${state.read(OrderModel.location.method) == 'office' ? 'Office delivery' : 'Home delivery'} · ${_transport(state)}',
                    textStyle: _reviewText,
                    maxLines: null,
                  ),
                  BeakValueBinding<String>.computed(
                    dependencies: [OrderModel.deliveryNote],
                    compute: (state) =>
                        'Note: “${state.read(OrderModel.deliveryNote) ?? ''}”',
                    visibleIf: (state) =>
                        state.read(OrderModel.deliveryNote)?.isNotEmpty == true,
                    textStyle: _reviewText,
                    maxLines: null,
                  ),
                ],
              ),
            ),
          ],
        ),
        BeakReviewSection(
          title: 'Dishes',
          stepIndex: 2,
          padding: const EdgeInsets.symmetric(vertical: 12),
          dividerSpacing: 0,
          titleStyle: _reviewHeading,
          children: [
            orderItems(allowEditing: false, compact: true, review: true),
          ],
        ),
        BeakReviewSection(
          title: 'Payment & voucher',
          stepIndex: 3,
          divider: false,
          padding: const EdgeInsets.symmetric(vertical: 12),
          contentPadding: const EdgeInsets.only(top: 2),
          dividerSpacing: 0,
          titleStyle: _reviewHeading,
          children: [
            BeakFormTemplate(
              template: BeakRecordTemplate(
                textGap: 0,
                title: BeakValueBinding<String>.computed(
                  dependencies: [OrderModel.paymentMode, OrderModel.costCenter],
                  compute: (state) => [
                    paymentLabels[state.read(OrderModel.paymentMode)],
                    if (state.read(OrderModel.costCenter)?.isNotEmpty == true)
                      'cost centre ${state.read(OrderModel.costCenter)}',
                  ].whereType<String>().join(' · '),
                  strong: true,
                  textStyle: _reviewText,
                ),
                subtitle: [
                  BeakValueBinding<String>.computed(
                    dependencies: [
                      OrderModel.voucher.code,
                      OrderModel.profile.organization.invoices,
                      OrderModel.deliveryDate,
                      OrderModel.paymentMode,
                    ],
                    compute: (state) => [
                      if (state.read(OrderModel.voucher.code) case final code?)
                        'Voucher $code applied',
                      if (draftInvoiceForOrder(state)?.reference
                          case final invoice?)
                        'billed on $invoice',
                    ].join(' · '),
                    textStyle: _reviewText,
                    maxLines: null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
    BeakFormMetrics(
      minColumnWidth: 120,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      gap: 2,
      inset: true,
      metrics: [
        BeakFormMetric(
          label: 'Subtotal',
          value: (state) => money(orderTotals(state).subtotalCents),
          format: BeakValueFormat.currency,
          valueStyle: gabelNumericMetricStyle,
          subtitle: (state, _) =>
              '${state.rows(OrderModel.items).fold<int>(0, (sum, row) => sum + (row.asOrderItem.quantity ?? 0))} dishes',
        ),
        BeakFormMetric(
          label: 'Voucher',
          value: (state) => money(-orderTotals(state).discountCents),
          format: BeakValueFormat.currency,
          valueStyle: gabelNumericMetricStyle,
          subtitle: (state, _) => state.asOrder.voucher == null
              ? 'No voucher'
              : '${state.asOrder.voucher!.code} · ${state.asOrder.voucher!.percentBasisPoints / 100}%',
          dependencies: [
            OrderModel.voucher.code,
            OrderModel.voucher.percentBasisPoints,
          ],
        ),
        BeakFormMetric(
          label: 'Delivery',
          value: (_) => money(0),
          format: BeakValueFormat.currency,
          valueStyle: gabelNumericMetricStyle,
          description: 'waived',
        ),
        BeakFormMetric(
          label: 'VAT',
          labelBuilder: (state, format) =>
              'VAT ${orderTotals(state).taxByRate.keys.map((rate) => '${format.number(rate / 100)}%').join(' + ')}',
          value: (state) => money(
            orderTotals(state).grossCents - orderTotals(state).netCents,
          ),
          format: BeakValueFormat.currency,
          valueStyle: gabelNumericMetricStyle,
          subtitle: (state, format) =>
              'net ${format.currency(orderTotals(state).netCents / 100)}',
        ),
        BeakFormMetric(
          label: 'Total',
          value: (state) => money(orderTotals(state).grossCents),
          format: BeakValueFormat.currency,
          valueStyle: gabelNumericTotalStyle,
          description: 'incl. VAT',
        ),
      ],
    ),
    BeakFormPlaceholder(
      label: 'A new order will be created',
      height: 90,
      template: BeakRecordTemplate(
        title: BeakValueBinding<String>.computed(
          dependencies: const [],
          compute: (_) => 'A new order will be created',
        ),
        inlineBadges: true,
        badges: [
          BeakValueBinding<String>.computed(
            dependencies: [
              OrderModel.profile.approvalThresholdCents,
              OrderModel.profile.kind,
              OrderModel.items,
              OrderModel.voucher,
            ],
            compute: (row) =>
                _draftNeedsApproval(row) ? 'Approval needed' : 'Draft',
            tone: (row) =>
                _draftNeedsApproval(row) ? BeakColor.warning : BeakColor.muted,
            badge: true,
            badgeDot: true,
            color: BeakColor.muted,
          ),
        ],
        subtitle: [
          BeakValueBinding<String>.computed(
            dependencies: [
              OrderModel.customer.name,
              OrderModel.profile.approver.name,
            ],
            compute: (row) =>
                'Confirmation email to ${row.read(OrderModel.customer.name) ?? 'the customer'} · approval request to ${row.read(OrderModel.profile.approver.name) ?? 'the approver'}',
            maxLines: null,
          ),
        ],
        icon: BeakValueBinding<IconData>.computed(
          dependencies: const [],
          compute: (_) => OiIcons.packageCheck,
        ),
        iconSize: 32,
        identityGap: 12,
        textGap: 2,
      ),
    ),
  ],
);

const _reviewHeading = TextStyle(
  fontSize: 16,
  height: 1.5,
  fontWeight: FontWeight.w600,
);
const _reviewText = TextStyle(fontSize: 14, height: 20 / 14);

String _transport(BeakDraftReader row) {
  final route = row.read(OrderModel.location.routeCode) ?? '';
  return route.toLowerCase().startsWith('bike')
      ? 'Bike courier'
      : 'Cooled van, Route $route';
}

bool _draftNeedsApproval(BeakDraftReader row) =>
    row is BeakDraftRecord && _needsApproval(BeakFormReader(row));

/// Shows the operational next steps instead of repeating the review's content.
BeakFormLayout orderReviewAside() => BeakFormLayout(
  visibleIf: (state) => state.stepIndex == 4,
  children: [
    BeakSection(
      title: 'What happens next',
      titleStyle: const TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w600,
      ),
      trailing: BeakValueBinding<String>.computed(
        dependencies: const [],
        compute: (_) => 'Draft',
        badge: true,
        badgeDot: true,
        color: BeakColor.muted,
      ),
      children: [
        const BeakCalculated(value: _afterPlace),
        BeakFormProgress(
          field: OrderModel.status,
          planned: true,
          timeline: true,
          contextSpacing: 8,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            height: 24 / 14,
          ),
          steps: [
            BeakProgressStep(
              state: OrderStatus.draft,
              label: 'Order confirmation',
              labelBuilder: (state) => _needsApproval(state)
                  ? '${state.asOrder.profile?.approver?.name ?? 'The company approver'} gets an approval request'
                  : 'Order confirmation',
              dependencies: [OrderModel.profile.approver.name],
              details: BeakRecordTemplate(
                title: BeakValueBinding<String>.computed(
                  dependencies: [
                    OrderModel.sendConfirmation,
                    OrderModel.customer.email,
                  ],
                  compute: (_) => 'Today, right after you place the order',
                  maxLines: null,
                ),
              ),
              contextInset: true,
              context: BeakRecordTemplate(
                title: BeakValueBinding.field(
                  OrderModel.profile.approver.name,
                  textStyle: const TextStyle(fontWeight: FontWeight.w500),
                ),
                inlineSubtitle: true,
                subtitle: [
                  BeakValueBinding<String>.computed(
                    dependencies: [
                      OrderModel.profile.approver.role,
                      OrderModel.profile.approver.email,
                    ],
                    compute: (row) {
                      final role = row.read(OrderModel.profile.approver.role);
                      final email = row.read(OrderModel.profile.approver.email);
                      return [
                        if (role?.isNotEmpty == true)
                          role == 'administrator' ? 'Admin' : role!,
                        if (email?.isNotEmpty == true) email!,
                      ].join(' · ');
                    },
                    maxLines: 1,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: .12,
                    ),
                  ),
                ],
                avatar: true,
                avatarSize: OiAvatarSize.xs,
                avatarPalette: identityPalette,
                avatarTone: BeakValueBinding<BeakAvatarTone>.computed(
                  dependencies: const [],
                  compute: (_) => identityPalette[1],
                ),
                identityGap: 8,
                textGap: 0,
              ),
            ),
            BeakProgressStep(
              state: OrderStatus.confirmed,
              label: 'Kitchen preparation',
              labelBuilder: (state) =>
                  'Kitchen planned on ${const BeakFormatPolicy(locale: 'en_US', datePattern: 'EEE d MMM').format(state.asOrder.deliveryDate, BeakValueFormat.date)} at ${const BeakFormatPolicy().clockTime(const FoodioClock().kitchenPreparationStart)}',
              dependencies: [OrderModel.deliveryDate],
              details: BeakRecordTemplate(
                title: BeakValueBinding<String>.computed(
                  dependencies: [OrderModel.profile.approver.name],
                  compute: (row) =>
                      'Only once ${row.read(OrderModel.profile.approver.name) ?? 'the approver'} has approved',
                  maxLines: null,
                ),
              ),
            ),
            BeakProgressStep(
              state: OrderStatus.outForDelivery,
              label: 'Delivery',
              labelBuilder: (state) =>
                  'Delivery between ${(state.asOrder.slot?.name ?? '—').replaceAll('–', ' and ').replaceAll('-', ' and ')}',
              dependencies: [OrderModel.slot.name],
              details: BeakRecordTemplate(
                title: BeakValueBinding<String>.computed(
                  dependencies: [
                    OrderModel.location.name,
                    OrderModel.handover,
                    OrderModel.location.routeCode,
                  ],
                  compute: (row) =>
                      '${row.read(OrderModel.location.name) ?? '—'} – ${row.read(OrderModel.handover) ?? ''}; ${_transport(row)}',
                  maxLines: null,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

String _afterPlace(BeakFormReader _) => 'Once you place the order:';

bool _needsApproval(BeakFormReader state) =>
    state.asOrder.profile?.kind == 'company' &&
    orderTotals(state).grossCents >
        (state.asOrder.profile?.approvalThresholdCents ?? 4000);

/// The same approval explanation is used by review and the live summary.
BeakFormNotice approvalNotice() => BeakFormNotice(
  title: 'Needs approval',
  titleBuilder: (state) =>
      'Needs approval — this order is over €${BeakDecimal(state.asOrder.profile?.approvalThresholdCents ?? 0, scale: 2)}.',
  tone: BeakColor.warning,
  visibleIf: (state) =>
      state.asOrder.profile?.kind == 'company' &&
      orderTotals(state).grossCents >
          (state.asOrder.profile?.approvalThresholdCents ?? 4000),
  dependencies: [OrderModel.profile.approver.name],
  message: (state) =>
      '${state.asOrder.profile?.approver?.name ?? 'The company approver'} gets an approval request; the kitchen starts once the order is approved.',
);
