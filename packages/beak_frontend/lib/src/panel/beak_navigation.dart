import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';

import '../query/beak_query_controller.dart';
import 'beak_routes.dart';
import 'beak_screen.dart';

/// A resource or custom-screen destination within a workspace section.
final class BeakNavigationItem {
  /// A generated resource list, optionally selecting one declared preset.
  ///
  /// [preset] is one of the presets declared in the resource's
  /// [BeakListDefinition.presets], referenced by the object itself.
  // --8<-- [start:BeakNavigationItemResource]
  const BeakNavigationItem.resource(
    this.model, {
    String? label,
    IconData? icon,
    this.preset,
    this.showCount = false,
    this.recordLabelMonospace = false,
  }) : screen = null,
       _label = label,
       _icon = icon;
  // --8<-- [end:BeakNavigationItemResource]

  /// A custom [BeakScreen] registered with the panel.
  ///
  /// The label and icon default to the screen's own navigation title and icon.
  // --8<-- [start:BeakNavigationItemScreen]
  const BeakNavigationItem.screen(this.screen, {String? label, IconData? icon})
    : model = null,
      preset = null,
      showCount = false,
      recordLabelMonospace = false,
      _label = label,
      _icon = icon;
  // --8<-- [end:BeakNavigationItemScreen]

  /// Model owning a generated route.
  final BeakModel? model;

  /// Custom screen registered with the panel.
  final BeakScreen? screen;

  final String? _label;

  final IconData? _icon;

  /// Defaults to the resource's navigation label, or the screen's.
  String? get label => _label ?? screen?.effectiveNavigationTitle;

  /// Defaults to the resource icon, or the screen's.
  IconData? get icon => _icon ?? screen?.icon.icon;

  /// Named list preset; its filter remains declared in the list definition.
  final BeakQueryPreset? preset;

  /// Formats this resource’s current-record label with the code text role.
  final bool recordLabelMonospace;

  /// Shows an authorized live count for this destination's base query and preset.
  /// Missing/loading/failed counts remain unavailable rather than becoming zero.
  final bool showCount;

  /// Whether this destination matches the active resource/preset bookmark.
  bool matches(Uri current) {
    if (Uri.parse(route).path != current.path) return false;
    if (preset == null) return true;
    try {
      return BeakQueryController.readUri(current)?.preset == preset?.key;
    } on BeakConfigurationException {
      return false;
    }
  }

  /// Navigable local URI including a stable serialized preset selection.
  String get route {
    final base = screen?.path ?? BeakRoutes.list(model!.table);
    final chosen = preset;
    if (chosen == null) return base;
    return Uri(
      path: base,
      queryParameters: {
        'list': base64Url.encode(
          utf8.encode(jsonEncode(BeakQueryState(preset: chosen.key).toJson())),
        ),
      },
    ).toString();
  }
}

/// A primary rail destination and its contextual resource navigation.
final class BeakNavigationSection {
  /// The first visible item is the section's landing destination.
  // --8<-- [start:BeakNavigationSection]
  const BeakNavigationSection({
    required this.key,
    required this.label,
    required this.icon,
    required this.items,
    this.bottom = false,
  });
  // --8<-- [end:BeakNavigationSection]

  /// Stable presentation identity.
  final String key;

  /// Accessible rail label.
  final String label;

  /// Rail icon.
  final IconData icon;

  /// Anchors this rail destination below the primary workspace links.
  final bool bottom;

  /// Contextual destinations in display order.
  final List<BeakNavigationItem> items;
}

/// Optional two-level navigation; ordinary resource navigation stays automatic.
final class BeakNavigation {
  /// Adds a primary rail and selects contextual items from the active route.
  // --8<-- [start:BeakNavigation]
  const BeakNavigation({
    required this.sections,
    this.leading,
    this.footer,
    this.headerBuilder,
    this.userMenu,
    this.searchPlaceholder,
    this.searchShortcut = const ['meta', 'K'],
    this.showCreateAction = true,
    this.showThemeToggle = true,
    this.showCurrentRecord = true,
    this.currentRecordBranch = false,
    this.searchInHeader = true,
  });
  // --8<-- [end:BeakNavigation]

  /// Workspace sections, filtered through the same resource permissions.
  final List<BeakNavigationSection> sections;

  /// Brand widget in the primary rail.
  final Widget? leading;

  /// Shared contextual navigation footer.
  final Widget? footer;

  /// Replaces the contextual heading with an application workspace header.
  final Widget Function(BuildContext context, String section)? headerBuilder;

  /// Profile or account menu placed after the shared header actions.
  final Widget? userMenu;

  /// Command search hint; the same shared search still handles activation.
  final String? searchPlaceholder;

  /// Visible logical shortcut keys beside the shared command-search hint.
  final List<String> searchShortcut;

  /// Automatically offers creation for the first creatable workspace resource.
  /// The resource's current visibility and creation permissions are respected.
  final bool showCreateAction;

  /// Whether the shared theme switch is included in the top bar.
  final bool showThemeToggle;

  /// Shows a full command-search field in the shell header.
  final bool searchInHeader;

  /// Presents the current record as a contextual branch without a repeated icon.
  final bool currentRecordBranch;

  /// Includes the loaded current record under its resource when applicable.
  final bool showCurrentRecord;
}
