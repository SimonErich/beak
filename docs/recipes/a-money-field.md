---
title: A money field
description: Store a price as an exact BeakDecimal, edit it with a currency input, show it in the panel's locale and sum it without floating point.
type: recipe
audience: [beginner, expert, agent]
status: stable
---

# A money field

You want a price that is exact in the database, in the form and in the total: 19.99 stays 19.99, and three of them add up to 59.97 on the server and in the browser.

## Recipe

Declare the field as `BeakDecimal` and give it the money semantic. This is the shop's product price:

```dart title="examples/clean_beak_config/lib/resources/products/models/product.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/models/product.dart:productPrice"
```

Run `beak prepare`. If the table already exists, add the column with a migration (`beak make:migration AddPriceToProducts --from-drift` fills it in from the difference). The column is an integer.

Place the currency input where the form needs it:

```dart title="examples/clean_beak_config/lib/resources/products/screens/product_form.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/screens/product_form.dart:ProductPriceInput"
```

The table cell and the detail row need nothing. They format the value with the panel's `BeakFormatting`, and the shop sets one policy for the whole panel:

```dart title="examples/clean_beak_config/lib/main.dart"
formatting: const BeakFormatting(
  locale: 'de_AT',
  currency: 'EUR',
  datePattern: 'dd.MM.yyyy',
  dateTimePattern: 'dd.MM.yyyy HH:mm',
),
```

With that policy an amount of 1234.05 shows as `€ 1 234,05` (with no-break spaces), and the currency input reads numbers the way `de_AT` writes them, so `1234,05`.

## How it works

- `BeakDecimal(units, scale: 2)` is an integer count of units. 12.50 is stored as `1250`, sent as `1250`, and read back as `12.50`. There is no `double` anywhere on the path.
- Arithmetic is integer arithmetic. `+` and `-` work on two amounts, `*` takes an `int` quantity. The shop's line total below is the whole formula.
- `BeakMin(0)` and every other rule compare exact values, on the client and again on the server. The filter takes an exact value too: `ProductModel.price.gte(BeakDecimal.parse('14'))`.
- `BeakDecimal.parse` refuses digits the scale cannot hold. `parse('19.999')` throws, and `tryParse` returns `null`. Nothing rounds silently.
- The coefficient is limited to 9007199254740991 units (`BeakDecimal.maxUnits`), the largest integer that Dart, JavaScript and JSON all keep exact. At two decimals that is about 90 trillion.

```dart title="examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart"
--8<-- "examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart:orderLineTotal"
```

## Variations

| You want | Do this |
| --- | --- |
| The currency to vary per record | Add a `String` currency field and point the money field at it with `currencyFrom: #currency`. The shop's fulfillment policy does. |
| A total | `InvoiceModel.total.sum(source, filter: ...)` returns a `BeakDecimal`. The shop's receivables card runs it, see [Custom blocks and widgets](../extending/custom-blocks-and-widgets.md). |
| A percentage of an amount | `BeakDecimal * BeakDecimal` does not exist. Do the rounding in integers, as `ShopMoney.percentOf` in `examples/clean_beak_config/lib/domain/shop_totals.dart` does (half-up to a whole cent). |
| Money you already store as `int` cents | Keep it. Use `.currency(minorUnits: true)` in tables and `inputCurrency(minorUnits: true)` in forms, as Foodio does with `grossCents`. It is exact, but sums go through `BeakModel.sum` in storage units. |
| Three decimals for a rate or a unit price | `BeakSemantic.money(scale: 3)`, or `BeakSemantic.exactDecimal(scale: 3)` for a number that is not a currency. |
| Money in a CSV import | The import reads numbers in the panel's locale. Under `de_AT` it accepts `12,50` (quoted in the CSV, as `"12,50"`, because the comma also separates cells) and rejects `12.50` and `1.234,50`. See [A CSV import](a-csv-import.md). |

The per-record currency looks like this:

```dart title="examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart"
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart:FulfillmentMoney"
```

`BeakModel.sum` and the typed summaries (`model.summary(...)`) accept only `BeakScalarField<num>`, and `BeakDecimal` is not a `num`. A dashboard tile over an exact money field therefore takes the route shown in [A dashboard KPI](a-dashboard-kpi.md), not `model.sum`.

## Verify

The shop stores `delivery_fee` as `12345` for 123.45, reads it back through the generated field, and filters on it:

```console
$ cd examples/clean_beak_config
$ flutter test test/shop_api_test.dart --plain-name 'semantic policy values round-trip'
00:00 +1: All tests passed!
$ flutter test test/shop_widget_test.dart --plain-name 'the product list shows exact euro prices'
00:01 +1: All tests passed!
```

The first test ends on the physical value, which is the assertion that matters:

```dart title="examples/clean_beak_config/test/shop_api_test.dart"
expect(physical?['delivery_fee'], 12345);
```

For your own field, seed a record with `ProductModel.price.to(BeakDecimal.parse('12.50'))` in an `InMemoryBeakDataSource` and assert on the formatted cell with `BeakFormatting.exactCurrency`, as the second test does.

## Continue reading

- [A belongs-to picker](a-belongs-to-picker.md) selects a related record whose choices depend on another field.
- [A dashboard KPI](a-dashboard-kpi.md) totals money on a page.
- [Field types](../reference/field-types.md) lists every semantic kind and the exact `BeakDecimal` API.
