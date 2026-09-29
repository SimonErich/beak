# A belongs-to picker

> Pick a related record in a form, and make its choices depend on another field with one existence rule that the picker and the server share.

You want a form field that picks a related record, and the choices depend on another field. An order belongs to a customer, and its delivery profile has to be one of that customer's profiles.

## Recipe

Declare both relations on the schema. A `@BelongsTo` field adds a foreign key column (`customer_id`, `profile_id`) and a typed relation on the generated model:

```dart title="examples/clean_beak_config/lib/resources/orders/models/order.dart"
/// The customer placing the order.
@BelongsTo(
  searchOn: [#email, #firstName, #lastName],
  inverse: false,
  onDelete: BeakOnDelete.restrict,
)
late final User customer;

/// One of the selected customer's profile associations.
@BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
late final UserProfileConnection profile;
```

State the dependency once, as a record rule on the same schema. `BeakExists` says the selected profile must exist in `UserProfileConnectionModel`, and `matching` says its `userId` has to equal the order's `customerId`:

```dart title="examples/clean_beak_config/lib/resources/orders/models/order.dart"
/// Shared delivery eligibility and complete-order validation.
static List<BeakRecordRule> get validationRules => [
  BeakCount(OrderModel.items, min: 1),
  BeakExists(
    OrderModel.profileId,
    UserProfileConnectionModel.id,
    matching: [
      BeakFieldMatch(
        target: UserProfileConnectionModel.userId,
        source: OrderModel.customerId,
      ),
    ],
  ),
];
```

Place the pickers. Neither call mentions the dependency:

```dart title="examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart"
OrderModel.customer.inputCombobox(),
```

```dart title="examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart"
OrderModel.profile.inputCombobox(),
```

Run `beak prepare` after editing the schema. The form now behaves like this:

- The profile picker is disabled and hints `Select Customer first.` until a customer is chosen.
- Once one is chosen, the picker searches only that customer's profiles.
- If the customer changes and the selected profile no longer belongs to them, the profile is cleared.
- The server runs the same rule on save, so a hand-built request cannot pair Ada with Linus's profile.

## How it works

- `inputCombobox` is a searchable picker over the related model's options query. The record's `displayColumnKey` (the `@Display()` field of the target) is the label, and `searchOn` on the relation adds fields to the search. The order's customer searches email, first name and last name.
- The form reads the model's `BeakExists` rules whose field is this relation's foreign key. Each one contributes its `where` filter and one equality per `matching` entry to the option query, and each `source` field becomes a prerequisite of the picker.
- After a source field changes, the picker checks that the current selection is still among the eligible options and clears it if not. It does not leave a stale value for the server to reject.
- A rule on the model runs in three places: the picker, the form's validation and the server. That is the point of putting it on the schema instead of on the picker.

## Variations

Scoping with `options:` on the picker is form-only. It narrows the choices and the server never sees it. The shop uses it where the dependency is a UI convenience, not a data rule: product attributes may only use definitions of the product's category.

```dart title="examples/clean_beak_config/lib/resources/products/screens/product_form.dart"
ProductAttributeModel.definition.inputCombobox(
  label: 'Category attribute',
  enabledIf: (state) =>
      state.parent?.asProduct.categoryId != null,
  options: (state) => CategoryAttributeModel.options(
    filter: CategoryAttributeModel.categoryId.eq(
      state.parent?.asProduct.categoryId,
    ),
  ),
),
```

| You want | Do this |
| --- | --- |
| The user can create the related record on the spot | `exclusive: false` and a `createForm:`. The shop's category picker does. |
| The rule enforced by the server | `BeakExists` on the schema's `validationRules`, as above. |
| A choice narrowed by the UI only | `options:` with a `Model.options(filter: ...)` query, as above. |
| A different look for the choices | `inputCards` (radio cards) or `inputCode` (type a code, exact match), see [Input builders](../reference/input-builders.md). |
| A required relation | Declare the field non-nullable (`late final User customer`). A nullable one (`Category?`) is optional and clearable. |

The category picker is the first variation. It creates a category from inside the product form:

```dart title="examples/clean_beak_config/lib/resources/products/screens/product_form.dart"
ProductModel.category.inputCombobox(
  exclusive: false,
  createForm: categoryForm(includeAttributes: false),
  description:
      'Configure category attributes in Categories after saving.',
),
```

A record created this way is seeded from the rule too. Create a profile inline after picking a customer, and its `userId` is already that customer.

The shop repeats this particular check in its graph preparer (`ShopGraphPreparer`), so a mismatched profile in the example is refused with the preparer's message before the rule gets a turn. The rule alone does the same job with the message `The selected value is not available.`.

## Verify

The form behaviour (disabled until the customer is set, scoped options, cleared selection, seeded create) is one package test. The server half is another, and the shop's option query has its own:

```console
$ cd packages/beak_frontend
$ flutter test test/src/form/declarative_behavior_test.dart --plain-name 'existence rules infer picker'
00:00 +1: All tests passed!
$ cd ../beak_backend
$ dart test test/src/service/shared_validation_test.dart --plain-name 'existence preflight'
00:00 +1: All tests passed!
$ cd ../../examples/clean_beak_config
$ flutter test test/shop_api_test.dart --plain-name 'typed dependent choices'
00:00 +1: All tests passed!
```

The shop's option query is typed all the way down. This is the assertion the last test makes:

```dart title="examples/clean_beak_config/test/shop_api_test.dart"
final choices = UserProfileConnectionModel.options(
  filter: UserProfileConnectionModel.userId.eq(ShopSeedIds.ada),
);
```

## Continue reading

- [A nested table editor](a-nested-table-editor.md) edits the rows of a to-many relation inside the parent form.
- [Related records in forms](../forms/related-records.md) covers every relation input.
- [Relationships](../models/relationships.md) explains `@BelongsTo`, `@HasMany` and the foreign key rules.
