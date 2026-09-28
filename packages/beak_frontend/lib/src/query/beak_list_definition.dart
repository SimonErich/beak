import '../blocks/beak_block.dart';
import '../filters/beak_filter_widget.dart';
import '../presentation/beak_record_template.dart';
import '../presentation/beak_action_presentation.dart';
import 'beak_query_controller.dart';
import 'beak_saved_views.dart';
import 'beak_list_export.dart';

/// Which surface owns the list's vertical scrolling.
enum BeakListScrollMode {
  /// A bounded row viewport with pagination visible below it (default).
  table,

  /// Intrinsic row height; the page body scrolls through rows and pagination.
  page,
}

/// One declarative list and all the surfaces sharing its query.
final class BeakListDefinition {
  /// Keeps ordinary table defaults when a presentation is omitted.
  const BeakListDefinition({
    this.presets = const [],
    this.columns = const [],
    this.filters = const [],
    this.quickFilters = const [],
    this.quickFilterLabels = const {},
    this.filterSheetWidth = 440,
    this.filterDescription,
    this.advancedFilterDescription,
    this.advancedFilterColumns = 1,
    this.recordNoun = 'records',
    this.header,
    this.collapsedHeader,
    this.initialPreset,
    this.persistQueryInUrl = true,
    this.showPresetCounts = true,
    this.showSearch = true,
    this.searchPlaceholder,
    this.title,
    this.subtitle,
    this.subtitleBuilder,
    this.pageSize = 15,
    this.showHeaderToggle = false,
    this.headerInitiallyVisible = true,
    this.savedViews,
    this.rowActions,
    this.bulkModelActions = const [],
    this.bulkActions,
    this.createLabel,
    this.export,
    this.showTableStatusBar = false,
    this.fitTableToRows = false,
    this.scrollMode = BeakListScrollMode.table,
    this.floatingBulkActions = false,
    this.pageSizeOptions = const [15, 25, 50, 100],
  });

  /// Shared model commands offered for the selected rows, each with its own receipt.
  final List<String> bulkModelActions;

  /// Ordered presentation of resource/model selection commands and `export`.
  /// Model commands named here are automatically included; no duplicate list is
  /// required in [bulkModelActions]. Null preserves the conventional actions.
  final List<BeakActionPresentation>? bulkActions;

  /// Explicit action placement/order; null keeps generated actions in overflow.
  final List<BeakActionPresentation>? rowActions;

  /// Optional server-authorized export of the active query.
  final BeakListExport? export;

  /// Label for the conventional create action.
  final String? createLabel;

  /// Sizes short result pages to their rows, preserving scrolling when taller.
  final bool fitTableToRows;

  /// Scroll ownership; page mode sizes the table to its loaded rows.
  final BeakListScrollMode scrollMode;

  /// Places selection actions at the page bottom, leaving the rows stationary.
  final bool floatingBulkActions;

  /// Shows the optional table status count above pagination.
  final bool showTableStatusBar;

  /// Page lengths offered alongside the current bookmarked length.
  final List<int> pageSizeOptions;

  /// Optional model-backed shared views using normal resource permissions.
  final BeakSavedViewStore? savedViews;

  /// Named, counted views over one resource.
  final List<BeakQueryPreset> presets;

  /// Reusable typed cell presentations.
  final List<BeakTableColumn> columns;

  /// Filter controls in the staged drawer; empty inherits resource filters.
  final List<BeakFilterDef> filters;

  /// Width of the staged filter sheet, clamped to the available viewport.
  final double filterSheetWidth;

  /// Optional guidance below the filter sheet title.
  final String? filterDescription;

  /// Optional explanation beside the collapsed advanced-filter group.
  final String? advancedFilterDescription;

  /// Number of columns in the expanded advanced-filter group.
  final int advancedFilterColumns;

  /// Plural noun used for result counts and selected-record actions.
  final String recordNoun;

  /// Frequently used filters exposed as compact buttons beside search.
  final List<BeakFilterDef> quickFilters;

  /// Optional compact toolbar labels, leaving full editor labels unchanged.
  final Map<BeakFilterDef, String> quickFilterLabels;

  /// Optional overview consuming the surrounding query scope.
  final BeakBlock? header;

  /// Compact overview shown when the full header is hidden, sharing its query scope.
  final BeakBlock? collapsedHeader;

  /// Default selected preset before applying a bookmark or saved view.
  final String? initialPreset;

  /// Includes query state in the current route and restores browser history.
  final bool persistQueryInUrl;

  /// Fetches authoritative counts for each permanent-scope/preset combination.
  final bool showPresetCounts;

  /// Shows generated-field search.
  final bool showSearch;

  /// Explains the fields searched by this list; null uses the standard prompt.
  final String? searchPlaceholder;

  /// Optional page title override.
  final String? title;

  /// Explanatory text below the page title.
  final String? subtitle;

  /// Formats framework-owned preset counts; missing counts are loading/unavailable.
  /// This is a presentation callback, not a data-fetch or state callback.
  final String Function(Map<String, int> counts)? subtitleBuilder;

  /// Initial page length before a bookmarked or saved choice is applied.
  final int pageSize;

  /// Offers a chart/overview visibility toggle without changing the query.
  final bool showHeaderToggle;

  /// Initial visibility of the optional overview.
  final bool headerInitiallyVisible;
}
