import 'package:beak/beak.dart';
import 'package:clean_beak_config/domain/shop_totals.dart';
import 'package:test/test.dart';

import 'support/money.dart';

void main() {
  test('multiple vouchers apply sequentially before exclusive line tax', () {
    final lines = [
      ShopLineInput(
        id: 'coffee',
        label: 'Coffee',
        quantity: 2,
        unitPrice: eur('49.00'),
        taxRate: eur('20'),
      ),
      ShopLineInput(
        id: 'service',
        label: 'Consultation',
        quantity: 1,
        unitPrice: eur('25.00'),
        taxRate: eur('20'),
      ),
    ];
    final percentage = ShopVoucherInput.percentage(
      id: 'welcome',
      code: 'WELCOME10',
      percent: eur('10'),
    );
    final fixed = ShopVoucherInput.fixed(
      id: 'loyalty',
      code: 'LOYAL5',
      amount: eur('5.00'),
    );
    final totals = ShopTotals.calculate(
      lines: lines,
      vouchers: [percentage, fixed],
    );
    expect(totals.subtotal, eur('123.00'));
    expect(totals.discount, eur('17.30'));
    expect(totals.net, eur('105.70'));
    expect(totals.tax, eur('21.14'));
    expect(totals.total, eur('126.84'));
    expect(totals.lines.map((line) => line.net), [eur('84.22'), eur('21.48')]);
    expect(totals.vouchers.map((voucher) => voucher.discount), [
      eur('12.30'),
      eur('5.00'),
    ]);
    expect(
      ShopTotals.calculate(
        lines: lines,
        vouchers: [fixed, percentage],
      ).discount,
      eur('16.80'),
    );
  });

  test('mixed tax rates and largest remainders preserve every cent', () {
    final totals = ShopTotals.calculate(
      lines: [
        ShopLineInput(
          id: 'one',
          label: 'One',
          quantity: 1,
          unitPrice: eur('1.01'),
          taxRate: eur('10'),
        ),
        ShopLineInput(
          id: 'two',
          label: 'Two',
          quantity: 1,
          unitPrice: eur('2.02'),
          taxRate: eur('20'),
        ),
        ShopLineInput(
          id: 'three',
          label: 'Three',
          quantity: 1,
          unitPrice: eur('3.03'),
        ),
      ],
      vouchers: [
        ShopVoucherInput.fixed(id: 'v', code: 'ONE', amount: eur('1.00')),
      ],
    );
    expect(totals.lines.map((line) => line.voucherDiscount), [
      eur('0.17'),
      eur('0.33'),
      eur('0.50'),
    ]);
    expect(totals.lines.map((line) => line.tax), [
      eur('0.08'),
      eur('0.34'),
      eur('0.00'),
    ]);
    expect(totals.net, eur('5.06'));
    expect(totals.total, eur('5.48'));
    expect(
      totals.lines.fold(ShopMoney.zero, (sum, line) => sum + line.total),
      totals.total,
    );
  });

  test('line discounts precede capped vouchers and tax rounds per line', () {
    final totals = ShopTotals.calculate(
      lines: [
        ShopLineInput(
          id: 'a',
          label: 'A',
          quantity: 1,
          unitPrice: eur('0.04'),
          lineDiscount: eur('0.01'),
          taxRate: eur('20'),
        ),
        ShopLineInput(
          id: 'b',
          label: 'B',
          quantity: 1,
          unitPrice: eur('0.03'),
          taxRate: eur('20'),
        ),
      ],
    );
    expect(totals.tax, eur('0.02')); // Each 0.6 cent tax rounds up alone.
    expect(totals.total, eur('0.08'));
    final free = ShopTotals.calculate(
      lines: [
        ShopLineInput(id: 'a', label: 'A', quantity: 1, unitPrice: eur('0.10')),
      ],
      vouchers: [
        ShopVoucherInput.fixed(id: 'free', code: 'FREE', amount: eur('1.00')),
      ],
    );
    expect(free.discount, eur('0.10'));
    expect(free.total, eur('0.00'));
    final capped = ShopTotals.calculate(
      lines: [
        ShopLineInput(
          id: 'a',
          label: 'A',
          quantity: 1,
          unitPrice: eur('10.00'),
        ),
      ],
      vouchers: [
        ShopVoucherInput.percentage(
          id: 'v',
          code: 'CAP',
          percent: eur('50'),
          maximumDiscount: eur('1.00'),
        ),
      ],
    );
    expect(capped.discount, eur('1.00'));
  });

  test('amounts of any scale are accepted when they are exact', () {
    final totals = ShopTotals.calculate(
      lines: [
        ShopLineInput(
          id: 'a',
          label: 'A',
          quantity: 3,
          unitPrice: BeakDecimal.parse('2.500', scale: 3),
          taxRate: BeakDecimal.parse('7.5', scale: 1),
        ),
      ],
    );
    expect(totals.subtotal, eur('7.50'));
    expect(totals.tax, eur('0.56'));
    expect(totals.total, eur('8.06'));
    expect(totals.total.scale, ShopMoney.scale);
  });

  test('money helpers validate scale, sign and range', () {
    expect(ShopMoney.amount(const BeakDecimal(5, scale: 0)), eur('5.00'));
    expect(
      () => ShopMoney.amount(const BeakDecimal(1005, scale: 3)),
      throwsFormatException,
    );
    expect(
      () => ShopMoney.amount(const BeakDecimal(-1)),
      throwsFormatException,
    );
    expect(
      () => ShopMoney.amount(const BeakDecimal(1000000000001)),
      throwsFormatException,
    );
    expect(ShopMoney.percentage(eur('19.99')), eur('19.99'));
    expect(() => ShopMoney.percentage(eur('100.01')), throwsFormatException);
    expect(() => ShopMoney.percentage(eur('-1')), throwsFormatException);
    expect(ShopMoney.percentOf(eur('105.70'), eur('20')), eur('21.14'));
    expect(ShopMoney.percentOf(eur('0.03'), eur('20')), eur('0.01'));
  });

  test(
    'invalid amounts, duplicate vouchers and oversized line discounts reject',
    () {
      final line = ShopLineInput(
        id: 'a',
        label: 'A',
        quantity: 1,
        unitPrice: eur('1.00'),
      );
      final voucher = ShopVoucherInput.fixed(
        id: 'v',
        code: 'V',
        amount: eur('0.05'),
      );
      expect(
        () => ShopTotals.calculate(lines: [line], vouchers: [voucher, voucher]),
        throwsFormatException,
      );
      expect(() => ShopTotals.calculate(lines: []), throwsFormatException);
      expect(
        () => ShopTotals.calculate(
          lines: [line],
          vouchers: [
            ShopVoucherInput.fixed(
              id: 'v',
              code: 'MIN',
              amount: eur('0.05'),
              minimumSubtotal: eur('2.00'),
            ),
          ],
        ),
        throwsFormatException,
      );
      expect(
        () => ShopTotals.calculate(
          lines: [
            ShopLineInput(
              id: 'a',
              label: 'A',
              quantity: 1,
              unitPrice: eur('1.00'),
              lineDiscount: eur('1.01'),
            ),
          ],
        ),
        throwsFormatException,
      );
      expect(
        () => ShopTotals.calculate(
          lines: [
            ShopLineInput(
              id: 'a',
              label: 'A',
              quantity: 0,
              unitPrice: eur('1.00'),
            ),
          ],
        ),
        throwsFormatException,
      );
      expect(
        () => ShopTotals.calculate(lines: [line, line]),
        throwsFormatException,
      );
      expect(
        () => ShopTotals.calculate(
          lines: [
            const ShopLineInput(
              id: 'big',
              label: 'Big',
              quantity: 2,
              unitPrice: ShopMoney.maximum,
            ),
          ],
        ),
        throwsFormatException,
      );
    },
  );
}
