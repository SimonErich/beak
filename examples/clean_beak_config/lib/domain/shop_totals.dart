import 'package:beak/beak.dart';

/// Exact euro arithmetic shared by the server and the form previews.
///
/// Every amount is a [BeakDecimal] with two decimal places; nothing here
/// converts to a binary floating-point number.
abstract final class ShopMoney {
  /// Decimal places of every amount and percentage.
  static const int scale = 2;

  /// The zero amount.
  static const BeakDecimal zero = BeakDecimal(0);

  /// Largest amount accepted by this demonstration, safely representable on web.
  static const BeakDecimal maximum = BeakDecimal(1000000000000);

  static const BeakDecimal _hundred = BeakDecimal(10000);

  /// Validates a non-negative amount and returns it with two decimal places.
  ///
  /// Throws a [FormatException] for a negative or oversized amount, and for one
  /// with more precision than cents.
  static BeakDecimal amount(BeakDecimal value) {
    final exact = _atScale(value);
    if (exact.units < 0 || exact.compareTo(maximum) > 0) {
      throw const FormatException('Enter a non-negative monetary amount.');
    }
    return exact;
  }

  /// Validates a percentage from 0 to 100 with at most two decimal places.
  static BeakDecimal percentage(BeakDecimal value) {
    final exact = _atScale(value);
    if (exact.units < 0 || exact.compareTo(_hundred) > 0) {
      throw const FormatException('Enter a percentage between 0 and 100.');
    }
    return exact;
  }

  /// [percent] of [amount], rounded half-up to a whole cent.
  static BeakDecimal percentOf(BeakDecimal amount, BeakDecimal percent) =>
      BeakDecimal(
        roundRatio(
          _atScale(amount).units,
          _atScale(percent).units,
          _hundred.units,
        ),
      );

  /// Rounds a non-negative rational amount half-up, without floating-point math.
  static int roundRatio(int value, int multiplier, int divisor) =>
      ((BigInt.from(value) * BigInt.from(multiplier) +
                  BigInt.from(divisor ~/ 2)) ~/
              BigInt.from(divisor))
          .toInt();

  static BeakDecimal _atScale(BeakDecimal value) {
    try {
      return value.rescale(scale);
    } on FormatException {
      throw const FormatException('Money supports at most two decimal places.');
    }
  }
}

/// A complete line price expressed in exact euros and a tax percentage.
final class ShopLineInput {
  /// Creates one uniquely identified product, variant or custom line.
  const ShopLineInput({
    required this.id,
    required this.label,
    required this.quantity,
    required this.unitPrice,
    this.lineDiscount = ShopMoney.zero,
    this.taxRate = ShopMoney.zero,
  });

  /// Stable row identity for matching previews and saved snapshots.
  final String id;

  /// Saved line description.
  final String label;

  /// Number of whole units.
  final int quantity;

  /// Net unit price.
  final BeakDecimal unitPrice;

  /// Net reduction on the whole line before invoice-level vouchers.
  final BeakDecimal lineDiscount;

  /// Exclusive tax rate as a percentage, where 20 means 20 percent.
  final BeakDecimal taxRate;
}

/// A voucher application in explicit application order.
final class ShopVoucherInput {
  /// A fixed reduction, capped at the remaining net subtotal.
  const ShopVoucherInput.fixed({
    required this.id,
    required this.code,
    required BeakDecimal amount,
    this.minimumSubtotal = ShopMoney.zero,
    this.maximumDiscount,
  }) : value = amount,
       percentage = false;

  /// A percentage reduction on the net subtotal remaining after prior vouchers.
  const ShopVoucherInput.percentage({
    required this.id,
    required this.code,
    required BeakDecimal percent,
    this.minimumSubtotal = ShopMoney.zero,
    this.maximumDiscount,
  }) : value = percent,
       percentage = true;

  /// Voucher identity; duplicates within one invoice are rejected.
  final String id;

  /// Snapshot of the redemption code.
  final String code;

  /// A euro amount for fixed vouchers, a percentage for percentage vouchers.
  final BeakDecimal value;

  /// Whether [value] is a percentage.
  final bool percentage;

  /// Eligibility threshold measured before all invoice-level vouchers.
  final BeakDecimal minimumSubtotal;

  /// Optional maximum discount for this application.
  final BeakDecimal? maximumDiscount;
}

/// The amount allocated to an individual line after all voucher applications.
final class ShopLineTotal {
  const ShopLineTotal._(
    this.input,
    this.subtotal,
    this.voucherDiscount,
    this.net,
    this.tax,
  );

  /// Original price and tax snapshot.
  final ShopLineInput input;

  /// Line subtotal after the line-level discount and before vouchers.
  final BeakDecimal subtotal;

  /// Proportional share of all invoice-level vouchers.
  final BeakDecimal voucherDiscount;

  /// Remaining taxable net amount.
  final BeakDecimal net;

  /// Tax rounded half-up on this line's remaining taxable amount.
  final BeakDecimal tax;

  /// Amount payable for this line.
  BeakDecimal get total => net + tax;
}

/// A voucher definition paired with its actual capped reduction.
final class ShopVoucherTotal {
  const ShopVoucherTotal._(this.input, this.discount);

  /// Applied voucher definition.
  final ShopVoucherInput input;

  /// Actual reduction after capping at the remaining subtotal.
  final BeakDecimal discount;
}

/// Deterministic invoice arithmetic for the example's exclusive-tax policy.
///
/// Line discounts apply first. Vouchers then apply sequentially and are
/// allocated proportionally across remaining line amounts using largest
/// remainders (ties follow line order). Tax is rounded half-up per line last.
/// No catalog lookup or mutable draft state is hidden in the calculator.
final class ShopTotals {
  ShopTotals._(this.lines, this.vouchers);

  /// Final immutable line snapshots.
  final List<ShopLineTotal> lines;

  /// Final immutable voucher snapshots, in application order.
  final List<ShopVoucherTotal> vouchers;

  /// Subtotal after line discounts, before vouchers.
  BeakDecimal get subtotal =>
      lines.fold(ShopMoney.zero, (sum, row) => sum + row.subtotal);

  /// Total invoice-level voucher reductions.
  BeakDecimal get discount =>
      vouchers.fold(ShopMoney.zero, (sum, row) => sum + row.discount);

  /// Final taxable net amount.
  BeakDecimal get net => subtotal - discount;

  /// Sum of rounded line taxes.
  BeakDecimal get tax =>
      lines.fold(ShopMoney.zero, (sum, row) => sum + row.tax);

  /// Final payable amount.
  BeakDecimal get total => net + tax;

  /// Validates inputs and calculates immutable, internally consistent totals.
  ///
  /// Running balances are whole units of the two-decimal amount scale, so
  /// every step is an exact integer operation.
  factory ShopTotals.calculate({
    required List<ShopLineInput> lines,
    List<ShopVoucherInput> vouchers = const [],
  }) {
    if (lines.isEmpty) {
      throw const FormatException('Add at least one invoice line.');
    }
    final ids = <String>{};
    final subtotals = <int>[];
    for (final line in lines) {
      if (!ids.add(line.id) || line.id.isEmpty || line.label.trim().isEmpty) {
        throw const FormatException(
          'Each line needs a unique identity and description.',
        );
      }
      if (line.quantity < 1) {
        throw const FormatException('Line quantities must be at least one.');
      }
      final grossNet =
          BigInt.from(line.quantity) *
          BigInt.from(ShopMoney.amount(line.unitPrice).units);
      final lineDiscount = ShopMoney.amount(line.lineDiscount).units;
      ShopMoney.percentage(line.taxRate);
      if (grossNet > BigInt.from(ShopMoney.maximum.units) ||
          BigInt.from(lineDiscount) > grossNet) {
        throw const FormatException(
          'A line discount cannot exceed its subtotal.',
        );
      }
      subtotals.add(grossNet.toInt() - lineDiscount);
    }
    final originalSubtotal = subtotals.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    if (originalSubtotal > ShopMoney.maximum.units) {
      throw const FormatException('Invoice amount is too large.');
    }
    final balances = [...subtotals];
    final applied = <ShopVoucherTotal>[];
    final voucherIds = <String>{};
    for (final voucher in vouchers) {
      if (!voucherIds.add(voucher.id)) {
        throw const FormatException('A voucher can only be applied once.');
      }
      final value = voucher.percentage
          ? ShopMoney.percentage(voucher.value)
          : ShopMoney.amount(voucher.value);
      final minimum = ShopMoney.amount(voucher.minimumSubtotal);
      final cap = switch (voucher.maximumDiscount) {
        final BeakDecimal amount => ShopMoney.amount(amount),
        null => null,
      };
      if (originalSubtotal < minimum.units) {
        throw FormatException(
          'Voucher ${voucher.code} requires a higher subtotal.',
        );
      }
      final remaining = balances.fold<int>(0, (sum, value) => sum + value);
      var discount = voucher.percentage
          ? ShopMoney.roundRatio(remaining, value.units, 10000)
          : value.units;
      if (cap != null && discount > cap.units) discount = cap.units;
      if (discount > remaining) discount = remaining;
      if (discount > 0) {
        final allocations = <int>[];
        final remainders = <BigInt>[];
        for (final balance in balances) {
          final share = BigInt.from(balance) * BigInt.from(discount);
          allocations.add((share ~/ BigInt.from(remaining)).toInt());
          remainders.add(share % BigInt.from(remaining));
        }
        final ranking = List<int>.generate(lines.length, (index) => index)
          ..sort((a, b) {
            final order = remainders[b].compareTo(remainders[a]);
            return order == 0 ? a.compareTo(b) : order;
          });
        final leftover =
            discount - allocations.fold<int>(0, (sum, value) => sum + value);
        for (var index = 0; index < leftover; index++) {
          allocations[ranking[index]]++;
        }
        for (var index = 0; index < balances.length; index++) {
          balances[index] -= allocations[index];
        }
      }
      applied.add(ShopVoucherTotal._(voucher, BeakDecimal(discount)));
    }
    return ShopTotals._(
      List.unmodifiable([
        for (var index = 0; index < lines.length; index++)
          ShopLineTotal._(
            lines[index],
            BeakDecimal(subtotals[index]),
            BeakDecimal(subtotals[index] - balances[index]),
            BeakDecimal(balances[index]),
            ShopMoney.percentOf(
              BeakDecimal(balances[index]),
              lines[index].taxRate,
            ),
          ),
      ]),
      List.unmodifiable(applied),
    );
  }
}
