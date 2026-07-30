import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../shared/enums.dart';

part 'purchase_source.beak.dart';

/// The purchase-sources resource — acquisition-channel breakdown.
@Resource()
final class PurchaseSource extends BeakSchema {
  /// The acquisition channel.
  @Column(filterable: true, defaultValue: PurchaseChannel.direct)
  @Badges({
    PurchaseChannel.direct: BeakColor.primary,
    PurchaseChannel.social: BeakColor.info,
    PurchaseChannel.email: BeakColor.success,
    PurchaseChannel.affiliate: BeakColor.warning,
    PurchaseChannel.search: BeakColor.secondary,
  })
  late final PurchaseChannel? source;

  /// Human-readable channel label.
  @Display()
  @Column(rules: [BeakMaxLength(40)])
  late final String label;

  /// Revenue from this channel.
  @Column(sortable: true, prefix: r'$')
  late final double? total;

  /// Order count from this channel.
  @Column(label: 'Orders', sortable: true, min: 0)
  late final int? count;

  /// Share of total, 0..100.
  @Column(label: 'Share', sortable: true, suffix: '%')
  late final double? percent;

  /// Chart swatch color.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakHexColor? color;
}
