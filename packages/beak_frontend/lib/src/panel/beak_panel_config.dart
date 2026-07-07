import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../actions/beak_action.dart';
import '../blocks/beak_block.dart';
import '../dashboard/beak_chart.dart';
import '../dashboard/beak_stat.dart';
import '../filters/beak_filter_widget.dart';
import '../form/beak_form_step.dart';
import 'beak_auth_config.dart';
import 'beak_maintenance_config.dart';
import 'beak_resource_view.dart';
import 'beak_routes.dart';
import 'beak_screen.dart';

/// A typed icon reference for panel navigation.
///
/// A zero-cost wrapper over [IconData] so resource declarations stay
/// expressive (`BeakIconToken(OiIcons.package)`) without leaking raw icon
/// plumbing into Beak's config surface. Wrap any obers_ui `OiIcons` value.
extension type const BeakIconToken(IconData icon) {}

/// One resource surfaced in the panel: a registered [BeakModel] plus its
/// navigation presentation and the typed actions and filters its generated
/// pages expose.
///
/// Declaring a resource is all it takes to get a full list/create/show/edit
/// CRUD surface — no per-page code. The built-in view, edit, delete and
/// create actions are always present; [recordActions], [bulkActions],
/// [globalActions] and [filters] add to them.
///
/// ```dart
/// BeakResource(
///   model: const ProductModel(),
///   icon: const BeakIconToken(OiIcons.package),
///   filters: const [
///     BeakSelectFilter(column: ProductColumns.status, label: 'Status'),
///     BeakTextFilter(column: ProductColumns.name, label: 'Name'),
///   ],
///   recordActions: const [
///     BeakRecordAction(
///       key: 'duplicate',
///       label: 'Duplicate',
///       icon: OiIcons.copy,
///       onExecute: duplicateProduct,
///     ),
///   ],
/// );
/// ```
final class BeakResource {
  /// Creates a panel resource for [model], shown with [icon] and [label]
  /// (defaults to the title-cased table name).
  const BeakResource({
    required this.model,
    required this.icon,
    this.label,
    this.section,
    this.recordActions = const [],
    this.bulkActions = const [],
    this.globalActions = const [],
    this.filters = const [],
    this.viewModes = const [BeakTableView()],
    this.detail,
    this.formSteps,
    this.formLayout,
  });

  /// The model this resource exposes.
  final BeakModel model;

  /// The sidebar icon.
  final BeakIconToken icon;

  /// The navigation label override.
  final String? label;

  /// Optional sidebar group heading this resource is filed under.
  final String? section;

  /// Extra per-row actions on the list page (view/edit/delete are built
  /// in).
  final List<BeakRecordAction> recordActions;

  /// Actions over the list page's selection.
  final List<BeakBulkAction> bulkActions;

  /// Extra page-level list actions (create is built in).
  final List<BeakGlobalAction> globalActions;

  /// The list page's filter controls.
  final List<BeakFilterDef> filters;

  /// The list page's selectable presentations; defaults to a single table
  /// view. Declaring more than one adds a view-mode switcher to the list
  /// page.
  final List<BeakResourceView> viewModes;

  /// A custom show-page layout: a record-bound [BeakBlock] tree (cards,
  /// sections, tabs, grids composed of `BeakFieldBlock`/`BeakFieldGroupBlock`/
  /// `BeakRelationBlock`) rendered inside the loaded record's scope. When
  /// `null`, the show page falls back to the generated definition-grid detail
  /// view plus the record's to-many relation managers.
  final BeakBlock? detail;

  /// When set, the create/edit form renders as a multi-step wizard over these
  /// steps instead of a single scrolling form — for long, complex entities.
  final List<BeakFormStep>? formSteps;

  /// When set, the create/edit form renders through this record-bound block
  /// layout — giving the form the same cards/tabs/columns structure as the
  /// show page (pass the same block tree to [detail] and here). Ignored when
  /// [formSteps] is set.
  final BeakBlock? formLayout;

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
///
/// This is the single declarative entry point of a Beak admin app — hand it
/// to a [BeakPanel] and the whole UI (navigation, routing, generated CRUD
/// pages, dashboard) is stood up from it. Compose it once, typically in a
/// builder so tests can vary the API origin.
///
/// ```dart
/// BeakPanelConfig buildPanelConfig({
///   String apiBaseUrl = 'http://localhost:8080',
/// }) => BeakPanelConfig(
///   title: 'Beak Admin',
///   apiBaseUrl: apiBaseUrl,
///   resources: const [
///     BeakResource(
///       model: ProductModel(),
///       icon: BeakIconToken(OiIcons.package),
///     ),
///     BeakResource(
///       model: UserModel(),
///       icon: BeakIconToken(OiIcons.users),
///     ),
///   ],
///   dashboardStats: const [
///     BeakStat(
///       label: 'Products',
///       aggregate: BeakAggregateSpec.count(table: 'products'),
///       icon: OiIcons.package,
///     ),
///   ],
///   dashboardCharts: const [
///     BeakChart(
///       title: 'Stock per product',
///       type: BeakChartType.bar,
///       query: BeakQuerySpec(table: 'products'),
///       map: stockPerProduct,
///     ),
///   ],
/// );
/// ```
final class BeakPanelConfig {
  /// Creates a panel configuration.
  const BeakPanelConfig({
    required this.title,
    required this.resources,
    required this.apiBaseUrl,
    this.pages = const [],
    this.auth,
    this.maintenance,
    this.theme,
    this.darkTheme,
    this.initialThemeMode = OiThemeMode.system,
    this.sidebarCollapsible = true,
    this.sidebarDefaultCollapsed = false,
    this.dashboardStats = const [],
    this.dashboardCharts = const [],
  });

  /// The panel title, shown in the shell and the login screen.
  final String title;

  /// The resources the panel exposes, in navigation order.
  final List<BeakResource> resources;

  /// Origin of the `beak_backend` server (e.g. `http://localhost:8080`).
  final String apiBaseUrl;

  /// Custom, non-resource screens, in navigation order.
  final List<BeakScreen> pages;

  /// Authentication routes; `null` mounts only a default `/login`.
  final BeakAuthConfig? auth;

  /// Maintenance / coming-soon routes; `null` mounts neither.
  final BeakMaintenanceConfig? maintenance;

  /// The light theme (defaults to `OiThemeData.light()`).
  final OiThemeData? theme;

  /// The dark theme (defaults to `OiThemeData.dark()`).
  final OiThemeData? darkTheme;

  /// The theme mode the panel starts in; toggled live from the shell.
  final OiThemeMode initialThemeMode;

  /// Whether the sidebar can collapse to an icon rail.
  final bool sidebarCollapsible;

  /// Whether the sidebar starts collapsed (an icon-only rail).
  final bool sidebarDefaultCollapsed;

  /// The dashboard's metric cards, in order.
  final List<BeakStat> dashboardStats;

  /// The dashboard's charts, in order.
  final List<BeakChart> dashboardCharts;

  /// Builds a [BeakModelRegistry] over every resource model, in declaration
  /// order.
  ///
  /// Called once at startup so the data layer can resolve a table name back
  /// to its model (primary-key metadata, relations). Registering the same
  /// table twice is a configuration error surfaced by the registry.
  BeakModelRegistry buildRegistry() {
    final registry = BeakModelRegistry();
    for (final resource in resources) {
      registry.register(resource.model);
    }
    return registry;
  }
}
