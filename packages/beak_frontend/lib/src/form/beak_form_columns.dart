import 'package:beak_core/beak_core.dart';

import '../blocks/beak_block.dart';

/// Collects, in reading order, every model column a form [layout] addresses
/// through a `BeakFieldBlock` or `BeakFieldGroupBlock` — walking the layout's
/// containers (columns, rows, grids, cards, sections, tabs, accordions,
/// masonry, three-pane, wizard steps).
///
/// A layout-driven form registers exactly these columns, so the layout is the
/// single source of truth for both the structure and the field set (mirroring
/// how sections subset a plain form's fields).
List<BeakColumn> beakFormColumnsOf(BeakBlock layout) {
  final columns = <BeakColumn>[];
  void walk(BeakBlock block) {
    switch (block) {
      case BeakFieldBlock(:final column):
        columns.add(column);
      case BeakFieldGroupBlock(columns: final grouped):
        columns.addAll(grouped);
      case BeakColumnBlock(:final children) ||
          BeakRowBlock(:final children) ||
          BeakGridBlock(:final children) ||
          BeakMasonryBlock(:final children):
        children.forEach(walk);
      case BeakCardBlock(:final child, :final footer):
        walk(child);
        if (footer != null) {
          walk(footer);
        }
      case BeakSectionBlock(:final child):
        walk(child);
      case BeakTabsBlock(:final tabs):
        for (final tab in tabs) {
          walk(tab.content);
        }
      case BeakAccordionBlock(:final items):
        for (final item in items) {
          walk(item.content);
        }
      case BeakThreePaneBlock(:final left, :final middle, :final right):
        walk(left);
        walk(middle);
        if (right != null) {
          walk(right);
        }
      case BeakWizardBlock(:final steps):
        for (final step in steps) {
          walk(step.body);
        }
      default:
        break;
    }
  }

  walk(layout);
  return columns;
}
