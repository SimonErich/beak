import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../data/beak_resource_repository.dart';
import '../data/beak_data_changes.dart';
import '../formatting/beak_formatting.dart';
import '../localization/beak_localizations.dart';

/// A dashboard metric: a typed aggregate over a table, rendered as a card.
///
/// List these on [BeakPanelConfig.dashboardStats]. The [aggregate] runs
/// through the repository and its result is shown with [prefix]/[suffix]
/// around the formatted number.
///
/// ```dart
/// const BeakStat(
///   label: 'Products',
///   aggregate: BeakAggregateSpec.count(table: 'products'),
///   icon: OiIcons.package,
/// );
///
/// // A currency total: sum a column and prefix the symbol.
/// BeakStat(
///   label: 'Catalog value',
///   aggregate: BeakAggregateSpec.sum(
///     table: 'products',
///     column: ProductColumns.price,
///   ),
///   icon: OiIcons.euro,
///   prefix: '€',
/// );
/// ```
final class BeakStat {
  /// Creates a stat computing [aggregate], labelled [label].
  const BeakStat({
    required this.label,
    required this.aggregate,
    this.icon,
    this.prefix = '',
    this.suffix = '',
    this.visibleWhen,
  });

  /// The card label.
  final String label;

  /// The aggregate the card displays.
  final BeakAggregateSpec aggregate;

  /// The card icon, if any.
  final IconData? icon;

  /// Text rendered before the value (e.g. `€`).
  final String prefix;

  /// Text rendered after the value (e.g. ` items`).
  final String suffix;

  /// Whether the dashboard may mount this stat and load its aggregate.
  ///
  /// Evaluated whenever the dashboard rebuilds, including committed identity
  /// changes in a Beak panel. Omit to show the stat unconditionally. This is
  /// presentation configuration; the backend must still authorize requests.
  final bool Function()? visibleWhen;

  /// Whether the stat is currently visible.
  bool get isVisible => visibleWhen?.call() ?? true;
}

/// Renders one [BeakStat]: fetches its aggregate through a
/// [BeakResourceRepository] and shows the formatted value.
///
/// Loading and errors are explicit, failed requests can be retried, and writes
/// refresh affected metrics automatically. Numbers use the panel display policy.
class BeakStatCard extends HookWidget {
  /// Creates the card for [stat] over [dataSource].
  const BeakStatCard({required this.stat, required this.dataSource, super.key});

  /// The stat on display.
  final BeakStat stat;

  /// The source the aggregate runs against.
  final BeakDataSource dataSource;

  @override
  Widget build(BuildContext context) {
    final value = useState<num?>(null);
    final loading = useState(true);
    final error = useState<BeakException?>(null);
    final attempt = useState(0);
    final revision = useBeakDataRevision(
      dataSource,
      table: stat.aggregate.table,
    );
    final strings = BeakLocalizations.of(context);
    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final result = await BeakResourceRepository(
          dataSource,
        ).aggregate(stat.aggregate);
        if (cancelled) {
          return;
        }
        loading.value = false;
        if (result case BeakOk(value: final loaded)) {
          value.value = loaded;
          error.value = null;
        } else if (result case BeakErr(error: final failure)) {
          error.value = failure;
        }
      }

      loading.value = true;
      load();
      return () => cancelled = true;
    }, [dataSource, stat, revision, attempt.value]);

    return OiCard(
      child: OiColumn(
        breakpoint: context.breakpoint,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OiRow(
            breakpoint: context.breakpoint,
            children: [
              if (stat.icon case final IconData icon)
                OiIcon(icon: icon, label: stat.label),
              Expanded(child: OiLabel.small(stat.label)),
            ],
          ),
          if (loading.value)
            OiProgress.linear(indeterminate: true, label: strings.loading)
          else if (error.value case final BeakException failure) ...[
            OiLabel.small(strings.errorMessage(failure)),
            OiButton.ghost(label: strings.retry, onTap: () => attempt.value++),
          ] else
            OiLabel.h2(
              _formatted(value.value, BeakFormatting.maybeOf(context)),
            ),
        ],
      ),
    );
  }

  String _formatted(num? value, BeakFormatting? formatting) {
    if (value == null) {
      return '—';
    }
    final String number =
        formatting?.number(value) ??
        (value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2));
    return '${stat.prefix}$number${stat.suffix}';
  }
}
