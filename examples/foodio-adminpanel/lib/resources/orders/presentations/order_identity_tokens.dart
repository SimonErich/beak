import 'package:beak/panel.dart';

import '../../../domain/foodio_payment.dart';
import '../../../theme/gabel_tokens.dart';

/// Deterministic pastel identity colors shared by cards, search and tables.
const identityPalette = [
  BeakAvatarTone(
    background: GabelLight.primarySoft,
    foreground: GabelLight.primaryInk,
  ),
  BeakAvatarTone(
    background: GabelLight.secondarySoft,
    foreground: GabelLight.secondaryInk,
  ),
  BeakAvatarTone(background: GabelLight.well, foreground: GabelLight.inkMuted),
];

/// Human-readable names for the configured payment modes.
const paymentLabels = foodioPaymentLabels;

/// Readable allergen context shared by notices, options and token tooltips.
String allergenLabel(String code) => switch (code) {
  'A' => 'A · gluten',
  'C' => 'C · eggs',
  'F' => 'F · soy',
  'G' => 'G · milk',
  'H' => 'H · tree nuts',
  'L' => 'L · celery',
  'M' => 'M · mustard',
  _ => '$code · allergen',
};
