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

  /// Percentage with up to two decimal places.
  @Column(suffix: '%', rules: [BeakMin(0), BeakMax(100)])
  late final double ratePercent;

  /// Whether this rate is offered for new sales.
  late final bool active;
}
