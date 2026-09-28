import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../panel/beak_panel_config.dart';
import '../panel/beak_back_button.dart';
import '../panel/beak_shell_page_scope.dart';

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
    this.surface = true,
    this.heading,
    this.showBack = true,
    this.padding,
    this.gap,
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

  /// Adds a shared card around content that does not declare its own surfaces.
  /// Configured form layouts supply their own cards and disable this wrapper.
  final bool surface;

  /// Optional live record identity rendered in place of the plain heading.
  final Widget? heading;

  /// Whether an independent Back control is displayed alongside page actions.
  final bool showBack;

  /// Insets and region spacing for pages declaring their own card surfaces.
  final EdgeInsetsGeometry? padding;

  /// Space between page heading and body.
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final breadcrumbs =
        variant == OiResourcePageVariant.list ||
            title == null ||
            BeakShellPageScope.hasBreadcrumbs(context)
        ? null
        : [
            OiBreadcrumbItem(
              label: resource.effectiveLabel,
              onTap: () => context.go(
                BeakBackButton.destination(
                  GoRouterState.of(context).uri,
                  resource.route,
                ),
              ),
            ),
            OiBreadcrumbItem(label: title!),
          ];
    final pageActions = [
      if (showBack && variant != OiResourcePageVariant.list)
        BeakBackButton(fallback: resource.route),
      ...actions,
    ];
    if (!surface) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final pageHeading = OiPageHeader(
            title: title ?? resource.effectiveLabel,
            titleVariant: OiLabelVariant.h1,
            titleContent: heading,
            breadcrumbs: breadcrumbs,
            actions: pageActions,
            padding: EdgeInsets.zero,
          );
          final pagePadding =
              padding ??
              const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
          final contentWidth =
              constraints.maxWidth -
              pagePadding.resolve(Directionality.of(context)).horizontal;
          final intrinsic = child is OiPageLayout
              ? child as OiPageLayout
              : null;
          final scrollHeading =
              intrinsic != null &&
              intrinsic.scrollable &&
              intrinsic.scrollHeaderWhenCompact &&
              contentWidth < intrinsic.collapseBreakpoint.minWidth;
          return OiPageLayout(
            padding: pagePadding,
            gap: gap ?? 16,
            header: scrollHeading ? null : pageHeading,
            child: scrollHeading
                ? intrinsic.prependHeader(pageHeading, headingGap: gap ?? 16)
                : child,
          );
        },
      );
    }
    final isForm =
        variant == OiResourcePageVariant.create ||
        variant == OiResourcePageVariant.edit;
    return OiResourcePage(
      label: resource.effectiveLabel,
      title: title ?? resource.effectiveLabel,
      variant: variant,
      breadcrumbs: breadcrumbs,
      actions: pageActions,
      filters: filters,
      wrapInCard: !isForm,
      // A form owns its scroll view. OiCard's shrink-wrapping Column removes
      // the vertical bound, making long create/edit forms unable to scroll.
      child: isForm
          ? OiSurface(
              color: context.components.card?.backgroundColor,
              border: context.decoration.defaultBorder,
              borderRadius:
                  context.components.card?.borderRadius ??
                  BorderRadius.circular(8),
              padding: const EdgeInsets.all(16),
              child: child,
            )
          : child,
    );
  }
}
