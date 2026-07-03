import 'package:flutter/widgets.dart';

/// Parses a six-digit `#rrggbb` hex string (leading `#` optional) into an
/// opaque [Color], or `null` when the input is not a six-digit hex color.
Color? parseBeakHexColor(String hex) {
  final String digits = hex.startsWith('#') ? hex.substring(1) : hex;
  if (digits.length != 6) {
    return null;
  }
  final int? rgb = int.tryParse(digits, radix: 16);
  return rgb == null ? null : Color(0xFF000000 | rgb);
}

/// Formats [color] as a `#rrggbb` hex string, dropping the alpha channel —
/// the wire shape `BeakColorColumn` values take.
String formatBeakHexColor(Color color) {
  final int rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0')}';
}
