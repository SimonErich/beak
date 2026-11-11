import 'dart:ui' show Color;

import 'package:obers_ui/obers_ui.dart';

import 'gabel_palette.dart';
import 'tokens/gabel_dark.dart';
import 'tokens/gabel_light.dart';

// --8<-- [start:gabelSwatch]
OiColorSwatch _swatch(Color value, Color soft, Color foreground) =>
    OiColorSwatch(
      base: value,
      light: soft,
      dark: value,
      muted: soft,
      foreground: foreground,
    );
// --8<-- [end:gabelSwatch]

/// Maps the Gabel tokens of [p] onto the slots of [base].
///
/// Everything the design does not name (`glassBackground`, `glassBorder`)
/// keeps its stock value.
// --8<-- [start:gabelColors]
OiColorScheme gabelColors(OiColorScheme base, GabelPalette p) {
  final pick = p.pick;
  return base.copyWith(
    background: p.canvas,
    surface: p.sheet,
    surfaceSubtle: p.well,
    surfaceHover: pick(GabelLight.fillHover, GabelDark.fillHover),
    surfaceActive: pick(GabelLight.fillPress, GabelDark.fillPress),
    overlay: pick(GabelLight.scrim, GabelDark.scrim),
    text: p.ink,
    textSubtle: p.subtle,
    textMuted: p.muted,
    textInverse: pick(GabelLight.onInverse, GabelDark.onInverse),
    textOnPrimary: p.onPrimary,
    border: p.border,
    borderSubtle: p.line,
    borderFocus: p.primaryInk,
    borderError: p.dangerInk,
    primary: _swatch(
      p.primary,
      p.primarySoft,
      p.onPrimary,
    ).copyWith(dark: p.primaryInk),
    accent: _swatch(
      pick(GabelLight.secondary, GabelDark.secondary),
      pick(GabelLight.secondarySoft, GabelDark.secondarySoft),
      pick(GabelLight.onSecondary, GabelDark.onSecondary),
    ),
    success: _swatch(
      pick(GabelLight.successInk, GabelDark.successInk),
      pick(GabelLight.successSoft, GabelDark.successSoft),
      pick(GabelLight.onSuccess, GabelDark.onSuccess),
    ),
    warning: _swatch(
      pick(GabelLight.warningInk, GabelDark.warningInk),
      pick(GabelLight.warningSoft, GabelDark.warningSoft),
      pick(GabelLight.onWarning, GabelDark.onWarning),
    ),
    error: _swatch(
      p.dangerInk,
      p.dangerSoft,
      pick(GabelLight.onDanger, GabelDark.onDanger),
    ),
    info: _swatch(
      pick(GabelLight.secondaryInk, GabelDark.secondaryInk),
      pick(GabelLight.secondarySoft, GabelDark.secondarySoft),
      pick(GabelLight.onSecondary, GabelDark.onSecondary),
    ),
    chart: p.dark
        ? const [
            GabelDark.chart1,
            GabelDark.chart2,
            GabelDark.chart3,
            GabelDark.chart4,
            GabelDark.chart5,
            GabelDark.chart6,
          ]
        : const [
            GabelLight.chart1,
            GabelLight.chart2,
            GabelLight.chart3,
            GabelLight.chart4,
            GabelLight.chart5,
            GabelLight.chart6,
          ],
  );
}
// --8<-- [end:gabelColors]
