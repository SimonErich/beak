import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'tax_rate.beak.dart';

/// A configurable exclusive tax rate; this example is not a tax filing system.
@Resource()
final class TaxRate extends BeakSchema {
  /// Administrator-facing rate label.
  @Display()
  @Column(searchable: true)
  late final String name;

  /// Percentage with exactly two decimal places, so 20.00 means 20 percent.
  @Column(
    suffix: '%',
    semantic: BeakSemantic.exactDecimal(scale: 2),
    rules: [BeakMin(0), BeakMax(100)],
  )
  late final BeakDecimal ratePercent;

  /// Whether this rate is offered for new sales.
  late final bool active;
}
