import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../gabel_palette.dart';
import '../gabel_text.dart';
import '../tokens/gabel_dark.dart';
import '../tokens/gabel_light.dart';

/// The Gabel theme for `OiButton`.
OiButtonThemeData gabelButtonTheme(
  GabelPalette p,
  GabelText text,
) => OiButtonThemeData(
  smallHeight: 32,
  mediumHeight: 36,
  largeHeight: 44,
  borderRadius: const BorderRadius.all(Radius.circular(8)),
  padding: const EdgeInsets.symmetric(horizontal: 12),
  iconLabelPadding: const EdgeInsetsDirectional.fromSTEB(12, 0, 14, 0),
  textStyle: text(14, 20, weight: 500),
  iconSize: 16,
  iconGap: 8,
  smallIconGap: 6,
  primaryStyle: OiButtonVariantStyle(
    background: p.primary,
    foreground: p.onPrimary,
    backgroundHover: p.pick(GabelLight.primaryHover, GabelDark.primaryHover),
    backgroundPressed: p.pick(GabelLight.primaryPress, GabelDark.primaryPress),
  ),
  secondaryStyle: OiButtonVariantStyle(
    background: p.sheet,
    border: p.border,
    foreground: p.ink,
    backgroundHover: p.well,
  ),
  outlineStyle: OiButtonVariantStyle(
    background: p.sheet,
    border: p.border,
    foreground: p.ink,
  ),
  softStyle: OiButtonVariantStyle(
    background: p.primarySoft,
    foreground: p.primaryInk,
  ),
);

/// The Gabel theme for `OiTextInput`.
OiTextInputThemeData gabelTextInputTheme(GabelPalette p, GabelText text) =>
    OiTextInputThemeData(
      labelStyle: text.fieldLabel,
      labelGap: 4,
      supportingGap: 6,
      multilineContentPadding: const EdgeInsets.all(12),
      textStyle: text.body,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      height: 36,
      borderColor: p.border,
      focusBorderColor: p.primaryInk,
      validationErrorColor: p.danger,
      placeholderColor: p.subtle,
      backgroundColor: p.sheet,
    );

/// The Gabel theme for `OiSearchTrigger`.
OiSearchTriggerThemeData gabelSearchTriggerTheme(
  GabelPalette p,
  GabelText text,
) => OiSearchTriggerThemeData(
  height: 36,
  foreground: p.muted,
  textStyle: text.body,
  decoration: BoxDecoration(
    color: p.sheet,
    borderRadius: const BorderRadius.all(Radius.circular(8)),
    boxShadow: const [
      BoxShadow(color: Color(0x0F1D1E29), offset: Offset(0, 1), blurRadius: 2),
    ],
  ),
);
