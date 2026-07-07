import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../dashboard/beak_chart.dart';
import '../table/beak_table_action.dart';

part 'beak_accordion_block.dart';
part 'beak_breadcrumbs_block.dart';
part 'beak_calendar_block.dart';
part 'beak_card_block.dart';
part 'beak_chart_block.dart';
part 'beak_chat_block.dart';
part 'beak_column_block.dart';
part 'beak_divider_block.dart';
part 'beak_faq_block.dart';
part 'beak_file_manager_block.dart';
part 'beak_grid_block.dart';
part 'beak_image_block.dart';
part 'beak_inbox_block.dart';
part 'beak_invoice_block.dart';
part 'beak_kanban_block.dart';
part 'beak_kpi_block.dart';
part 'beak_markdown_block.dart';
part 'beak_masonry_block.dart';
part 'beak_metric_block.dart';
part 'beak_pricing_block.dart';
part 'beak_profile_block.dart';
part 'beak_row_block.dart';
part 'beak_section_block.dart';
part 'beak_spacer_block.dart';
part 'beak_table_block.dart';
part 'beak_tabs_block.dart';
part 'beak_text_block.dart';
part 'beak_carousel_block.dart';
part 'beak_map_block.dart';
part 'beak_radial_slider_block.dart';
part 'beak_three_pane_block.dart';
part 'beak_widget_block.dart';
part 'beak_wizard_block.dart';

/// A declarative, composable content node — the building block of every
/// non-CRUD Beak surface.
///
/// One sealed union drives three consumers with the same descriptors: a
/// custom page's body, a resource's alternate view mode, and an overlay's
/// content. `BeakBlockHost` renders the union exhaustively onto obers_ui
/// widgets, so a new block type is a compile error until every renderer
/// handles it.
///
/// Blocks are pure `const` configuration — no widget code, no callbacks
/// except where an interaction is the feature (and [BeakWidgetBlock], the
/// documented raw-widget escape hatch).
///
/// ```dart
/// const body = BeakColumnBlock(
///   children: [
///     BeakTextBlock('Welcome back', variant: BeakTextVariant.h1),
///     BeakGridBlock(
///       columns: 12,
///       children: [
///         BeakCardBlock(
///           span: BeakSpan(columns: 6),
///           child: BeakTextBlock('Half width'),
///         ),
///         BeakCardBlock(
///           span: BeakSpan(columns: 6),
///           child: BeakTextBlock('Other half'),
///         ),
///       ],
///     ),
///   ],
/// );
/// ```
@immutable
sealed class BeakBlock {
  /// Creates a block, optionally sized by [span] inside grid parents.
  const BeakBlock({this.span});

  /// How many grid tracks this block occupies when it is a direct child
  /// of a [BeakGridBlock]; ignored elsewhere.
  final BeakSpan? span;
}

/// Grid placement of a block inside a [BeakGridBlock].
@immutable
final class BeakSpan {
  /// Creates a span covering [columns] × [rows] grid tracks.
  const BeakSpan({this.columns = 1, this.rows = 1})
    : assert(columns >= 1, 'columns must be >= 1'),
      assert(rows >= 1, 'rows must be >= 1');

  /// Number of grid columns covered.
  final int columns;

  /// Number of grid rows covered.
  final int rows;
}
