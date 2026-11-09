import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../gabel_icons.dart';
import '../gabel_palette.dart';
import '../gabel_text.dart';
import '../tokens/gabel_dark.dart';
import '../tokens/gabel_light.dart';

/// The Gabel theme for `OiSheet`.
OiSheetThemeData gabelSheetTheme(GabelPalette p) => OiSheetThemeData(
  inset: const EdgeInsets.all(8),
  borderRadius: const BorderRadius.all(Radius.circular(14)),
  barrierColor: p.pick(GabelLight.scrim, GabelDark.scrim),
);

// --8<-- [start:gabelIconTheme]
/// The Gabel theme for every icon.
OiIconThemeData gabelIconTheme() =>
    OiIconThemeData(sources: gabelIconSources, size: 18);
// --8<-- [end:gabelIconTheme]

/// The Gabel theme for `OiAppShell`.
OiAppShellThemeData gabelAppShellTheme(GabelPalette p, GabelText text) =>
    OiAppShellThemeData(
      breadcrumbLinkStyle: text(14, 20, foreground: p.muted),
      breadcrumbSeparatorIcon: OiIcons.chevronRight,
      breadcrumbSpacing: 8,
      topBarHeight: 64,
      primaryNavigationWidth: 64,
      searchMaxWidth: 360,
      actionSpacing: 12,
      titleStyle: text(14, 20, weight: 500),
      topBarPadding: const EdgeInsets.symmetric(horizontal: 32),
      backgroundColor: p.canvas,
      borderColor: const Color(0x00000000),
    );

/// The Gabel theme for `OiNavigationRail`.
OiNavigationRailThemeData gabelNavigationRailTheme(GabelPalette p) =>
    OiNavigationRailThemeData(
      width: 64,
      itemWidth: 40,
      itemHeight: 40,
      iconSize: 20,
      itemSpacing: 4,
      itemPadding: EdgeInsets.zero,
      borderWidth: 0,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      backgroundColor: p.pick(GabelLight.railSurface, GabelDark.railSurface),
      indicatorColor: p.pick(GabelLight.railActive, GabelDark.railActive),
      hoverColor: p.pick(GabelLight.railHover, GabelDark.railHover),
      hoverIconColor: p.pick(GabelLight.railInk, GabelDark.railInk),
      selectedIconColor: p.pick(
        GabelLight.onRailActive,
        GabelDark.onRailActive,
      ),
      unselectedIconColor: p.pick(GabelLight.railInk, GabelDark.railInk),
    );

/// The Gabel theme for `OiStepper`.
OiStepperThemeData gabelStepperTheme(GabelPalette p) => OiStepperThemeData(
  indicatorBorderColor: p.border,
  indicatorBorderWidth: 1,
  connectorColor: p.lineStrong,
  stepSpacing: 20,
  detailsSpacing: 2,
);

/// The Gabel theme for `OiSidebar`.
OiSidebarThemeData gabelSidebarTheme(GabelPalette p, GabelText text) =>
    OiSidebarThemeData(
      contextBranchColor: p.lineStrong,
      headerHeight: 64,
      headerPadding: const EdgeInsets.fromLTRB(24, 16, 20, 16),
      headerTextStyle: text(16, 24, weight: 580),
      labelGap: 8,
      itemSpacing: 2,
      plainBadges: true,
      badgeTextStyle: text(12, 16, weight: 500).copyWith(color: p.muted),
      selectedIconColor: p.primary,
      selectedBorderColor: p.line,
      width: 264,
      compactWidth: 64,
      itemHeight: 36,
      iconSize: 18,
      iconWidth: 24,
      itemPadding: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
      itemRadius: const BorderRadius.all(Radius.circular(8)),
      backgroundColor: p.canvas,
      foreground: p.ink,
      iconColor: p.muted,
      selectedBackground: p.sheet,
      selectedForeground: p.ink,
      textStyle: text.body,
      selectedTextStyle: text(14, 20, weight: 580),
    );
