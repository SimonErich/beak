import 'package:clean_beak_config/domain/shop_totals.dart';
import 'package:test/test.dart';

void main() {
  test('multiple vouchers apply sequentially before exclusive line tax', () {
    const lines = [
      ShopLineInput(
        id: 'coffee',
        label: 'Coffee',
        quantity: 2,
        unitPriceCents: 4900,
        taxBasisPoints: 2000,
      ),
      ShopLineInput(
        id: 'service',
        label: 'Consultation',
        quantity: 1,
        unitPriceCents: 2500,
        taxBasisPoints: 2000,
      ),
    ];
    const percentage = ShopVoucherInput.percentage(
      id: 'welcome',
      code: 'WELCOME10',
      basisPoints: 1000,
    );
    const fixed = ShopVoucherInput.fixed(
      id: 'loyalty',
      code: 'LOYAL5',
      amountCents: 500,
    );
    final totals = ShopTotals.calculate(
      lines: lines,
      vouchers: [percentage, fixed],
    );
    expect(totals.subtotalCents, 12300);
    expect(totals.discountCents, 1730);
    expect(totals.netCents, 10570);
    expect(totals.taxCents, 2114);
    expect(totals.totalCents, 12684);
    expect(totals.lines.map((line) => line.netCents), [8422, 2148]);
    expect(totals.vouchers.map((voucher) => voucher.discountCents), [
      1230,
      500,
    ]);
    expect(
      ShopTotals.calculate(
        lines: lines,
        vouchers: [fixed, percentage],
      ).discountCents,
      1680,
    );
  });

  test('mixed tax rates and largest remainders preserve every cent', () {
    final totals = ShopTotals.calculate(
      lines: const [
        ShopLineInput(
          id: 'one',
          label: 'One',
          quantity: 1,
          unitPriceCents: 101,
          taxBasisPoints: 1000,
        ),
        ShopLineInput(
          id: 'two',
          label: 'Two',
          quantity: 1,
          unitPriceCents: 202,
          taxBasisPoints: 2000,
        ),
        ShopLineInput(
          id: 'three',
          label: 'Three',
          quantity: 1,
          unitPriceCents: 303,
        ),
      ],
      vouchers: const [
        ShopVoucherInput.fixed(id: 'v', code: 'ONE', amountCents: 100),
      ],
    );
    expect(totals.lines.map((line) => line.voucherDiscountCents), [17, 33, 50]);
    expect(totals.lines.map((line) => line.taxCents), [8, 34, 0]);
    expect(totals.netCents, 506);
    expect(totals.totalCents, 548);
    expect(
      totals.lines.fold<int>(0, (sum, line) => sum + line.totalCents),
      totals.totalCents,
    );
  });

  test('line discounts precede capped vouchers and tax rounds per line', () {
    final totals = ShopTotals.calculate(
      lines: const [
        ShopLineInput(
          id: 'a',
          label: 'A',
          quantity: 1,
          unitPriceCents: 4,
          lineDiscountCents: 1,
          taxBasisPoints: 2000,
        ),
        ShopLineInput(
          id: 'b',
          label: 'B',
          quantity: 1,
          unitPriceCents: 3,
          taxBasisPoints: 2000,
        ),
      ],
    );
    expect(totals.taxCents, 2); // Each 0.6 cent tax rounds up independently.
    expect(totals.totalCents, 8);
    final free = ShopTotals.calculate(
      lines: const [
        ShopLineInput(id: 'a', label: 'A', quantity: 1, unitPriceCents: 10),
      ],
      vouchers: const [
        ShopVoucherInput.fixed(id: 'free', code: 'FREE', amountCents: 100),
      ],
    );
    expect(free.discountCents, 10);
    expect(free.totalCents, 0);
    final capped = ShopTotals.calculate(
      lines: const [
        ShopLineInput(id: 'a', label: 'A', quantity: 1, unitPriceCents: 1000),
      ],
      vouchers: const [
        ShopVoucherInput.percentage(
          id: 'v',
          code: 'CAP',
          basisPoints: 5000,
          maximumDiscountCents: 100,
        ),
      ],
    );
    expect(capped.discountCents, 100);
  });

  test(
    'invalid amounts, duplicate vouchers and oversized line discounts reject',
    () {
      const line = ShopLineInput(
        id: 'a',
        label: 'A',
        quantity: 1,
        unitPriceCents: 100,
      );
      const voucher = ShopVoucherInput.fixed(
        id: 'v',
        code: 'V',
        amountCents: 5,
      );
      expect(
        () => ShopTotals.calculate(lines: [line], vouchers: [voucher, voucher]),
        throwsFormatException,
      );
      expect(() => ShopTotals.calculate(lines: []), throwsFormatException);
      expect(
        () => ShopTotals.calculate(
          lines: [line],
          vouchers: const [
            ShopVoucherInput.fixed(
              id: 'v',
              code: 'MIN',
              amountCents: 5,
              minimumSubtotalCents: 200,
            ),
          ],
        ),
        throwsFormatException,
      );
      expect(
        () => ShopTotals.calculate(
          lines: const [
            ShopLineInput(
              id: 'a',
              label: 'A',
              quantity: 1,
              unitPriceCents: 100,
              lineDiscountCents: 101,
            ),
          ],
        ),
        throwsFormatException,
      );
      expect(
        () => ShopTotals.calculate(
          lines: const [
            ShopLineInput(
              id: 'a',
              label: 'A',
              quantity: 0,
              unitPriceCents: 100,
            ),
          ],
        ),
        throwsFormatException,
      );
      expect(ShopMoney.cents(12.34), 1234);
      expect(ShopMoney.basisPoints(19.99), 1999);
      expect(ShopMoney.format(1234), '€12.34');
      expect(() => ShopMoney.cents(1.005), throwsFormatException);
      expect(() => ShopMoney.cents(double.nan), throwsFormatException);
      expect(() => ShopMoney.basisPoints(101), throwsFormatException);
    },
  );
}
