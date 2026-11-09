import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../gabel_palette.dart';
import '../gabel_text.dart';

/// The Gabel theme for `OiCheckbox`.
OiCheckboxThemeData gabelCheckboxTheme(GabelPalette p) => OiCheckboxThemeData(
  borderWidth: 1,
  size: 16,
  borderRadius: const BorderRadius.all(Radius.circular(2)),
  disabledColor: p.line,
);

/// The Gabel theme for `OiRadio`.
OiRadioThemeData gabelRadioTheme(GabelPalette p, GabelText text) =>
    OiRadioThemeData(
      optionSpacing: 24,
      optionPadding: EdgeInsets.zero,
      size: 16,
      dotSize: 6,
      borderWidth: 1,
      borderColor: p.border,
      selectedBorderColor: p.primary,
      selectedFillColor: p.sheet,
      selectedDotColor: p.primary,
      labelStyle: text.body,
      groupLabelSpacing: 12,
      groupLabelStyle: text(16, 24, weight: 580),
    );

/// The Gabel theme for `OiRadioTile`.
OiRadioTileThemeData gabelRadioTileTheme(GabelPalette p, GabelText text) =>
    OiRadioTileThemeData(
      titleStyle: text(14, 20, weight: 500),
      controlGap: 12,
      bodyGap: 16,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      borderWidth: 1,
      selectedBorderWidth: 2,
      minHeight: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderColor: p.border,
      selectedBorderColor: p.primary,
      backgroundColor: p.sheet,
      selectedBackgroundColor: p.primarySoft,
    );

/// The Gabel theme for `OiTabs`.
OiTabsThemeData gabelTabsTheme(GabelPalette p, GabelText text) =>
    OiTabsThemeData(
      labelStyle: text(14, 20, weight: 500),
      indicatorColor: p.primary,
      tabPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
      tabSpacing: 24,
      activeLabelColor: p.ink,
      inactiveLabelColor: p.muted,
    );

/// The Gabel theme for `OiSwitch`.
OiSwitchThemeData gabelSwitchTheme(GabelPalette p) => OiSwitchThemeData(
  width: 36,
  height: 20,
  activeTrackColor: p.primary,
  inactiveTrackColor: p.muted,
  thumbColor: p.sheet,
);

/// The Gabel theme for `OiSegmentedControl`.
OiSegmentedControlThemeData gabelSegmentedControlTheme(
  GabelPalette p,
  GabelText text,
) => OiSegmentedControlThemeData(
  labelStyle: text(14, 20, weight: 500),
  spacing: 2,
  height: 32,
  inset: 2,
  innerRadius: const BorderRadius.all(Radius.circular(6)),
  backgroundColor: p.well,
  selectedColor: p.sheet,
  selectedTextColor: p.ink,
  unselectedTextColor: p.muted,
  borderColor: const Color(0x00000000),
  borderRadius: const BorderRadius.all(Radius.circular(8)),
);
