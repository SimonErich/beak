import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../gabel_palette.dart';
import '../gabel_text.dart';
import '../tokens/gabel_dark.dart';
import '../tokens/gabel_light.dart';

// --8<-- [start:gabelChartTheme]
/// The Gabel theme for the chart widgets.
OiChartThemeData gabelChartTheme(GabelPalette p, GabelText text) =>
    OiChartThemeData(
      grid: OiChartGridTheme(
        color: p.line,
        width: 1,
        dashPattern: const [1, 1],
      ),
      centerValueStyle: text(28, 32, weight: 560),
      legend: OiChartLegendTheme(
        iconSize: 8,
        valueIconSize: 10,
        markerGap: 6,
        valueLabelStyle: text.body,
        valueStyle: text.tabular(text(14, 20, weight: 500)),
      ),
      axis: OiChartAxisTheme(
        labelGap: 8,
        labelStyle: text(12, 16, weight: 500, tracking: .12),
        labelColor: p.muted,
      ),
      density: const OiChartDensityTheme(
        padding: EdgeInsets.fromLTRB(40, 8, 0, 38),
        radialInset: 7,
        barWidth: 18,
        sectionSpacing: 24,
      ),
    );
// --8<-- [end:gabelChartTheme]

/// The Gabel theme for `OiBadge`.
OiBadgeThemeData gabelBadgeTheme(GabelText text) => OiBadgeThemeData(
  useSwatchColors: true,
  borderRadius: const BorderRadius.all(Radius.circular(6)),
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  textStyle: text(12, 16, weight: 500, tracking: .12),
  height: 24,
);

/// The Gabel theme for `OiBanner`.
OiBannerThemeData gabelBannerTheme(GabelPalette p) => OiBannerThemeData(
  borderRadius: const BorderRadius.all(Radius.circular(10)),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  iconSize: 18,
  warningBackground: p.pick(GabelLight.warningSoft, GabelDark.warningSoft),
  warningBorder: const Color(0x00000000),
  errorBackground: p.dangerSoft,
  errorBorder: const Color(0x00000000),
  successBackground: p.pick(GabelLight.successSoft, GabelDark.successSoft),
  successBorder: const Color(0x00000000),
  infoBackground: p.pick(GabelLight.secondarySoft, GabelDark.secondarySoft),
  infoBorder: const Color(0x00000000),
  neutralBackground: p.well,
  neutralBorder: const Color(0x00000000),
);

/// The Gabel theme for `OiFieldDisplay`.
OiFieldDisplayThemeData gabelFieldDisplayTheme(
  GabelPalette p,
  GabelText text,
) => OiFieldDisplayThemeData(
  labelStyle: text.fieldLabel,
  valueStyle: text.body,
  emptyStyle: text(14, 20, foreground: p.muted),
  linkStyle: text(14, 20, foreground: p.primaryInk),
  pairGap: 4,
  padding: const EdgeInsets.symmetric(vertical: 2),
);
