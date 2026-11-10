# Labels in every language

> Name models, fields, relationships, enum values and commands once, in ARB files keyed by Dart names, and let the panel show them in its language.

After this page you can name every model, field, relationship, enum value and
command of a panel in each of its languages without writing one label in a
screen, and read your app's own copy from the context.

## At a glance

| You want | Use |
| --- | --- |
| Names for every model, field and enum value in each language | `labels:` in `beak.yaml` and one ARB file per language |
| One screen's own wording for a field | `label:` where the field is placed |
| The app's own copy in the configuration | `BeakLocalizedPanel`, or `runServerpodBeakAdmin(config: (context, auth) => ...)` |
| Beak's own tab and card titles | `BeakTab.general`, `BeakTab.details`, `BeakCard.general` |

## Order of precedence

Every label is read when it is shown, in the panel's language:

| # | Source | Example |
| --- | --- | --- |
| 1 | Where the field is placed | `ProductModel.sku.inputText(label: 'Item no.')` |
| 2 | Label file, exact key | `"product.sku": "Artikelnummer"` |
| 3 | Label file, shared key | `"*.sortOrder": "Reihenfolge"` |
| 4 | The schema | `@Column(label: 'SKU')`, or the inventory's `fields.<name>.label` |
| 5 | The field name made readable | `sortOrder` reads `Sort Order` |

A single-language panel can stop at row 4. A panel in more than one language
puts its names in label files.

## Label files

Point `beak.yaml` at a folder of ARB files, one per language:

```yaml
labels:
  path: labels        # relative to beak.yaml
  template: de        # the language generated defaults use
  require: shown      # fail on a shown field without a label
```

`labels: labels` is the short form. Without `require: shown`, a missing label
is a warning and the field keeps its schema label.

Keys are paths of Dart names in lowerCamelCase, never table or column keys:

```json
{
  "@@locale": "de",
  "*.sortOrder": "Reihenfolge",
  "placedOrder": "{count, plural, one{Bestellung} other{Bestellungen}}",
  "placedOrder.email": "E-Mail",
  "placedOrder.email.hint": "Adresse der Bestätigung",
  "placedOrder.actions.cancel": "Stornieren",
  "placedOrder.actions.cancel.description": "Die Bestellung wird storniert.",
  "orderStatus.pending": "Offen"
}
```

| Key | Names |
| --- | --- |
| `placedOrder` | The model. An ICU plural gives one and other; a plain text serves both. |
| `placedOrder.email` | A field or relationship of the model |
| `placedOrder.email.hint` | The help text under the field's input |
| `placedOrder.actions.cancel` | A model command, and `.description` its explanation |
| `orderStatus.pending` | An enum value, by enum type |
| `*.sortOrder` | Every field, relationship or enum value of that name without an exact key |

`@Resource(labelKey: 'order')`, or `labelKey: order` in a Serverpod
inventory, files a model's labels under another key. A foreign key without
a label takes its relationship's, and a related field that shows the related
record's display column reads as the relationship (`order.customer.name`
reads `Customer`).

Flutter's gen-l10n cannot hold these keys, because its resource names must be
Dart method names, so the label files live in their own folder. They are plain
ARB, so translation tools read them like any other.

## What the generator checks

`beak prepare` and `beak generate` read the label files and write every
language onto the generated models, columns, relationships, enum columns and
command labels. They fail when:

- a key names nothing; the message suggests the nearest real key
  (`"placedOrder.emial" ... Did you mean "placedOrder.email"?`)
- a shared key is never used because every field of that name has its own key
- a key is in one language and missing in another
- two models share a label key
- a plural has no `other`

They report shown fields without a label, which is an error with
`require: shown`. `beak generate --check` and `beak doctor` include the label
files, so a changed translation without a new run is caught.

## Your own copy

Navigation sections, tab and card titles, wizard steps and dashboard text are
your app's copy, not a model's. Keep them in your gen-l10n ARB files and build
the configuration in a context that holds them:

```dart
BeakLocalizedPanel(
  locale: const Locale('de'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  config: (context) => BeakPanelConfig(
    title: AppLocalizations.of(context).appTitle,
    resources: shopResources(context),
  ),
)
```

`runServerpodBeakAdmin` does the same with `locale`, `supportedLocales`,
`localizationsDelegates` and `config: (context, auth) => ...`. The builder runs
with the panel's language already set, so a function that needs copy takes the
`BuildContext`; nothing passes localizations around. Something that reads a
label while it is built belongs in that builder, not in a top-level `final`,
or it keeps the first language.

Beak words its own titles: `BeakTab.general`, `BeakTab.details` and
`BeakCard.general` follow the panel's language without any copy of yours.

## Rules and limits

- One panel shows one language at a time: `BeakLabels.language` follows the
  panel's locale, and a new locale builds the configuration again.
- The server has no panel locale. Server-written texts, such as CSV headers,
  use the template language.
- Command names are not checked: an action key under a known model is taken
  as written.

## Verify it

- `beak generate --check` (or `beak doctor`) passes, so the generated models
  carry the current label files.
- A widget test pumps the panel in each locale and finds a label of each kind:
  the model's plural, a column heading and an enum value
  (`packages/beak_frontend/test/src/localization/beak_model_labels_test.dart`).

## Reference

- `packages/beak_core/lib/src/localization/beak_labels.dart`
- `packages/beak_cli/lib/src/labels/label_resolver.dart`
- `packages/beak_frontend/lib/src/panel/beak_localized_panel.dart`

## Continue reading

- [Defaults, labels and standard resources](defaults-and-labels.md): the
  standard resource and list these labels appear in.
- [Formatting and localization](../theming/formatting-and-localization.md):
  numbers, money, dates and Beak's own controls in each language.
- [Generating the admin schema](../serverpod/admin-app/generate.md): the
  inventory a Serverpod admin's label files sit next to.
