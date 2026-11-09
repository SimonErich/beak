import 'package:flutter/painting.dart';

/// The light semantic colors of the Gabel design.
///
/// Each token keeps the name it has in the design's reference prototype, in
/// camelCase: `ink-muted` is `inkMuted`.
abstract final class GabelLight {
  /// Page background, panel, recessed well and popover surfaces.
  static const canvas = Color(0xFFF3F3F7),
      sheet = Color(0xFFFEFEFF),
      well = Color(0xFFF6F7FA),
      overlay = Color(0xFFFFFFFF);

  /// Hairlines, the control border, hover and press fills, and the modal scrim.
  static const line = Color(0xFFE5E5EA),
      lineStrong = Color(0xFFD2D3D9),
      border = Color(0xFF88898F),
      fillHover = Color(0x0D2B2C3D),
      fillPress = Color(0x172B2C3D),
      scrim = Color(0x5214151F);

  /// Text ink, from default to subtle.
  static const ink = Color(0xFF1C1D26),
      inkMuted = Color(0xFF595A63),
      inkSubtle = Color(0xFF7F8086);

  /// Inverse surface (toasts, bulk bar) and its text.
  static const inverse = Color(0xFF202128),
      onInverse = Color(0xFFF6F6F9),
      inverseMuted = Color(0xFFB1B2B9);

  /// The dark navigation rail and its states.
  static const railSurface = Color(0xFF1C1D28),
      railInk = Color(0xFFB7B8C1),
      railHover = Color(0x14FCFCFC),
      railLine = Color(0x12FCFCFC),
      railActive = Color(0xFFBABAEA),
      onRailActive = Color(0xFF181729);

  /// The primary brand color, its states, ink and soft fills.
  static const primary = Color(0xFF625FAC),
      primaryHover = Color(0xFF57559C),
      primaryPress = Color(0xFF4E4C8D),
      onPrimary = Color(0xFFFBFBFE),
      primaryInk = Color(0xFF5A589F),
      primarySoft = Color(0xFFEEEFFC),
      primarySoftHover = Color(0xFFE5E6FB);

  /// The secondary color, also used for info.
  static const secondary = Color(0xFF95C7D9),
      onSecondary = Color(0xFF11242D),
      secondaryInk = Color(0xFF35647A),
      secondarySoft = Color(0xFFE7F4F8);

  /// The highlight color and the focus halo.
  static const highlight = Color(0xFFF2CE9B),
      onHighlight = Color(0xFF382515),
      highlightInk = Color(0xFF855A31),
      highlightSoft = Color(0xFFFDF2E0),
      focusHalo = Color(0x33625FAC);

  /// Success: fill, text on it, ink and soft fill.
  static const success = Color(0xFF4E966F),
      onSuccess = Color(0xFF0A1E13),
      successInk = Color(0xFF286847),
      successSoft = Color(0xFFE7F5EC);

  /// Warning: fill, text on it, ink and soft fill.
  static const warning = Color(0xFFE0A968),
      onWarning = Color(0xFF301D0D),
      warningInk = Color(0xFF8B572C),
      warningSoft = Color(0xFFFCF1E1);

  /// Danger: fill, hover fill, text on it, ink and soft fill.
  static const danger = Color(0xFFB64F4F),
      dangerHover = Color(0xFFA74546),
      onDanger = Color(0xFFFEFBFA),
      dangerInk = Color(0xFFA54344),
      dangerSoft = Color(0xFFFDEDEC);

  /// Info fill and soft fill.
  static const info = Color(0xFF7E8087), infoSoft = Color(0xFFF0F1F4);

  /// The six chart series colors, in series order.
  static const chart1 = Color(0xFF6766AA),
      chart2 = Color(0xFFCD8F57),
      chart3 = Color(0xFF6DBBE8),
      chart4 = Color(0xFFAA6386),
      chart5 = Color(0xFF3D5590),
      chart6 = Color(0xFF338D6B);

  /// Catalog tones: a chart color mixed 26% with the sheet in OKLCH.
  static const catalogVegetableSoft = Color(0xFFCDDCEC),
      catalogDessertSoft = Color(0xFFDDD8EC);

  /// Chart helpers: muted series, sequential ramp and diverging scale.
  static const chartMuted = Color(0xFFBCBDC3),
      chartSeq1 = Color(0xFFE9EAFA),
      chartSeq2 = Color(0xFFCECFF0),
      chartSeq3 = Color(0xFFAFB1E2),
      chartSeq4 = Color(0xFF8E8FD0),
      chartSeq5 = Color(0xFF706FB9),
      chartSeq6 = Color(0xFF524F93),
      chartDivNeg = Color(0xFFCC8F5C),
      chartDivMid = Color(0xFFDDDEE2),
      chartDivPos = Color(0xFF6766AA);
}
