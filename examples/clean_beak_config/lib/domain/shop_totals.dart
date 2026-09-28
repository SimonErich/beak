/// Exact cent conversion and half-up rounding shared by server and previews.
abstract final class ShopMoney {
  /// Largest amount accepted by this demonstration, safely representable on web.
  static const maxCents = 1000000000000;

  /// Converts an entered euro amount without silently accepting extra precision.
  static int cents(double euros) {
    if (!euros.isFinite || euros < 0 || euros * 100 > maxCents) {
      throw const FormatException('Enter a non-negative monetary amount.');
    }
    final scaled = euros * 100;
    final rounded = scaled.round();
    if ((scaled - rounded).abs() > 0.000001) {
      throw const FormatException('Money supports at most two decimal places.');
    }
    return rounded;
  }

  /// Converts a 0–100 percentage with at most two decimal places to basis points.
  static int basisPoints(double percent) {
    if (!percent.isFinite || percent < 0 || percent > 100) {
      throw const FormatException('Enter a percentage between 0 and 100.');
    }
    return cents(percent);
  }

  /// Rounds a non-negative rational amount half-up, without floating-point math.
  static int roundRatio(int value, int multiplier, int divisor) =>
      ((BigInt.from(value) * BigInt.from(multiplier) +
                  BigInt.from(divisor ~/ 2)) ~/
              BigInt.from(divisor))
          .toInt();

  /// Formats a saved amount for the demonstration's euro currency.
  static String format(int cents) => '€${(cents / 100).toStringAsFixed(2)}';
}

/// A complete line price expressed in integer cents and tax basis points.
final class ShopLineInput {
  /// Creates one uniquely identified product, variant or custom line.
  const ShopLineInput({
    required this.id,
    required this.label,
    required this.quantity,
    required this.unitPriceCents,
    this.lineDiscountCents = 0,
    this.taxBasisPoints = 0,
  });

  /// Stable row identity for matching previews and saved snapshots.
  final String id;

  /// Saved line description.
  final String label;

  /// Number of whole units.
  final int quantity;

  /// Net unit price in cents.
  final int unitPriceCents;

  /// Net reduction on the whole line before invoice-level vouchers.
  final int lineDiscountCents;

  /// Exclusive tax rate, where 2000 means 20%.
  final int taxBasisPoints;
}

/// A voucher application in explicit application order.
final class ShopVoucherInput {
  /// A fixed reduction in cents, capped at the remaining net subtotal.
  const ShopVoucherInput.fixed({
    required this.id,
    required this.code,
    required int amountCents,
    this.minimumSubtotalCents = 0,
    this.maximumDiscountCents,
  }) : value = amountCents,
       percentage = false;

  /// A percentage reduction on the net subtotal remaining after prior vouchers.
  const ShopVoucherInput.percentage({
    required this.id,
    required this.code,
    required int basisPoints,
    this.minimumSubtotalCents = 0,
    this.maximumDiscountCents,
  }) : value = basisPoints,
       percentage = true;

  /// Voucher identity; duplicates within one invoice are rejected.
  final String id;

  /// Snapshot of the redemption code.
  final String code;

  /// Cents for fixed vouchers, basis points for percentage vouchers.
  final int value;

  /// Whether [value] is a percentage.
  final bool percentage;

  /// Eligibility threshold measured before all invoice-level vouchers.
  final int minimumSubtotalCents;

  /// Optional maximum discount for this application.
  final int? maximumDiscountCents;
}

/// The amount allocated to an individual line after all voucher applications.
final class ShopLineTotal {
  const ShopLineTotal._(
    this.input,
    this.subtotalCents,
    this.voucherDiscountCents,
    this.netCents,
    this.taxCents,
  );

  /// Original price and tax snapshot.
  final ShopLineInput input;

  /// Line subtotal after the line-level discount and before vouchers.
  final int subtotalCents;

  /// Proportional share of all invoice-level vouchers.
  final int voucherDiscountCents;

  /// Remaining taxable net amount.
  final int netCents;

  /// Tax rounded half-up on this line's remaining taxable amount.
  final int taxCents;

  /// Amount payable for this line.
  int get totalCents => netCents + taxCents;
}

/// A voucher definition paired with its actual capped reduction.
final class ShopVoucherTotal {
  const ShopVoucherTotal._(this.input, this.discountCents);

  /// Applied voucher definition.
  final ShopVoucherInput input;

  /// Actual reduction after capping at the remaining subtotal.
  final int discountCents;
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
  int get subtotalCents => lines.fold(0, (sum, row) => sum + row.subtotalCents);

  /// Total invoice-level voucher reductions.
  int get discountCents =>
      vouchers.fold(0, (sum, row) => sum + row.discountCents);

  /// Final taxable net amount.
  int get netCents => subtotalCents - discountCents;

  /// Sum of rounded line taxes.
  int get taxCents => lines.fold(0, (sum, row) => sum + row.taxCents);

  /// Final payable amount.
  int get totalCents => netCents + taxCents;

  /// Validates inputs and calculates immutable, internally consistent totals.
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
      if (line.quantity < 1 ||
          line.unitPriceCents < 0 ||
          line.lineDiscountCents < 0 ||
          line.taxBasisPoints < 0 ||
          line.taxBasisPoints > 10000) {
        throw const FormatException(
          'Line quantities, prices and tax rates are invalid.',
        );
      }
      final grossNet =
          BigInt.from(line.quantity) * BigInt.from(line.unitPriceCents);
      if (grossNet > BigInt.from(ShopMoney.maxCents) ||
          BigInt.from(line.lineDiscountCents) > grossNet) {
        throw const FormatException(
          'A line discount cannot exceed its subtotal.',
        );
      }
      subtotals.add(grossNet.toInt() - line.lineDiscountCents);
    }
    final originalSubtotal = subtotals.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    if (originalSubtotal > ShopMoney.maxCents) {
      throw const FormatException('Invoice amount is too large.');
    }
    final balances = [...subtotals];
    final applied = <ShopVoucherTotal>[];
    final voucherIds = <String>{};
    for (final voucher in vouchers) {
      if (!voucherIds.add(voucher.id)) {
        throw const FormatException('A voucher can only be applied once.');
      }
      if (voucher.value < 0 ||
          (voucher.percentage && voucher.value > 10000) ||
          voucher.minimumSubtotalCents < 0 ||
          (voucher.maximumDiscountCents ?? 0) < 0) {
        throw const FormatException('Voucher values are invalid.');
      }
      if (originalSubtotal < voucher.minimumSubtotalCents) {
        throw FormatException(
          'Voucher ${voucher.code} requires a higher subtotal.',
        );
      }
      final remaining = balances.fold<int>(0, (sum, value) => sum + value);
      var discount = voucher.percentage
          ? ShopMoney.roundRatio(remaining, voucher.value, 10000)
          : voucher.value;
      if (voucher.maximumDiscountCents case final int cap when discount > cap) {
        discount = cap;
      }
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
      applied.add(ShopVoucherTotal._(voucher, discount));
    }
    return ShopTotals._(
      List.unmodifiable([
        for (var index = 0; index < lines.length; index++)
          ShopLineTotal._(
            lines[index],
            subtotals[index],
            subtotals[index] - balances[index],
            balances[index],
            ShopMoney.roundRatio(
              balances[index],
              lines[index].taxBasisPoints,
              10000,
            ),
          ),
      ]),
      List.unmodifiable(applied),
    );
  }
}
