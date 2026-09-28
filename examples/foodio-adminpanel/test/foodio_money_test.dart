import 'package:foodio_adminpanel/domain/foodio_money.dart';
import 'package:test/test.dart';

void main() {
  test('reference invoice and soup edit reconcile inclusive tax buckets', () {
    final lines = [
      const FoodioMoneyLine(
        key: 'risotto',
        grossCents: 1190,
        taxBasisPoints: 1000,
      ),
      const FoodioMoneyLine(key: 'dal', grossCents: 1240, taxBasisPoints: 1000),
      const FoodioMoneyLine(
        key: 'strudel',
        grossCents: 420,
        taxBasisPoints: 1000,
      ),
      const FoodioMoneyLine(
        key: 'drink',
        grossCents: 290,
        taxBasisPoints: 2000,
        food: false,
      ),
    ];
    final initial = FoodioTotals.calculate(lines);
    expect(initial.grossCents, 3140);
    expect(initial.taxCents, 307);
    expect(initial.netCents, 2833);
    final edited = FoodioTotals.calculate([
      ...lines,
      const FoodioMoneyLine(key: 'soup', grossCents: 450, taxBasisPoints: 1000),
    ]);
    expect(edited.grossCents, 3590);
    expect(edited.netCents, 3242);
    expect(edited.taxByRate, {1000: 300, 2000: 48});
  });
  test('wizard voucher applies 15 percent food discount with exact VAT', () {
    final total = FoodioTotals.calculate(
      [
        const FoodioMoneyLine(
          key: 'risotto',
          grossCents: 2380,
          taxBasisPoints: 1000,
        ),
        const FoodioMoneyLine(
          key: 'dal',
          grossCents: 1090,
          taxBasisPoints: 1000,
        ),
        const FoodioMoneyLine(
          key: 'schnitzel',
          grossCents: 1390,
          taxBasisPoints: 1000,
        ),
      ],
      voucherBasisPoints: 1500,
      voucherCapCents: 1000,
    );
    expect(total.voucherDiscountCents, 729);
    expect(total.grossCents, 4131);
    expect(total.netCents, 3755);
    expect(total.taxCents, 376);
    expect(
      total.lines.fold<int>(0, (sum, line) => sum + line.taxCents),
      total.taxCents,
    );
  });
  test('discount remainder is stable by identity across reordered lines', () {
    final lines = [
      for (final key in ['b', 'a', 'c'])
        FoodioMoneyLine(key: key, grossCents: 1, taxBasisPoints: 2000),
    ];
    final first = FoodioTotals.calculate(lines, manualDiscountCents: 1);
    final second = FoodioTotals.calculate(
      lines.reversed.toList(),
      manualDiscountCents: 1,
    );
    expect(
      {for (final line in first.lines) line.key: line.discountCents},
      {'b': 0, 'a': 1, 'c': 0},
    );
    expect(
      {for (final line in first.lines) line.key: line.taxCents},
      {for (final line in second.lines) line.key: line.taxCents},
    );
  });
  test('food-only cap excludes drinks and manual discount cannot overdraw', () {
    final lines = [
      const FoodioMoneyLine(
        key: 'food',
        grossCents: 20000,
        taxBasisPoints: 1000,
      ),
      const FoodioMoneyLine(
        key: 'drink',
        grossCents: 1000,
        taxBasisPoints: 2000,
        food: false,
      ),
    ];
    expect(
      FoodioTotals.calculate(
        lines,
        voucherBasisPoints: 1500,
        voucherCapCents: 1000,
      ).voucherDiscountCents,
      1000,
    );
    expect(
      () => FoodioTotals.calculate(lines, manualDiscountCents: 21001),
      throwsArgumentError,
    );
    expect(
      () => FoodioTotals.calculate([lines.first, lines.first]),
      throwsArgumentError,
    );
  });
}
