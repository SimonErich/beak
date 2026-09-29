import 'package:meta/meta.dart';

import '../blocks/beak_block.dart';
import 'beak_destination.dart';
import 'beak_panel_config.dart';

/// A custom, non-resource panel screen: a route, its navigation entry, and
/// a declarative [BeakBlock] body.
///
/// Where a [BeakResource] yields generated CRUD pages, a [BeakScreen] is any
/// free-form screen — a dashboard, a profile, an invoice, a pricing table —
/// composed entirely from blocks. Register screens on
/// [BeakPanelConfig.pages]; each becomes a route and (unless [showInNav] is
/// false) a sidebar entry.
///
/// ```dart
/// const BeakScreen(
///   path: '/analytics',
///   title: 'Analytics',
///   icon: BeakIconToken(OiIcons.chartLine),
///   navigationGroup: 'Insights',
///   body: BeakGridBlock(columns: 12, children: [...]),
/// );
/// ```
@immutable
class BeakScreen implements BeakDestination {
  // --8<-- [start:BeakScreen]
  /// Creates a custom screen routed at [path].
  const BeakScreen({
    required this.path,
    required this.title,
    required this.icon,
    required this.body,
    this.navigationTitle,
    this.navigationGroup,
    this.showInNav = true,
    this.framed = true,
  });
  // --8<-- [end:BeakScreen]

  /// The route this screen is mounted at (e.g. `'/analytics'`).
  final String path;

  /// The screen title, shown in the framed header and used as the sidebar
  /// title fallback.
  final String title;

  /// The sidebar icon.
  final BeakIconToken icon;

  /// The declarative screen content.
  final BeakBlock body;

  /// Sidebar title override; defaults to [title].
  final String? navigationTitle;

  /// Optional sidebar group heading this screen is filed under.
  final String? navigationGroup;

  /// Whether the screen appears in the sidebar. Set false for detail pages
  /// reached only by navigation (e.g. an invoice document).
  final bool showInNav;

  /// Whether to provide the standard page header, gutters and scrolling.
  /// The frame does not add a card or background behind the body: card,
  /// chart and table blocks own their surfaces. Wrap the body in a
  /// [BeakCardBlock] to deliberately place it on one shared surface.
  /// Set false for full-bleed screens like a calendar or kanban board.
  final bool framed;

  /// The title shown in navigation.
  String get effectiveNavigationTitle => navigationTitle ?? title;

  @override
  String get location => path;
}
