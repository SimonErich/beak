import 'package:beak/panel.dart';
import '../models/voucher.dart';

/// Voucher value, scheduling and eligibility without custom form state.
BeakFormLayout voucherForm() => BeakFormLayout(
  children: [
    BeakColumns(
      children: [
        BeakCard(
          title: 'Discount',
          children: [
            VoucherModel.code.inputText(label: 'Voucher code'),
            VoucherModel.name.inputText(label: 'Description'),
            VoucherModel.kind.input(label: 'Discount type'),
            VoucherModel.value.inputNumber(
              label: 'Amount / percentage',
              description:
                  'Fixed vouchers use euros. Percentage vouchers use 0–100.',
              validators: [
                (value, state) =>
                    state.asVoucher.kind == VoucherKind.percentage &&
                        (value ?? 0) > 100
                    ? 'Enter a percentage between 0 and 100.'
                    : null,
              ],
            ),
            VoucherModel.active.inputToggle(label: 'Active'),
          ],
        ),
        BeakCard(
          title: 'Eligibility',
          description: 'Empty limits allow any order value and any date.',
          children: [
            VoucherModel.minimumSubtotal.inputCurrency(
              label: 'Minimum net subtotal',
            ),
            VoucherModel.maximumDiscount.inputCurrency(
              label: 'Maximum discount',
            ),
            VoucherModel.startsAt.inputDateTime(label: 'Valid from'),
            VoucherModel.endsAt.inputDateTime(
              label: 'Valid until',
              validators: [
                (value, state) =>
                    value != null &&
                        state.asVoucher.startsAt != null &&
                        !value.isAfter(state.asVoucher.startsAt!)
                    ? 'The end must be after the start.'
                    : null,
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
