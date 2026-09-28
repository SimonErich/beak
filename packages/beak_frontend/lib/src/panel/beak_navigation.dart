import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';

import '../query/beak_query_controller.dart';
import 'beak_routes.dart';

/// A resource or custom-page destination within a workspace section.
final class BeakNavigationItem {
  /// A generated resource list, optionally selecting one declared preset.
  const BeakNavigationItem.resource(
    this.model, {
    this.label,
    this.icon,
    this.preset,
    this.showCount = false,
    this.recordLabelMonospace = false,
  }) : path = null;

  /// A custom screen registered with the panel.
  const BeakNavigationItem.page(
    this.path, {
    required this.label,
    required this.icon,
  }) : model = null,
       preset = null,
       showCount = false,
       recordLabelMonospace = false;

  /// Model owning a generated route.
  final BeakModel? model;

  /// Custom registered route.
  final String? path;

  /// Defaults to the resource's navigation label.
  final String? label;

  /// Defaults to the resource icon.
  final IconData? icon;

  /// Named list preset; its filter remains declared in the list definition.
  final String? preset;

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
      return BeakQueryController.readUri(current)?.preset == preset;
    } on BeakConfigurationException {
      return false;
    }
  }

  /// Navigable local URI including a stable serialized preset selection.
  String get route {
    final base = path ?? BeakRoutes.list(model!.table);
    if (preset == null) return base;
    return Uri(
      path: base,
      queryParameters: {
        'list': base64Url.encode(
          utf8.encode(jsonEncode(BeakQueryState(preset: preset).toJson())),
        ),
      },
    ).toString();
  }
}

/// A primary rail destination and its contextual resource navigation.
final class BeakNavigationSection {
  /// The first visible item is the section's landing destination.
  const BeakNavigationSection({
    required this.key,
    required this.label,
    required this.icon,
    required this.items,
    this.bottom = false,
  });

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
