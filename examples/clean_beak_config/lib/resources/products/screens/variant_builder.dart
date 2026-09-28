import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../domain/shop_attributes.dart';
import '../models/product.dart';
import '../models/product_variant.dart';
import '../models/variant_attribute.dart';

/// Previews combinations before adding ordinary, unsaved relationship rows.
// --8<-- [start:ShopVariantBuilder]
class ShopVariantBuilder extends HookWidget {
  /// Shares the product form's draft, cancellation, validation and final save.
  const ShopVariantBuilder({required this.draft, super.key});

  /// Product draft containing the configured variants relationship editor.
  final BeakDraftRecord draft;

  @override
  Widget build(BuildContext context) {
    final firstName = useTextEditingController(text: 'Size');
    final firstValues = useTextEditingController();
    final secondName = useTextEditingController(text: 'Finish');
    final secondValues = useTextEditingController();
    final preview = useState<List<BeakVariantCombination>>(const []);
    final selected = useState<Set<String>>({});
    final message = useState<String?>(null);
    final enabled =
        BeakDraftScope.of(context).enabled && !draft.session.hasUnknown;
    void invalidate(String _) {
      preview.value = const [];
      selected.value = {};
      message.value = null;
    }

    return OiCard(
      child: OiColumn(
        breakpoint: context.breakpoint,
        crossAxisAlignment: CrossAxisAlignment.start,
        gap: const OiResponsive(12),
        children: [
          const OiLabel.h3('Build variant combinations'),
          const OiLabel.small(
            'Enter up to two dimensions. Preview, select and add combinations to this draft; nothing is saved until the product is saved.',
          ),
          OiTextInput(
            label: 'First dimension',
            controller: firstName,
            enabled: enabled,
            onChanged: invalidate,
          ),
          OiTextInput(
            label: 'First dimension values',
            hint: 'For example: 250 g, 1 kg',
            controller: firstValues,
            enabled: enabled,
            onChanged: invalidate,
          ),
          OiTextInput(
            label: 'Second dimension (optional)',
            controller: secondName,
            enabled: enabled,
            onChanged: invalidate,
          ),
          OiTextInput(
            label: 'Second dimension values',
            hint: 'For example: Whole bean, Ground',
            controller: secondValues,
            enabled: enabled,
            onChanged: invalidate,
          ),
          OiButton.secondary(
            label: 'Preview combinations',
            enabled: enabled,
            onTap: () {
              final first = shopAttributeChoices(firstValues.text);
              final second = shopAttributeChoices(secondValues.text);
              if (firstName.text.trim().isEmpty ||
                  first.isEmpty ||
                  (second.isNotEmpty &&
                      (secondName.text.trim().isEmpty ||
                          secondName.text.trim() == firstName.text.trim()))) {
                message.value =
                    'Give each dimension a different name and provide its values.';
                return;
              }
              if (first.length * (second.isEmpty ? 1 : second.length) > 100) {
                message.value = 'Preview at most 100 combinations at a time.';
                return;
              }
              final matrix = BeakVariantMatrix([
                BeakVariantAxis(
                  key: firstName.text.trim(),
                  label: firstName.text.trim(),
                  values: first,
                ),
                if (second.isNotEmpty)
                  BeakVariantAxis(
                    key: secondName.text.trim(),
                    label: secondName.text.trim(),
                    values: second,
                  ),
              ], maximumCombinations: 100);
              preview.value = matrix.preview(
                existing: shopVariantCombinations(draft),
              );
              selected.value = {
                for (final combination in preview.value) combination.key,
              };
              message.value = preview.value.isEmpty
                  ? 'These combinations already exist in this product.'
                  : '${preview.value.length} new combinations. Select those you want to add.';
            },
          ),
          if (message.value case final String text) OiLabel.small(text),
          for (final combination in preview.value)
            OiCheckbox(
              label: combination.label,
              value: selected.value.contains(combination.key),
              enabled: enabled,
              onChanged: (value) => selected.value =
                  value == true
                        ? {...selected.value, combination.key}
                        : {...selected.value}
                    ..remove(combination.key),
            ),
          if (preview.value.isNotEmpty)
            OiButton.primary(
              label: 'Add selected variants',
              enabled: enabled && selected.value.isNotEmpty,
              onTap: () {
                if ((draft.read(ProductModel.sku)?.trim().isEmpty ?? true) ||
                    draft.read(ProductModel.price) == null) {
                  message.value =
                      'Enter a base SKU and catalog price in Overview first.';
                  return;
                }
                final added = stageShopVariants(
                  draft,
                  preview.value.where(
                    (item) => selected.value.contains(item.key),
                  ),
                );
                preview.value = const [];
                selected.value = {};
                message.value =
                    '$added variants added to the draft. Review prices and stock below.';
              },
            ),
        ],
      ),
    );
  }
}
// --8<-- [end:ShopVariantBuilder]

/// Includes loaded and newly staged rows when excluding existing combinations.
Iterable<BeakVariantCombination> shopVariantCombinations(
  BeakDraftRecord product,
) => [
  for (final variant in product.rows(ProductModel.variants))
    BeakVariantCombination({
      for (final attribute in variant.rows(ProductVariantModel.attributes))
        if (attribute.read(VariantAttributeModel.name) case final String name)
          name: attribute.read(VariantAttributeModel.value) ?? '',
    }),
];

/// Adds only missing combinations; all edits use Beak's existing draft graph.
int stageShopVariants(
  BeakDraftRecord product,
  Iterable<BeakVariantCombination> combinations,
) {
  final existing = shopVariantCombinations(
    product,
  ).map((row) => row.key).toSet();
  final skus = product
      .rows(ProductModel.variants)
      .map((row) => row.read(ProductVariantModel.sku))
      .toSet();
  final prefix = product.read(ProductModel.sku)!.trim();
  var suffix = 1;
  var added = 0;
  for (final combination in combinations) {
    if (!existing.add(combination.key)) continue;
    while (skus.contains('$prefix-${suffix.toString().padLeft(3, '0')}')) {
      suffix++;
    }
    final sku = '$prefix-${suffix.toString().padLeft(3, '0')}';
    skus.add(sku);
    final variant = product.addRow(ProductModel.variants);
    variant.set(ProductVariantModel.name, combination.label);
    variant.set(ProductVariantModel.sku, sku);
    variant.set(ProductVariantModel.price, product.read(ProductModel.price));
    variant.set(ProductVariantModel.stock, 0);
    variant.set(ProductVariantModel.active, true);
    for (final entry in combination.values.entries) {
      final attribute = variant.addRow(ProductVariantModel.attributes);
      attribute.set(VariantAttributeModel.name, entry.key);
      attribute.set(VariantAttributeModel.value, entry.value);
    }
    added++;
  }
  return added;
}
