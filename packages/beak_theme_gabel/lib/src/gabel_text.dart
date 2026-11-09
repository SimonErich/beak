import 'package:flutter/painting.dart';
import 'package:obers_ui/obers_ui.dart';

import 'gabel_fonts.dart';
import 'gabel_numeric_styles.dart';
import 'gabel_palette.dart';

/// Builds the text styles of one Gabel palette.
///
/// Calling an instance makes a style from the design's size, line height in
/// pixels, weight and width, so the component themes read like the design's
/// own type scale: `text(14, 20, weight: 500)`.
final class GabelText {
  /// Creates the text styles of [palette].
  GabelText(this.palette);

  /// The colors the styles take their ink from.
  final GabelPalette palette;

  // --8<-- [start:gabelTextHelper]
  /// A style of [size] on a [height]-pixel line.
  TextStyle call(
    double size,
    double height, {
    double weight = 400,
    double width = 100,
    double? tracking,
    Color? foreground,
  }) => TextStyle(
    fontFamily: gabelSansFamily,
    fontFamilyFallback: gabelSansFallbackFamilies,
    fontSize: size,
    fontWeight: FontWeight.values[(weight / 100).round().clamp(1, 9) - 1],
    height: height / size,
    color: foreground ?? palette.ink,
    fontVariations: [
      // Native hundred-step weights must remain overridable by components.
      // A fixed wght axis otherwise silently defeats copyWith(fontWeight: ...).
      if (weight % 100 != 0) FontVariation('wght', weight),
      FontVariation('wdth', width),
    ],
    letterSpacing: tracking,
  );
  // --8<-- [end:gabelTextHelper]

  /// [style] with equal-width digits, for amounts that change.
  TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// The default text, 14/20.
  late final TextStyle body = this(14, 20);

  /// Secondary text, 13/18 in muted ink.
  late final TextStyle small = this(13, 18, foreground: palette.muted);

  /// A label above a value or a field: 12/16, medium, subtle ink.
  late final TextStyle fieldLabel = this(
    12,
    16,
    weight: 500,
    tracking: .12,
    foreground: palette.subtle,
  );

  // --8<-- [start:gabelTextTheme]
  /// Replaces every role of [base] with the design's type scale.
  ///
  /// `headingScale` is pinned to 1 so `display`, `h1` and `h2` do not grow on
  /// a wide screen.
  OiTextTheme apply(OiTextTheme base) => base.copyWith(
    headingScale: const OiResponsive<double>(1),
    display: this(40, 48, weight: 560, width: 106, tracking: -.8),
    h1: this(34, 40, weight: 560, width: 106, tracking: -.68),
    h2: gabelHeading2Style.copyWith(color: palette.ink),
    h3: this(18, 24, weight: 580),
    h4: this(16, 24, weight: 580),
    body: body,
    bodyStrong: this(14, 20, weight: 580),
    small: small,
    smallStrong: this(13, 18, weight: 580),
    tiny: this(12, 16, weight: 500, tracking: .12, foreground: palette.subtle),
    caption: fieldLabel,
    code: const TextStyle(
      fontFamily: gabelMonoFamily,
      fontFamilyFallback: gabelMonoFallbackFamilies,
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w500,
    ),
    overline: this(
      11,
      16,
      weight: 600,
      tracking: .5,
      foreground: palette.subtle,
    ),
    link: this(14, 20, foreground: palette.primaryInk),
  );
  // --8<-- [end:gabelTextTheme]
}
