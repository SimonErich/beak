# Models

> Define shared data, constraints and behavior once.

Schemas describe stored facts and relationships. Generated model descriptors are shared by the backend and the panel. Semantic metadata adds richer inputs without changing the underlying storage contract.

```dart title="examples/clean_beak_config/lib/resources/products/models/product.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../../categories/models/category.dart';
import '../../taxes/models/tax_rate.dart';
import 'product_attribute.dart';
import 'product_variant.dart';
import 'product_image.dart';

part 'product.beak.dart';

/// Product schema; all metadata and typed helpers are generated.
@Resource()
final class Product extends BeakSchema {
  /// Product name used in picker suggestions.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Current catalog unit price, exact and in euros.
  @Column(
    label: 'Net price',
    semantic: BeakSemantic.money(currency: 'EUR'),
    sortable: true,
    rules: [BeakMin(0)],
  )
  late final BeakDecimal price;

  /// Optional stock-keeping identifier for the base product.
  @Column(searchable: true)
  late final String? sku;

  /// Catalog description.
  late final String? description;

  /// Whether this product can be sold.
  @Column(defaultValue: true)
  late final bool active;

  /// Category and its attribute definitions.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.setNull)
  late final Category? category;

  /// Default exclusive tax rate.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.setNull)
  late final TaxRate? taxRate;

  /// Product-specific attribute values.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<ProductAttribute> attributes;

  /// Ordered product gallery, saved with the product draft.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<ProductImage> images;

  /// Sellable variants with separate prices and stock.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<ProductVariant> variants;
}
```

## Which page to read

| You want to… | Read | For |
| --- | --- | --- |
| Describe data once and generate typed model, field and record APIs | [Defining models](defining-models.md) | Guide for beginners |
| Understand generated fields, record readers and preserved authored files | [Generated code](generated-code.md) | Guide for beginners, experts and agents |
| Choose storage kinds and semantic values for generated controls | [Fields](fields.md) | Guide for beginners |
| Define a field's meaning once for typed generation, inputs, validation, storage, filtering and display | [Semantic fields](semantic-fields.md) | Guide for experts |
| Share scalar, record and relationship constraints between client and server | [Validation](validation.md) | Guide for beginners and experts |
| Declare typed connections and ownership for pickers and nested editing | [Relationships](relationships.md) | Guide for beginners and experts |
| Declare value lifecycles, shared guards and named business actions on the schema | [Model behavior](behavior.md) | Guide for experts |
| Declare managed upload fields and ordered media collections | [Files and storage columns](files-and-storage-columns.md) | Guide for beginners and experts |
| Share attribute metadata between editors and validation, then preview and stage variant combinations | [Dynamic attributes and variants](dynamic-attributes-and-variants.md) | Guide for experts |

## Continue reading

- [Defining models](defining-models.md): Describe data once and generate typed model, field and record APIs.
- [Generated code](generated-code.md): Understand generated fields, record readers and preserved authored files.
- [Fields](fields.md): Choose storage kinds and semantic values for generated controls.
