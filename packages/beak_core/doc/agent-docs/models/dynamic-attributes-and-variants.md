# Dynamic attributes and variants

> Share attribute metadata between editors and validation, then preview and stage variant combinations.

`BeakAttributeDefinition` describes an attribute's stable identity, label, type,
choices, requiredness, version and optional rules. A single definition can drive
an input and authoritative validation. Supported types are text, finite number,
boolean and explicit choice. Canonical values remain strings, so this works with
an existing attribute-value schema.

The shop keeps one adapter in `lib/domain/shop_attributes.dart`. It converts its
category model's metadata into the shared descriptor; both the product editor and
the transactional policy call that adapter. Existing comma-separated choices are
adapted once into `List<String>` without replacing stored catalog data.

```dart
ProductAttributeModel.value.inputAttribute(
  definition: (state) => switch (state.read(ProductAttributeModel.definition)) {
    final BeakRecord record => shopAttributeDefinition(record),
    null => null,
  },
)
```

`definition.validate(value, version: storedVersion)` checks representation and an
optional definition revision. `BeakAttributeSet.reconcile(entries)` reports
retained values, obsolete values, missing required definitions and errors. It does
not delete incompatible data. The shop rejects a category change until the final
owned attribute rows match the selected category; users can correct or explicitly
remove obsolete rows. This example keeps definition version 1; applications that
change attribute meaning should persist and compare definition revisions.

## Variant combinations

`BeakVariantAxis` gives each dimension a stable key and allowed values.
`BeakVariantMatrix.preview(existing: ...)` returns only missing combinations, with
a deterministic collision-safe key and readable label. The matrix bounds the
Cartesian product before creating any records.

The product form's custom builder accepts two dimensions, previews at most 100
combinations, lets the user select a subset and adds ordinary unsaved variants.
Generated rows inherit the catalog price, start with zero stock and receive a
unique SKU suffix within the current product draft. Every attribute becomes an
owned child draft. Nothing is written until the product is saved.

```dart title="examples/clean_beak_config/lib/resources/products/screens/variant_builder.dart"
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
```

Client preview is an aid, not a uniqueness guarantee. The shop recomputes canonical
combination keys from the final attribute rows, checks existing variants, and
backs new keys with a scoped database uniqueness constraint. The normal SKU
constraint remains authoritative across products and concurrent users. The
additive migration preserves existing variants whose keys have not yet been
calculated; server checks also inspect those existing attribute rows.

## Continue reading

- [Custom widgets](../extending/custom-blocks-and-widgets.md).
- [Model behavior](behavior.md).
