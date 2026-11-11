import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../gabel_palette.dart';
import '../gabel_text.dart';
import '../tokens/gabel_dark.dart';
import '../tokens/gabel_light.dart';

/// The Gabel theme for `OiCard`.
OiCardThemeData gabelCardTheme(GabelPalette p) => OiCardThemeData(
  headerAlignment: CrossAxisAlignment.start,
  subtitleGap: 2,
  borderRadius: const BorderRadius.all(Radius.circular(14)),
  padding: const EdgeInsets.all(24),
  backgroundColor: p.sheet,
  borderColor: const Color(0x00000000),
  borderWidth: 0,
  shadow: [
    BoxShadow(
      color: p.dark ? GabelDark.line : const Color(0x0E1D1E29),
      spreadRadius: 1,
    ),
    const BoxShadow(
      color: Color(0x0A1D1E29),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    const BoxShadow(
      color: Color(0x121D1E29),
      offset: Offset(0, 3),
      blurRadius: 8,
      spreadRadius: -4,
    ),
  ],
);

/// The Gabel theme for `OiTable`.
OiTableThemeData gabelTableTheme(GabelPalette p, GabelText text) =>
    OiTableThemeData(
      rowBorderRadius: const BorderRadius.all(Radius.circular(4)),
      headerHeight: 40,
      rowHeight: 56,
      headerBackground: p.sheet,
      borderColor: p.line,
      selectedBackground: p.primarySoft,
      hoverBackground: p.well,
      headerTextStyle: text(
        12,
        16,
        weight: 500,
        tracking: .12,
        foreground: p.muted,
      ),
      cellTextStyle: text.body,
      cellPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );

/// The Gabel theme for `OiCapacity`.
OiCapacityThemeData gabelCapacityTheme(GabelPalette p, GabelText text) =>
    OiCapacityThemeData(
      warningGap: 2,
      columnGap: 12,
      trackRadius: 2,
      stripeColor: p.lineStrong,
      labelStyle: text.tabular(text.body),
      valueStyle: text.tabular(text.body),
      valueWidth: 68,
      warningIcon: OiIcons.triangleAlert,
      alignWarningWithTrack: true,
    );

/// The Gabel theme for `OiBulkBar`.
OiBulkBarThemeData gabelBulkBarTheme(GabelText text) => OiBulkBarThemeData(
  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
  borderRadius: const BorderRadius.all(Radius.circular(10)),
  labelStyle: text(14, 20, weight: 500, foreground: GabelLight.onInverse),
  compactSeparator: true,
  actionStyle: OiButtonVariantStyle(
    background: GabelLight.onInverse.withValues(alpha: .12),
    foreground: GabelLight.onInverse,
    backgroundHover: GabelLight.onInverse.withValues(alpha: .18),
    backgroundPressed: GabelLight.onInverse.withValues(alpha: .24),
  ),
  destructiveActionStyle: OiButtonVariantStyle(
    background: GabelLight.onInverse.withValues(alpha: .12),
    foreground: GabelDark.dangerInk,
    backgroundHover: GabelLight.onInverse.withValues(alpha: .18),
    backgroundPressed: GabelLight.onInverse.withValues(alpha: .24),
  ),
);

/// The Gabel theme for `OiActionBar`.
OiActionBarThemeData gabelActionBarTheme() => const OiActionBarThemeData(
  menuMinWidth: 232,
  menuIconGap: 10,
  menuRadius: BorderRadius.all(Radius.circular(10)),
  menuItemRadius: BorderRadius.all(Radius.circular(8)),
  menuPadding: EdgeInsets.all(4),
  menuItemPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
);

/// The Gabel theme for `OiPagination`.
OiPaginationThemeData gabelPaginationTheme(GabelPalette p, GabelText text) =>
    OiPaginationThemeData(
      distributed: true,
      showFirstLast: false,
      siblingCount: 2,
      activeBackground: p.primarySoft,
      activeForeground: p.primary,
      buttonRadius: const BorderRadius.all(Radius.circular(8)),
      buttonSize: 32,
      buttonSpacing: 2,
      perPageWidth: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      labelStyle: text.tabular(text.body.copyWith(color: p.muted)),
      pageStyle: text.tabular(text.body),
      activePageStyle: text.tabular(text(14, 20, weight: 500)),
    );
