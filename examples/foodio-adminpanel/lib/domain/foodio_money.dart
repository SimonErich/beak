/// One VAT-inclusive priced line. All calculations use integer cents.
final class FoodioMoneyLine {
  /// Captures the priced quantity as one stable allocation line.
  const FoodioMoneyLine({
    required this.key,
    required this.grossCents,
    required this.taxBasisPoints,
    this.food = true,
  });

  /// Stable line identity used to resolve equal rounding remainders.
  final String key;

  /// VAT-inclusive amount in cents.
  final int grossCents;

  /// VAT percentage in basis points; 1000 means 10 percent.
  final int taxBasisPoints;

  /// Whether a food-only voucher may discount this line.
  final bool food;
}

/// Immutable allocation used by the preview, saved order and invoice.
final class FoodioLineTotal {
  /// Captures this line after discounts and VAT allocation.
  const FoodioLineTotal({
    required this.key,
    required this.grossCents,
    required this.discountCents,
    required this.taxCents,
  });

  /// Stable line identity used to resolve equal rounding remainders.
  final String key;

  /// VAT-inclusive amount in cents.
  final int grossCents;

  /// This line’s allocated share of all discounts.
  final int discountCents;

  /// This line’s reconciled VAT allocation.
  final int taxCents;

  /// Amount before VAT in cents.
  int get netCents => grossCents - taxCents;
}

/// VAT buckets round once; stable largest-remainder allocation reconciles lines.
final class FoodioTotals {
  FoodioTotals._(
    this.lines,
    this.subtotalCents,
    this.voucherDiscountCents,
    this.manualDiscountCents,
    this.taxByRate,
  );

  /// Per-line allocations in the same order as the input.
  final List<FoodioLineTotal> lines;

  /// VAT-inclusive total before any discounts.
  final int subtotalCents;

  /// Discount from the single selected voucher, after its cap.
  final int voucherDiscountCents;

  /// Separate operator adjustment applied after the voucher.
  final int manualDiscountCents;

  /// VAT cents grouped by basis-point rate.
  final Map<int, int> taxByRate;

  /// Total reductions from the original VAT-inclusive price.
  int get discountCents => voucherDiscountCents + manualDiscountCents;

  /// Final payable VAT-inclusive amount.
  int get grossCents => subtotalCents - discountCents;

  /// VAT total across all reconciled rate buckets.
  int get taxCents => taxByRate.values.fold(0, (a, b) => a + b);

  /// Amount before VAT in cents.
  int get netCents => grossCents - taxCents;

  /// One voucher applies first, followed by a separate authorized adjustment.
  factory FoodioTotals.calculate(
    List<FoodioMoneyLine> input, {
    int voucherBasisPoints = 0,
    int? voucherCapCents,
    bool voucherFoodOnly = true,
    int manualDiscountCents = 0,
  }) {
    if (input.map((line) => line.key).toSet().length != input.length ||
        input.any(
          (line) =>
              line.grossCents < 0 ||
              line.taxBasisPoints < 0 ||
              line.taxBasisPoints > 10000,
        ) ||
        voucherBasisPoints < 0 ||
        voucherBasisPoints > 10000 ||
        (voucherCapCents != null && voucherCapCents < 0) ||
        manualDiscountCents < 0) {
      throw ArgumentError(
        'Invalid price, tax rate, discount or duplicate line.',
      );
    }
    final subtotal = input.fold(0, (sum, line) => sum + line.grossCents);
    final eligible = [
      for (final line in input)
        if (!voucherFoodOnly || line.food) line,
    ];
    final eligibleGross = eligible.fold(
      0,
      (sum, line) => sum + line.grossCents,
    );
    var voucher = _round(eligibleGross * voucherBasisPoints, 10000);
    if (voucherCapCents != null && voucher > voucherCapCents) {
      voucher = voucherCapCents;
    }
    if (manualDiscountCents > subtotal - voucher) {
      throw ArgumentError('The discount exceeds the remaining order amount.');
    }
    final voucherParts = _allocate(voucher, {
      for (final line in eligible) line.key: line.grossCents,
    });
    final afterVoucher = {
      for (final line in input)
        line.key: line.grossCents - (voucherParts[line.key] ?? 0),
    };
    final manualParts = _allocate(manualDiscountCents, afterVoucher);
    final gross = {
      for (final line in input)
        line.key: afterVoucher[line.key]! - (manualParts[line.key] ?? 0),
    };
    final taxByRate = <int, int>{};
    final taxParts = <String, int>{};
    for (final rate in input.map((line) => line.taxBasisPoints).toSet()) {
      final bucket = {
        for (final line in input)
          if (line.taxBasisPoints == rate) line.key: gross[line.key]!,
      };
      final bucketGross = bucket.values.fold(0, (a, b) => a + b);
      final tax = _round(bucketGross * rate, 10000 + rate);
      taxByRate[rate] = tax;
      taxParts.addAll(_allocate(tax, bucket));
    }
    return FoodioTotals._(
      List.unmodifiable([
        for (final line in input)
          FoodioLineTotal(
            key: line.key,
            grossCents: gross[line.key]!,
            discountCents: line.grossCents - gross[line.key]!,
            taxCents: taxParts[line.key] ?? 0,
          ),
      ]),
      subtotal,
      voucher,
      manualDiscountCents,
      Map.unmodifiable(taxByRate),
    );
  }

  static int _round(int numerator, int denominator) =>
      (numerator * 2 + denominator) ~/ (denominator * 2);

  static Map<String, int> _allocate(int amount, Map<String, int> weights) {
    final total = weights.values.fold(0, (a, b) => a + b);
    if (total == 0 || amount == 0) {
      return {for (final key in weights.keys) key: 0};
    }
    final result = {
      for (final entry in weights.entries)
        entry.key: amount * entry.value ~/ total,
    };
    var remainder = amount - result.values.fold(0, (a, b) => a + b);
    final keys = weights.keys.toList()
      ..sort((a, b) {
        final difference = (amount * weights[b]! % total).compareTo(
          amount * weights[a]! % total,
        );
        return difference != 0 ? difference : a.compareTo(b);
      });
    for (final key in keys) {
      if (remainder-- <= 0) break;
      result[key] = result[key]! + 1;
    }
    return result;
  }
}
