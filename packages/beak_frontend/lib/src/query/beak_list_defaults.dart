import 'beak_list_definition.dart';

/// The list presentation a panel gives every resource that does not ask for
/// its own.
///
/// These are the conventions an admin usually wants once: 25 rows a page with
/// the page scrolling, the first three filters as one-click chips, and a CSV
/// export of the listed columns. A resource that needs another shape passes its
/// own `BeakTableScreen`, which always wins.
final class BeakListDefaults {
  /// Creates list defaults.
  const BeakListDefaults({
    this.pageSize = 25,
    this.quickFilters = 3,
    this.fitRows = true,
    this.scroll = BeakListScrollMode.page,
    this.export = true,
  });

  /// Rows per page before the operator changes it.
  final int pageSize;

  /// How many filters appear as one-click chips (`0` for none).
  final int quickFilters;

  /// Whether the table fits its rows instead of using a fixed viewport.
  final bool fitRows;

  /// Which surface scrolls the rows.
  final BeakListScrollMode scroll;

  /// Whether a list exports the columns it shows.
  final bool export;
}
