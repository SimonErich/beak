---
title: Dynamic attributes and variants
description: Share attribute metadata between editors and validation, then preview and stage variant combinations.
---

# Dynamic attributes and variants

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
--8<-- "examples/clean_beak_config/lib/resources/products/screens/variant_builder.dart:ShopVariantBuilder"
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
