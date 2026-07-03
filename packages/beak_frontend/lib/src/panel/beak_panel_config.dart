import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../actions/beak_action.dart';
import '../dashboard/beak_chart.dart';
import '../dashboard/beak_stat.dart';
import '../filters/beak_filter_widget.dart';
import 'beak_routes.dart';

/// A typed icon reference for panel navigation — a zero-cost wrapper so
/// resource declarations stay expressive (`BeakIconToken(OiIcons.package)`)
/// without leaking raw icon plumbing into Beak's config surface.
extension type const BeakIconToken(IconData icon) {}

/// One resource surfaced in the panel: a registered [BeakModel] plus its
/// navigation presentation.
final class BeakResource {
  /// Creates a panel resource for [model], shown with [icon] and [label]
  /// (defaults to the title-cased table name).
  const BeakResource({
    required this.model,
    required this.icon,
    this.label,
    this.recordActions = const [],
    this.bulkActions = const [],
    this.globalActions = const [],
    this.filters = const [],
  });

  /// The model this resource exposes.
  final BeakModel model;

  /// The sidebar icon.
  final BeakIconToken icon;

  /// The navigation label override.
  final String? label;

  /// Extra per-row actions on the list page (view/edit/delete are built
  /// in).
  final List<BeakRecordAction> recordActions;

  /// Actions over the list page's selection.
  final List<BeakBulkAction> bulkActions;

  /// Extra page-level list actions (create is built in).
  final List<BeakGlobalAction> globalActions;

  /// The list page's filter controls.
  final List<BeakFilterDef> filters;

  /// The label shown in navigation and page titles.
  String get effectiveLabel => label ?? _titleCase(model.table);

  /// The list route of this resource.
  String get route => BeakRoutes.list(model.table);

  static String _titleCase(String table) => table
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

/// Everything a Beak panel needs at startup: the resources, the backend
/// origin, and optional theming.
final class BeakPanelConfig {
  /// Creates a panel configuration.
  const BeakPanelConfig({
    required this.title,
    required this.resources,
    required this.apiBaseUrl,
    this.theme,
    this.darkTheme,
    this.dashboardStats = const [],
    this.dashboardCharts = const [],
  });

  /// The panel title, shown in the shell and the login screen.
  final String title;

  /// The resources the panel exposes, in navigation order.
  final List<BeakResource> resources;

  /// Origin of the `beak_backend` server (e.g. `http://localhost:8080`).
  final String apiBaseUrl;

  /// The light theme (defaults to `OiThemeData.light()`).
  final OiThemeData? theme;

  /// The dark theme (defaults to `OiThemeData.dark()`).
  final OiThemeData? darkTheme;

  /// The dashboard's metric cards, in order.
  final List<BeakStat> dashboardStats;

  /// The dashboard's charts, in order.
  final List<BeakChart> dashboardCharts;

  /// A registry over every resource model, in declaration order.
  BeakModelRegistry buildRegistry() {
    final registry = BeakModelRegistry();
    for (final resource in resources) {
      registry.register(resource.model);
    }
    return registry;
  }
}
