import 'package:meta/meta.dart';

import '../blocks/beak_block.dart';
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
///   section: 'Insights',
///   body: BeakGridBlock(columns: 12, children: [...]),
/// );
/// ```
@immutable
class BeakScreen {
  /// Creates a custom screen routed at [path].
  const BeakScreen({
    required this.path,
    required this.title,
    required this.icon,
    required this.body,
    this.label,
    this.section,
    this.showInNav = true,
    this.framed = true,
  });

  /// The route this screen is mounted at (e.g. `'/analytics'`).
  final String path;

  /// The screen title, shown in the framed header and used as the nav label
  /// fallback.
  final String title;

  /// The sidebar icon.
  final BeakIconToken icon;

  /// The declarative screen content.
  final BeakBlock body;

  /// Navigation label override; defaults to [title].
  final String? label;

  /// Optional sidebar group heading this screen is filed under.
  final String? section;

  /// Whether the screen appears in the sidebar. Set false for detail pages
  /// reached only by navigation (e.g. an invoice document).
  final bool showInNav;

  /// Whether to provide the standard page header, gutters and scrolling.
  /// The frame does not add a card or background behind the body: card,
  /// chart and table blocks own their surfaces. Wrap the body in a
  /// [BeakCardBlock] to deliberately place it on one shared surface.
  /// Set false for full-bleed screens like a calendar or kanban board.
  final bool framed;

  /// The label shown in navigation and the page header.
  String get effectiveLabel => label ?? title;
}
