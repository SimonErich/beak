# Hide a resource

> Keep a model, its API and the forms that use it without a page or sidebar entry of its own, in a generated panel (beak.yaml) and an authored one.

You have a model that only makes sense inside another one: order lines, tags, a lookup table. It needs a table and an API, and the order form has to edit it. It does not need its own list page or sidebar entry.

## Recipe

The panel builds its list of known models from the resources you give it, plus every model those resources reach through a relationship. A model reached that way works in pickers, table editors and relation loads without ever being a resource. So hiding a resource is leaving it out, and the two bootstraps differ in how.

**Authored panel**

Do not list it in `resources:`. The shop has an `OrderItem` model and no `OrderItemResource`, because the order form edits the lines and nothing else opens them:

```dart title="examples/clean_beak_config/lib/main.dart"
void main() => runApp(
  BeakPanel(
    title: 'Clean Beak Shop',
    theme: OiThemeData.fromBrand(color: const Color(0xFF315D91)),
    darkTheme: OiThemeData.fromBrand(
      color: const Color(0xFF82ACDF),
      brightness: Brightness.dark,
    ),
    locale: const Locale('en'),
    formatting: const BeakFormatting(
      locale: 'de_AT',
      currency: 'EUR',
      datePattern: 'dd.MM.yyyy',
      dateTimePattern: 'dd.MM.yyyy HH:mm',
    ),
    pages: [shopOverview(), shopOperations()],
    resources: [
      OrderResource(),
      InvoiceResource(),
      VoucherResource(),
      ProductResource(),
      VariantResource(),
      CategoryResource(),
      UserResource(),
      CompanyResource(),
      ProfileResource(),
      TaxRateResource(),
      FulfillmentPolicyResource(),
    ],
  ),
);
```

The panel finds `OrderItemModel` through `OrderModel.items`, and the table editor in the order form works. There is no `/order_items` page.

**Generated panel**

`beak prepare` writes a `BeakResource` for every model it finds. Name the tables to drop under `resources:` in `beak.yaml`, keyed by table name:

```yaml
resources:
  tags:
    hidden: true
```

Run `beak prepare` and the resource is gone from `lib/beak/panel.g.dart`, while the model stays in `lib/beak/registry.g.dart` and its migration stays in `lib/beak/server.g.dart`:

```console
$ beak prepare
  3 models · 0 resource classes · 0 screens · 0 overrides
  generated  1 of 10 files
$ grep -n "Model()" lib/beak/panel.g.dart
24:        model: const NoteModel(),
$ grep -n "TagModel" lib/beak/registry.g.dart
14:  TagModel(),
```

A table name that matches no model stops `prepare` with `resources.tagz names no discovered table`.

## How it works

- The panel's registry is `resources` plus, recursively, every model a resource's model lists in `relatedModels`. A `@BelongsTo` or `@HasMany` puts the far model there.
- A hidden model that a visible one relates to is fully usable in forms. A hidden model that nothing relates to is unknown to the panel, and anything that needs it fails with `No model registered for table "audit_entries".` (the model of a list's saved-view store is the exception: the panel registers it itself, see [A saved list view](a-saved-list-view.md)).
- The table, the migration and the REST API are untouched. `POST /api/order_items/query` answers as before. Hiding is not access control. To keep people out of the data, use a server policy, see [Auth and policies](../backend/auth-and-policies.md).
- `hidden` removes the whole default resource, not only the sidebar entry. Open the hidden model's route by hand (`/tags`) and the panel shows its 404 page.
- A model with a `BeakResource` class ignores `hidden`: a class you wrote is always shown. `beak eject resource <table>` refuses a table marked hidden.

## Variations

| You want | Do this |
| --- | --- |
| The page to exist, only out of the sidebar | Keep the `BeakResource` and write a `BeakNavigation` that does not mention it. The route works, the command bar still lists it, and the sidebar does not. See [Navigation](../panel/navigation.md). |
| A generated panel with such a navigation | `beak eject panel`, then set `navigation:` on the config in `lib/panel.dart`. |
| The entry hidden for some accounts | Model permissions hide UI for an account that may not read the model. The server policy is what enforces it. |
| A model with no relation to any resource, still used by the panel | Give it a `BeakResource` and leave it out of the navigation. |

## Verify

The generator side has a test: with `hidden: true` the panel config lists no resources and the registry still holds the model.

```console
$ cd packages/beak_cli
$ dart test test/src/commands/prepare_command_test.dart --plain-name 'a hidden resource'
00:00 +1: All tests passed!
```

The panel side is easy to check by hand. Run the shop and open `/order_items`: the page is not found. Open a new order, and the `Products and services` table adds and edits its lines all the same. To see a hidden page's route, leave the resource in, drop it from the navigation, and open its URL: the list appears without a sidebar entry.

## Continue reading

- [Add a resource](add-a-resource.md) is the other direction: a model that gets a section.
- [Beak.yaml](../reference/beak-yaml.md) lists every key of the file, including `resources`.
- [Navigation](../panel/navigation.md) shows how to order and group what stays in the sidebar.
