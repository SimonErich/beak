import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';

import '../../../theme/gabel_tokens.dart';
import 'order_identity_tokens.dart';

/// Reusable categorical dish roles shared by catalog and compact records.
BeakValueBinding<BeakAvatarTone> dishToneBinding(
  BeakScalarField<String> category,
  BeakScalarField<String> diet,
) => BeakValueBinding<BeakAvatarTone>.computed(
  dependencies: [category, diet],
  compute: (row) => dishTone(row.read(category), row.read(diet)),
);

/// Categorical pastel colors, independent of record names and selected variants.
BeakAvatarTone dishTone(String? category, String? diet) => switch (category) {
  'Soups' => identityPalette[1],
  'Mains'
      when (diet ?? '').contains('vegan') ||
          (diet ?? '').contains('vegetarian') =>
    const BeakAvatarTone(
      background: GabelLight.catalogVegetableSoft,
      foreground: GabelLight.inkMuted,
    ),
  'Mains' => identityPalette[0],
  'Desserts' => const BeakAvatarTone(
    background: GabelLight.catalogDessertSoft,
    foreground: GabelLight.inkMuted,
  ),
  _ => identityPalette[2],
};

/// Category and diet symbols used consistently by catalog and owned rows.
IconData dishIcon(String? category, [String? diet]) => switch (category) {
  'Soups' => OiIcons.soup,
  'Desserts' => OiIcons.cakeSlice,
  'Drinks' => OiIcons.cupSoda,
  'Mains' when (diet ?? '').contains('vegan') => OiIcons.leaf,
  'Mains' when (diet ?? '').contains('vegetarian') => OiIcons.salad,
  _ => OiIcons.utensils,
};
