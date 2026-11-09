import 'package:flutter/painting.dart';

/// The dark semantic colors of the Gabel design.
///
/// Each token keeps the name it has in the design's reference prototype, in
/// camelCase: `ink-muted` is `inkMuted`.
abstract final class GabelDark {
  /// Page background, panel, recessed well and popover surfaces.
  static const canvas = Color(0xFF0A0A0D),
      sheet = Color(0xFF131417),
      well = Color(0xFF0E0F12),
      overlay = Color(0xFF1C1C20);

  /// Hairlines, the control border, hover and press fills, and the modal scrim.
  static const line = Color(0xFF242428),
      lineStrong = Color(0xFF323338),
      border = Color(0xFF777880),
      fillHover = Color(0x0FF0F1F9),
      fillPress = Color(0x1AF0F1F9),
      scrim = Color(0x9E010203);

  /// Text ink, from default to subtle.
  static const ink = Color(0xFFEFF0F3),
      inkMuted = Color(0xFFB4B5BC),
      inkSubtle = Color(0xFF83848B);

  /// Inverse surface (toasts, bulk bar) and its text.
  static const inverse = Color(0xFFE5E6E9),
      onInverse = Color(0xFF18191F),
      inverseMuted = Color(0xFF55565D);

  /// The dark navigation rail and its states.
  static const railSurface = Color(0xFF030406),
      railInk = Color(0xFF9E9FA6),
      railHover = Color(0x0FFCFCFC),
      railLine = Color(0x12FCFCFC),
      railActive = Color(0xFFA7A7D6),
      onRailActive = Color(0xFF10101E);

  /// The primary brand color, its states, ink and soft fills.
  static const primary = Color(0xFFADABE7),
      primaryHover = Color(0xFFB6B5EE),
      primaryPress = Color(0xFFA3A2DD),
      onPrimary = Color(0xFF161524),
      primaryInk = Color(0xFFB8B7EF),
      primarySoft = Color(0xFF252537),
      primarySoftHover = Color(0xFF2E2D46);

  /// The secondary color, also used for info.
  static const secondary = Color(0xFF8ABACB),
      onSecondary = Color(0xFF081A21),
      secondaryInk = Color(0xFF9AC6D6),
      secondarySoft = Color(0xFF1B282D);

  /// The highlight color and the focus halo.
  static const highlight = Color(0xFFD7B88D),
      onHighlight = Color(0xFF261708),
      highlightInk = Color(0xFFE8CB9D),
      highlightSoft = Color(0xFF332719),
      focusHalo = Color(0x4CADABE7);

  /// Success: fill, text on it, ink and soft fill.
  static const success = Color(0xFF71B48E),
      onSuccess = Color(0xFF091A11),
      successInk = Color(0xFF91CCA9),
      successSoft = Color(0xFF1A2A21);

  /// Warning: fill, text on it, ink and soft fill.
  static const warning = Color(0xFFE3B371),
      onWarning = Color(0xFF251508),
      warningInk = Color(0xFFE9C28A),
      warningSoft = Color(0xFF342619);

  /// Danger: fill, hover fill, text on it, ink and soft fill.
  static const danger = Color(0xFFDB8A87),
      dangerHover = Color(0xFFE29491),
      onDanger = Color(0xFF221010),
      dangerInk = Color(0xFFEEA7A4),
      dangerSoft = Color(0xFF371F1E);

  /// Info fill and soft fill.
  static const info = Color(0xFF84858D), infoSoft = Color(0xFF212226);

  /// The six chart series colors, in series order.
  static const chart1 = Color(0xFF7877BD),
      chart2 = Color(0xFFC0834A),
      chart3 = Color(0xFF439CCC),
      chart4 = Color(0xFFBA7295),
      chart5 = Color(0xFF47609F),
      chart6 = Color(0xFF338D6B);

  /// Catalog tones: a chart color mixed 26% with the sheet in OKLCH.
  static const catalogVegetableSoft = Color(0xFF202D3B),
      catalogDessertSoft = Color(0xFF322D3E);

  /// Chart helpers: muted series, sequential ramp and diverging scale.
  static const chartMuted = Color(0xFF4C4D53),
      chartSeq1 = Color(0xFF2B2A46),
      chartSeq2 = Color(0xFF413F69),
      chartSeq3 = Color(0xFF59568E),
      chartSeq4 = Color(0xFF7471B3),
      chartSeq5 = Color(0xFF9290CF),
      chartSeq6 = Color(0xFFB5B5E8),
      chartDivNeg = Color(0xFFC48A5A),
      chartDivMid = Color(0xFF3C3D42),
      chartDivPos = Color(0xFF807DC0);
}
