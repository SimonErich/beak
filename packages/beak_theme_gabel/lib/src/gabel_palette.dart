import 'dart:ui' show Color;

import 'tokens/gabel_dark.dart';
import 'tokens/gabel_light.dart';

/// The Gabel tokens of one brightness, resolved once so the theme files read
/// `p.ink` instead of branching on the mode at every use.
final class GabelPalette {
  /// Creates the palette of [dark] or light mode.
  GabelPalette({required this.dark})
    : canvas = _pick(dark, GabelLight.canvas, GabelDark.canvas),
      sheet = _pick(dark, GabelLight.sheet, GabelDark.sheet),
      well = _pick(dark, GabelLight.well, GabelDark.well),
      ink = _pick(dark, GabelLight.ink, GabelDark.ink),
      muted = _pick(dark, GabelLight.inkMuted, GabelDark.inkMuted),
      subtle = _pick(dark, GabelLight.inkSubtle, GabelDark.inkSubtle),
      line = _pick(dark, GabelLight.line, GabelDark.line),
      lineStrong = _pick(dark, GabelLight.lineStrong, GabelDark.lineStrong),
      border = _pick(dark, GabelLight.border, GabelDark.border),
      primary = _pick(dark, GabelLight.primary, GabelDark.primary),
      primaryInk = _pick(dark, GabelLight.primaryInk, GabelDark.primaryInk),
      primarySoft = _pick(dark, GabelLight.primarySoft, GabelDark.primarySoft),
      onPrimary = _pick(dark, GabelLight.onPrimary, GabelDark.onPrimary),
      danger = _pick(dark, GabelLight.danger, GabelDark.danger),
      dangerInk = _pick(dark, GabelLight.dangerInk, GabelDark.dangerInk),
      dangerSoft = _pick(dark, GabelLight.dangerSoft, GabelDark.dangerSoft);

  /// Whether this is the dark palette.
  final bool dark;

  /// The page background.
  final Color canvas;

  /// Panels, cards and inputs.
  final Color sheet;

  /// A recessed surface, such as a hovered row or a segmented control track.
  final Color well;

  /// The default text color.
  final Color ink;

  /// Secondary text.
  final Color muted;

  /// Tertiary text and placeholders.
  final Color subtle;

  /// Hairlines.
  final Color line;

  /// Stronger dividers and connectors.
  final Color lineStrong;

  /// The border of a control.
  final Color border;

  /// The brand color.
  final Color primary;

  /// The brand color as text or focus ring.
  final Color primaryInk;

  /// The soft brand fill.
  final Color primarySoft;

  /// Text on a [primary] fill.
  final Color onPrimary;

  /// The error fill and border.
  final Color danger;

  /// The error color as text.
  final Color dangerInk;

  /// The soft error fill.
  final Color dangerSoft;

  /// [light] in light mode, [night] in dark mode.
  Color pick(Color light, Color night) => _pick(dark, light, night);

  static Color _pick(bool dark, Color light, Color night) =>
      dark ? night : light;
}
