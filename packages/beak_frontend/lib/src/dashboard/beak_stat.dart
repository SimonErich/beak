import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../data/beak_resource_repository.dart';

/// A dashboard metric: a typed aggregate over a table, rendered as a card.
final class BeakStat {
  /// Creates a stat computing [aggregate], labelled [label].
  const BeakStat({
    required this.label,
    required this.aggregate,
    this.icon,
    this.prefix = '',
    this.suffix = '',
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
}

/// Renders one [BeakStat]: fetches its aggregate through the repository
/// and shows the formatted value (an em dash while loading or on failure).
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
    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final result = await BeakResourceRepository(
          dataSource,
        ).aggregate(stat.aggregate);
        if (cancelled) {
          return;
        }
        if (result case BeakOk(value: final loaded)) {
          value.value = loaded;
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource, stat]);

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
          OiLabel.h2(_formatted(value.value)),
        ],
      ),
    );
  }

  String _formatted(num? value) {
    if (value == null) {
      return '—';
    }
    final String number = value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '${stat.prefix}$number${stat.suffix}';
  }
}
