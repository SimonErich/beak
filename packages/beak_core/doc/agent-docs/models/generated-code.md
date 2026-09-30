# Generated code

> What beak prepare writes from a schema class, which symbol to use for what, and which files you never edit.

You wrote a schema class and ran `beak prepare`. After this page you can read every file it wrote, pick the right generated symbol for a task, and tell which files are safe to touch.

None of it is hidden. It is ordinary Dart, committed to your repository and formatted the way `dart format` leaves it. It is also dull on purpose: declarations and one-line delegations into `beak_core`, no logic.

## At a glance

`beak prepare` writes one part file beside each schema and four wiring files under `lib/beak/` (two only while `lib/main.dart` is generated). It keeps three entrypoints current and writes a first migration for a new table.

| File | Holds | Commit it | Edit it |
| --- | --- | --- | --- |
| `<schema>.beak.dart`, beside each schema | The columns, relations, fields, model, draft and record of that schema | Yes | Never |
| `lib/beak/registry.g.dart` | `beakModels` and `buildBeakRegistry()` | Yes | Never |
| `lib/beak/panel.g.dart` | `buildBeakPanel()`, the panel configuration; generated bootstrap only | Yes | Never |
| `lib/beak/app.g.dart` | `beakPanelConfig` and the `BeakApp` widget; generated bootstrap only | Yes | Never |
| `lib/beak/server.g.dart` | `beakHost()`, with the migration and seeder lists | Yes | Never |
| `lib/main.dart`, `bin/serve.dart`, `bin/migrate.dart` | One-line entrypoints | No, git-ignored | Yes, once you own it |
| `lib/migrations/create_<table>_table.dart` | A new table's migration | Yes | Yes, it is yours from the first write |

Every generated file starts with a header that says `beak prepare` wrote it and that it is not to be edited, and the next run overwrites it. To change what one contains, change its input: the schema class, a resource class or `beak.yaml`. An entrypoint without that header belongs to you and `prepare` leaves it alone, which is how an authored `lib/main.dart` stays authored, see [Two ways to boot a panel](../start-here/generated-or-authored.md).

## What lands beside a schema

One schema becomes six passes in one part file. The pieces below come from the shop's `Product` schema, in the order `beak prepare` writes them.

### ProductColumns, the storage description

One `static const` per column, including the ones you never wrote (`id`, the foreign keys). Rules, semantics and options from `@Column` are copied in, and non-nullable fields gain `BeakRequired()`.

```dart title="examples/clean_beak_config/lib/resources/products/models/product.beak.dart"
/// Current catalog unit price, exact and in euros.
static const BeakIntColumn price = BeakIntColumn(
  key: 'price',
  label: 'Net price',
  rules: [BeakRequired(), BeakMin(0)],
  semantic: BeakSemantic.money(currency: 'EUR'),
  sortable: true,
);
```

The column class is picked by the field's Dart type, see [Fields](fields.md). An exact `BeakDecimal` is stored in an integer column and the semantic says how to read it back. `ProductColumns.values` lists every column in declaration order, and the migration reads that list.

### ProductRelations, the relationship description

One constant per relationship, including the ones another schema declared toward this one. Both sides exist without you writing both.

```dart title="examples/clean_beak_config/lib/resources/products/models/product.beak.dart"
/// Category and its attribute definitions.
static const BeakBelongsTo category = BeakBelongsTo(
  key: 'category',
  label: 'Category',
  relatedTable: 'categories',
  displayColumnKey: 'name',
  foreignKey: 'category_id',
  searchColumnKeys: ['name'],
  onDelete: BeakOnDelete.setNull,
);
```

### ProductFields, typed references

This is what you write in your own code. A `BeakScalarField<T>` carries the column, the Dart type and the path from the model it started at, so `ProductModel.price` is a `BeakScalarField<BeakDecimal>` and a typo is a compile error.

```dart title="examples/clean_beak_config/lib/resources/products/models/product.beak.dart"
/// Net price.
BeakScalarField<BeakDecimal> get price => BeakScalarField<BeakDecimal>(
  model: _model,
  column: ProductColumns.price,
  path: _path,
  isRequired: true,
);
```

`ProductToOneField` is the same set reached through a relationship. It is why `OrderItemModel.variant.price` and `ProductVariantModel.product.name` exist: the path keeps its root, so the framework knows which relation to load.

A field reference is more than a name. These are the members you use, all from `beak_core`:

| On | Member | Returns | Use |
| --- | --- | --- | --- |
| Any scalar | `eq(v)`, `notEq(v)` | `BeakFilter` | Equality. A `null` argument becomes an is-null check |
| Number, date, time, `BeakDecimal` | `gt`, `gte`, `lt`, `lte` | `BeakFilter` | Ordered comparison |
| `String` | `contains(s)` | `BeakFilter` | Case-insensitive substring |
| Root scalar | `ascending()`, `descending()` | `BeakSort` | Ordering. Throws for a field reached through a relation |
| Scalar | `readFrom(record)`, `require(record)` | value | Read from a loaded record. `require` throws `BeakRecordShapeException` |
| Scalar | `to(value)` | `BeakFieldValue` | A typed write for `model.record([...])` |
| Any | `invalid(message)` | `BeakValidationException` | A server rule failing on this field |
| To-one | `eq(record)`, `equalsId(id)`, `matches(filter)` | `BeakFilter` | Filter by the related row |
| To-one | `options(...)`, `relationLoad` | `BeakOptionQuery`, `BeakRelationLoad` | A picker source, an eager load |
| To-many | `any(filter)`, `search(field)` | `BeakFilter`, field | Filter by any child, search through the collection |
| `BeakDecimal` | `sum(source)` | `Future<BeakDecimal>` | An exact sum, without floating point |

### ProductModel, the descriptor

The `BeakModel` the backend, the panel and the migration all read. Its statics are the shortcuts you use:

```dart title="examples/clean_beak_config/lib/resources/products/models/product.beak.dart"
/// Typed field and relation references, including reserved names.
static const ProductFields fields = ProductFields();
// ...
/// Typed reference to [price] in this model.
static final price = fields.price;
```

```dart title="examples/clean_beak_config/lib/resources/products/models/product.beak.dart"
/// Declarative source for record choices.
static BeakOptionQuery options({BeakFilter? filter}) => BeakOptionQuery(
  model: const ProductModel(),
  query: const ProductModel().query(filter: filter),
);

/// Searches the model display and searchable columns.
static BeakOptionQuery search(String term, {BeakFilter? filter}) =>
    BeakOptionQuery(
      model: const ProductModel(),
      query: const ProductModel().query(
        filter: filter,
        search: BeakSearch(term, const ['name', 'sku']),
      ),
    );
```

`options()` feeds a picker with the model's records, `search(term)` searches the display column and every `searchable: true` column, and `.including([...])` adds eager to-one loads to either. The invoice form uses it to bring the tax rate along with each product in a picker:

```dart title="examples/clean_beak_config/lib/resources/invoices/screens/invoice_form.dart"
InvoiceItemModel.product.inputCombobox(
  options: (state) =>
      ProductModel.options().including([ProductModel.taxRate]),
),
```

A model also gives you `query(...)`, `count(...)`, `sum(...)`, `avg(...)`, `summary(...)` and `record(...)` from `BeakModel`, without ever naming the table.

### ProductDraft and ProductRecord, typed reads

Two views, for two moments. A draft is a form in progress: values may be missing, so every getter is nullable. A record is a stored row: required fields are non-null and relations are there only when you loaded them.

```dart title="examples/clean_beak_config/lib/resources/products/models/product.beak.dart"
/// Net price, or null while incomplete.
BeakDecimal? get price => _reader.read(ProductModel.fields.price);
```

```dart title="examples/clean_beak_config/lib/resources/products/models/product.beak.dart"
/// Current catalog unit price, exact and in euros.
BeakDecimal get price => ProductModel.fields.price.require(record);
```

```dart title="examples/clean_beak_config/lib/resources/products/models/product.beak.dart"
/// The eager-loaded category, or null when unloaded or unset.
CategoryRecord? get category => switch (record.relations['category']) {
  [final BeakRecord first, ...] => CategoryRecord.of(first),
  _ => null,
};
```

`ProductRecord` is an extension type over `BeakRecord`, so it costs nothing at runtime. You reach it with `record.asProduct`, and a draft with `state.asProduct` inside a form callback. A relationship you did not load reads as `null` (to-one) or an empty list (to-many). It never fetches, and it does not throw. The table and form blocks load what their fields name. When you write a query yourself, ask for the relation with `relationLoads`, for example `relationLoads: [ProductModel.category.relationLoad]`.

A private enum of form slots (`_ProductModelFormSlot`, values `s0`, `s1` and so on) closes the file. It is an implementation bridge for the form engine, one value per field, and never appears in your code.

### Using them

The shop's operations screen configures a table with nothing but these symbols. No column or table name is a string:

```dart title="examples/clean_beak_config/lib/operations.dart"
child: BeakTableBlock(
  model: const ProductVariantModel(),
  fields: [
    ProductVariantModel.sku,
    ProductVariantModel.name,
    ProductVariantModel.product.name,
    ProductVariantModel.stock,
  ],
  enableDelete: false,
  initialSpec: const ProductVariantModel().query(
    sorts: [ProductVariantModel.stock.ascending()],
    pagination: const BeakPagination(perPage: 10),
  ),
  baseFilter: BeakAndFilter([
    ProductVariantModel.active.eq(true),
    ProductVariantModel.stock.lte(5),
  ]),
),
```

Records read the same way outside a form. The shop turns a category attribute row into a typed definition:

```dart title="examples/clean_beak_config/lib/domain/shop_attributes.dart"
final definition = record.asCategoryAttribute;
return BeakAttributeDefinition(
  id: identity ?? definition.id ?? definition.name,
  label: definition.name,
  description: definition.description,
```

And a form callback reads the live draft, which may be incomplete. The user form shows a toggle only once a company is picked:

```dart title="examples/clean_beak_config/lib/resources/users/screens/user_form_screen.dart"
UserModel.company.inputCombobox(),
UserModel.invoiceCompany.inputToggle(
  label: 'Invoice the company',
  visibleIf: (state) => state.asUser.companyId != null,
),
```

## The wiring under lib/beak/

Four files, one concern each. The registry is the one every other file starts from:

```dart title="examples/clean_beak_config/lib/beak/registry.g.dart"
/// A registry populated with every model in [beakModels].
BeakModelRegistry buildBeakRegistry() {
  final registry = BeakModelRegistry();
  for (final model in beakModels) {
    registry.register(model);
  }
  return registry;
}
```

`panel.g.dart` builds the `BeakPanelConfig` from `beak.yaml`, every model and every resource class it found. `app.g.dart` wraps it in `BeakApp`. `server.g.dart` builds the `BeakServeHost` with the registry, every migration in the order of its declared `name`, a create-table migration moved behind the tables its foreign keys point at, and every seeder. You never register a migration or a model by hand. If you did, the next `prepare` would remove it.

A package that only holds schema classes, and depends on `beak_core` alone, gets the parts and `registry.g.dart` and nothing else.

## Rules and limits

- Never edit a generated file. The header says so, `beak doctor` fails on drift, and the next `prepare` overwrites your change.
- Commit them. A fresh clone compiles before any `beak` command runs, a schema change shows up in review as the diff it caused, and CI needs no Beak CLI to build the app. The three entrypoints are the exception, they are git-ignored on purpose.
- Reference fields through the model. `ProductModel.price`, not `'price'`. Nothing in an application spells a column key.
- Some names have no shortcut. A field named `fields`, `options`, `search`, `table`, `displayColumnKey`, `columns`, `permissions`, `validationRules`, `behavior`, `capabilities`, `dataSource`, `createModel`, `editModel`, `relationships`, `relatedModels`, `softDeletes`, `formSlots`, `primaryKey`, `ref`, `query`, `count`, `sum`, `avg`, `sumDecimal`, `avgDecimal`, `summary`, `record`, `primaryKeyOf`, `columnsFor`, `columnByKey` or `relationshipByKey` collides with a member of `BeakModel`, so `ProductModel.count` is not emitted. Use `ProductModel.fields.count`, which always exists. A test in `beak_cli` reads `BeakModel` and fails when it gains a member this list misses.
- One name is refused. A field named `record` is a `beak prepare` issue: the typed record view wraps the underlying `BeakRecord` as `record`, so a getter of that name would redeclare it. Rename the field, and pin the existing column with `@Column(columnName: 'record')` when the table already has it.
- Draft getters are all nullable, record getters are not. A record getter is non-null exactly when the schema field is non-nullable. Do not paper over the difference with `!`.
- An unloaded relation reads as empty. It does not throw and it does not fetch. Load it explicitly.
- Identifiers follow the class. `Product` yields `ProductColumns`, `ProductModel`, `ProductRecord`. A hand-written class with one of those names will clash.
- One schema class per file. Two schemas in one file share one part, and the second overwrites the first, see [Defining models](defining-models.md#where-the-file-goes).

For an agent: after any change to a schema, resource class, screen or `beak.yaml`, run `beak prepare` and then `dart analyze`. Read `*.beak.dart` to learn a name, never to change one.

## Verify it

```bash
beak prepare
beak doctor
```

`prepare` is idempotent: run it twice and the second run rewrites nothing.

```text
  1 model · 0 resource classes · 0 screens · 0 overrides
  generated  up to date (8 files)
```

`beak doctor` byte-compares every generated file with what `prepare` would write now, and lists missing and stale files separately:

```text
  FAIL generated files out of date (0 missing, 1 stale)
       → beak prepare
```

## Reference

| Generated symbol | Kind | Use it for |
| --- | --- | --- |
| `XColumns.<field>` | `static const` column | Migrations, custom cells, anything needing the raw `BeakColumn` |
| `XColumns.values` | `List<BeakColumn>` | The model's column list |
| `XRelations.<field>` | `static const` relationship | Relationship metadata, pivot tables |
| `XFields` | class | Typed field references, also reachable as `XModel.fields` |
| `XToOneField` | class | A to-one path: `OrderModel.customer.email` |
| `XModel` | `BeakModel` subclass | The descriptor, `const XModel()` |
| `XModel.<field>` | `static final` | A typed reference to one field |
| `XModel.options()`, `XModel.search(term)` | `BeakOptionQuery` | Picker sources |
| `XDraft`, `state.asX` | class, extension | Nullable reads inside form callbacks |
| `XRecord`, `record.asX` | extension type, extension | Typed reads of a stored row |
| `beakModels`, `buildBeakRegistry()` | constant, function | Every model and the registry over them |
| `buildBeakPanel()`, `beakPanelConfig`, `BeakApp` | function, value, widget | The generated panel |
| `beakHost()` | function | The generated server host |

The complete list with signatures is in [Generated files and symbols](../reference/generated-files.md).

## Continue reading

- [Fields](fields.md) how a Dart type picks the column class you saw above.
- [Relationships](relationships.md) the four relationship kinds and their inverse.
- [CLI commands](../reference/cli-commands.md) every `beak` command and flag.
