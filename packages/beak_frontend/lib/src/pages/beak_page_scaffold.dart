import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../panel/beak_panel_config.dart';

/// The shared page chrome of every generated resource page: an
/// `OiResourcePage` titled after the resource, with Beak-owned action
/// buttons (the variant defaults are suppressed — Beak's typed actions
/// replace them).
final class BeakPageScaffold extends StatelessWidget {
  /// Creates the scaffold for [resource]'s [variant] page around [child].
  const BeakPageScaffold({
    required this.resource,
    required this.variant,
    required this.child,
    this.title,
    this.actions = const [],
    this.filters,
    super.key,
  });

  /// The resource the page belongs to.
  final BeakResource resource;

  /// Which CRUD page this is.
  final OiResourcePageVariant variant;

  /// The page content.
  final Widget child;

  /// Title override (defaults to the resource label).
  final String? title;

  /// The page's action buttons.
  final List<Widget> actions;

  /// The list page's filter bar, if any.
  final Widget? filters;

  @override
  Widget build(BuildContext context) => OiResourcePage(
    label: resource.effectiveLabel,
    title: title ?? resource.effectiveLabel,
    variant: variant,
    actions: actions,
    filters: filters,
    child: child,
  );
}
