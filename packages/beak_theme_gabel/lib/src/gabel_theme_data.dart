import 'package:flutter/painting.dart';
import 'package:obers_ui/obers_ui.dart';

import 'components/gabel_components.dart';
import 'gabel_colors.dart';
import 'gabel_fonts.dart';
import 'gabel_palette.dart';
import 'gabel_text.dart';

/// The Gabel design for [dark] or light mode, entirely through obers_ui's
/// public theme contract.
OiThemeData buildGabelTheme({required bool dark}) {
  final p = GabelPalette(dark: dark);
  final text = GabelText(p);
  // --8<-- [start:gabelBase]
  final base = dark
      ? OiThemeData.dark(
          fontFamily: gabelSansFamily,
          monoFontFamily: gabelMonoFamily,
        )
      : OiThemeData.light(
          fontFamily: gabelSansFamily,
          monoFontFamily: gabelMonoFamily,
        );
  // --8<-- [end:gabelBase]
  return base.copyWith(
    colors: gabelColors(base.colors, p),
    shadows: base.shadows.copyWith(
      lg: const [
        BoxShadow(color: Color(0x121D1E29), spreadRadius: 1),
        BoxShadow(
          color: Color(0x141D1E29),
          offset: Offset(0, 4),
          blurRadius: 8,
          spreadRadius: -2,
        ),
        BoxShadow(
          color: Color(0x381D1E29),
          offset: Offset(0, 18),
          blurRadius: 36,
          spreadRadius: -12,
        ),
      ],
    ),
    decoration: base.decoration.copyWith(
      defaultBorder: base.decoration.defaultBorder.copyWith(color: p.border),
      focusBorder: base.decoration.focusBorder.copyWith(color: p.primaryInk),
      errorBorder: base.decoration.errorBorder.copyWith(color: p.danger),
    ),
    textTheme: text.apply(base.textTheme),
    radius: const OiRadiusScale(
      none: BorderRadius.zero,
      xs: BorderRadius.all(Radius.circular(4)),
      sm: BorderRadius.all(Radius.circular(6)),
      md: BorderRadius.all(Radius.circular(8)),
      lg: BorderRadius.all(Radius.circular(10)),
      xl: BorderRadius.all(Radius.circular(14)),
      full: BorderRadius.all(Radius.circular(9999)),
    ),
    componentSizes: const OiComponentSizeScale(
      small: 32,
      medium: 36,
      large: 44,
    ),
    animations: const OiAnimationConfig(
      fast: Duration(milliseconds: 120),
      normal: Duration(milliseconds: 200),
      slow: Duration(milliseconds: 320),
      reducedMotion: false,
    ),
    components: gabelComponents(p, text),
  );
}
