---
title: Formatting and localization
description: Set number, money and date conventions once, keep CSV exports in step with the screen, and see which built-in strings Beak translates (English and German).
type: guide
audience: [beginner, expert]
status: stable
---

# Formatting and localization

A panel shows a price, a timestamp and a Save button, and each of the three follows a different setting. After this page you can set number, money and date conventions once, keep the CSV export in step with the screen, switch Beak's own controls to German, add a language of your own, and tell which strings Beak does not translate.

Beak 0.9 has no localization system for your text: no message catalog, no ARB files, no live language switch. It has a format policy that covers numbers, money, dates and durations, and translations of Beak's own controls into English and German, which leave gaps. This page says where they are.

## At a glance

| You want | Set | On |
| --- | --- | --- |
| Separators, currency placement, month and weekday names | `BeakFormatting(locale: 'de_AT')` | `formatting:` |
| The currency money shows in | `currency: 'EUR'` | `formatting:` |
| The shape of dates and times | `datePattern`, `dateTimePattern`, `timePattern` (ICU patterns) | `formatting:` |
| The date a calendar input asks for | `dateInputPattern` | `formatting:` |
| The time zone timestamps show in | `useLocalTime`, `timeZoneOffsetMinutes` | `formatting:` |
| The text of an empty cell | `emptyValue` | `formatting:` |
| One field shown another way | `Model.field.formatted(BeakValueFormat.date)` | a table, list or form field |
| The language of Beak's buttons and messages | `Locale('de')` | `locale:` |
| A language beyond English and German | a `BeakLocalizations` subclass and its delegate | `BeakPanelConfig.localizationsDelegates` |

Two of these carry the word locale and they are different things. `BeakFormatting.locale` is a string for the `intl` package and decides how a number or a date is written. The panel's `locale` is a Flutter `Locale` and decides which language Beak's own controls speak. The shop sets both and lets them disagree, English buttons and Austrian money:

```dart title="examples/clean_beak_config/lib/main.dart"
--8<-- "examples/clean_beak_config/lib/main.dart:shopFormatting"
```

`BeakPanel(...)` takes `locale` and `formatting`. `supportedLocales` and `localizationsDelegates` exist on `BeakPanelConfig` only. A generated panel has no `beak.yaml` key for any of them (unknown keys are errors), so it sets them in `lib/panel.dart`, the file `beak eject panel` writes:

```console
$ beak eject panel
  created lib/panel.dart

  run `beak prepare` to wire it up
$ beak prepare
  1 model · 0 resource classes · 0 screens · 1 override
```

After that, `lib/beak/panel.g.dart` returns `panel.beakPanel(config)`, so whatever you change on `defaults` is the panel's configuration. Illustrative, with real names:

```dart
import 'package:beak/panel.dart';
import 'package:flutter/widgets.dart';

BeakPanelConfig beakPanel(BeakPanelConfig defaults) => defaults.copyWith(
  locale: const Locale('de'),
  formatting: const BeakFormatting(
    locale: 'de_AT',
    currency: 'EUR',
    datePattern: 'dd.MM.yyyy',
  ),
);
```

## The policy

`BeakFormatPolicy` lives in `beak_core`, because the server formats too: the CSV export builds its cells with it. `BeakFormatting` extends it in `beak_frontend` and adds the widget scope plus the conversions the date editors need. The constructor is the same:

```dart title="packages/beak_frontend/lib/src/formatting/beak_formatting.dart"
--8<-- "packages/beak_frontend/lib/src/formatting/beak_formatting.dart:BeakFormatting"
```

| Setting | Default | What it does |
| --- | --- | --- |
| `locale` | `'en_US'` | ICU locale: separators, grouping, currency placement, month and weekday names. It does not pick the shape of a date. |
| `currency` | `'USD'` | ISO 4217 code money shows in, unless the record names its own. |
| `datePattern` | `'yyyy-MM-dd'` | Dates without a time. |
| `dateInputPattern` | `datePattern` | What editable calendar controls and range endpoints show. |
| `dateTimePattern` | `'yyyy-MM-dd HH:mm'` | Timestamps. |
| `timePattern` | `'HH:mm'` | Times without a date. |
| `numberPrecision` | `2` | Decimals of a non-integer number. An `int` shows none. |
| `currencyPrecision` | `null` | Decimals of money. `null` takes the currency's own (0 for JPY, 2 for EUR). |
| `useGrouping` | `true` | Thousands separators. |
| `useLocalTime` | `true` | Show timestamps in the device's time zone. `false` shows UTC. |
| `timeZoneOffsetMinutes` | `null` | A fixed UTC offset in minutes. Wins over `useLocalTime`. |
| `emptyValue` | an em dash | Text for a null value. |

The panel mounts a `BeakFormattingScope` when `formatting:` is set, and every table cell, detail row, form input, filter, block and summary reads the nearest one with `BeakFormatting.of(context)`. Outside any scope that returns a default `BeakFormatting()`, so a widget of yours behaves in a test without setup. Put your own `BeakFormattingScope` around a subtree to change the policy there ([Using Beak widgets standalone](../extending/using-beak-widgets-standalone.md) does it for an embedded form).

### What the locale decides

The locale picks words and separators. It never picks the shape of a date: `yyyy-MM-dd` stays ISO under every locale, and you write the shape yourself. Same numbers, four locales, money in euro (the gaps in `de_AT` and `fr_FR` are no-break spaces):

| `locale` | `number(1234567.891)` | `currency(1234.5)` | `percent(0.256)` |
| --- | --- | --- | --- |
| `en_US` | `1,234,567.89` | `€1,234.50` | `25.6%` |
| `de_AT` | `1 234 567,89` | `€ 1 234,50` | `25,6 %` |
| `de_DE` | `1.234.567,89` | `1.234,50 €` | `25,6 %` |
| `fr_FR` | `1 234 567,89` | `1 234,50 €` | `25,6 %` |

The pattern `EEE d MMM` gives `Tue 29 Sep` under `en_US` and `Di. 29 Sep.` under `de_AT`. Choose the pattern for the shape and the locale for the words.

The same policy reads what people type. A number input under `de_AT` takes `1234,05`, a pasted CSV import parses its numbers with the panel's separators, and both refuse malformed grouping such as `1,2,3` instead of guessing. A timestamp in an import must be ISO 8601.

## Dates, times and time zones

Patterns are ICU `DateFormat` patterns. Which one applies depends on the value:

| Value | Shown with |
| --- | --- |
| `BeakDateFormat.dateOnly` on a timestamp column, or `BeakValueFormat.date` | `datePattern` |
| `BeakDateFormat.standard` (the column default), or `BeakValueFormat.dateTime` | `dateTimePattern` |
| `BeakDateFormat.timeOnly`, or `BeakValueFormat.time` | `timePattern` |
| `BeakDateFormat.iso` | ISO 8601, no pattern |
| `BeakDateFormat.relative` | `just now`, `5m ago`, `3h ago`, `2d ago`, then `datePattern` after 30 days |
| A calendar date (`BeakDate`) | `datePattern`, never zone-converted |
| A wall-clock time (`BeakTime`) | `timePattern`, never zone-converted |

In table cells and detail values the relative words come from `BeakLocalizations`, so they follow the panel's `Locale`, not `formatting.locale`. The inbox and invoice blocks build their text without a widget context and always use the English words.

Only an absolute timestamp has a time zone. There are three ways to show one. Take the Aviary's specimen with a `hatchedAt` of 11:00 UTC, opened on a machine set to Tokyo (UTC+9):

| Panel configuration | Shows |
| --- | --- |
| no `formatting:` at all | `2026-01-01 11:00` (UTC, as the server sent it) |
| `BeakFormatting()` | `2026-01-01 20:00` (device time) |
| `BeakFormatting(useLocalTime: false)` | `2026-01-01 11:00` (UTC) |
| `BeakFormatting(timeZoneOffsetMinutes: 330)` | `2026-01-01 16:30` (UTC+5:30) |

The first row is the one to notice. A panel with no `formatting:` keeps each plain column's own formatting: timestamps as UTC, decimals at their `precision`, integers as stored. The first `formatting:` you set switches timestamps to device time and adds grouping. Set it explicitly even when you want the defaults, so tables, forms and exports agree.

A fixed offset trades correctness for agreement. Everyone sees the same clock time, and so does the export, but an offset is not a zone: daylight saving does not exist to it. Foodio pins `120` (UTC+2), which is right in Central European summer time and an hour off in winter. Its policy also shows why `dateInputPattern` is separate: the tables print `Tue 29 Sep`, and the calendar input asks for a year.

```dart title="examples/foodio-adminpanel/lib/main.dart"
--8<-- "examples/foodio-adminpanel/lib/main.dart:foodioFormatting"
```

The editors show and read timestamps in the panel's zone and convert back to UTC before the value enters the draft, so what is stored does not depend on where the editor sits. Calendar dates and wall-clock times skip the conversion entirely: `2026-02-28` is `28.02.2026` in every zone.

## Numbers and money

| Value | Shown as |
| --- | --- |
| An `int` | no decimals: `42` |
| A non-integer number | `numberPrecision` decimals: `3.14159` is `3.14` |
| `percent(0.125)` | `12.5%`, up to `numberPrecision` decimals and none when whole. The input is a fraction. |
| Money | the locale places the symbol, the currency sets the decimals: `¥1,234` for JPY, `€1,234.50` for EUR |
| A file size | binary units: `1.50 KiB`, and `1,50 KiB` under `de_DE` |
| A duration | `HH:MM:SS`, with hours unbounded: `27:02:03` |

The policy's `currency` is the default. A money semantic that points at a currency column (`currencyFrom: #currency`) shows the record's own. In the Aviary the policy says EUR and specimen 0 says USD, and its detail page shows `$7.48`, not `€7.48`.

Exact values never pass through a `double`. A `BeakDecimal` is formatted by `exactDecimal` and `exactCurrency` from its integer units, and each semantic field picks its formatter:

| Semantic | Formatter |
| --- | --- |
| `money` | `exactCurrency`, in the record's or the policy's currency |
| `exactDecimal` | `exactDecimal`, every digit kept |
| `percentage` | `percent`, after dividing by the semantic's scale |
| `quantity` | `number`, then the unit |
| `calendarDate`, `time` | `datePattern`, `timePattern`, no zone |
| `duration`, `fileSize` | `HH:MM:SS`, binary units |
| `password` | eight bullets in the export and wherever a value reaches the screen; the server does not send the stored value |

[Semantic fields](../models/semantic-fields.md) explains what each semantic stores. A value that does not fit its format shows as its own text, not as an error.

## One field at a time

`BeakValueFormat` names a formatter, and a field can carry one. The default follows the column, so this is for the field that should read differently in one place:

```dart title="packages/beak_core/lib/src/formatting/beak_format_policy.dart"
--8<-- "packages/beak_core/lib/src/formatting/beak_format_policy.dart:BeakValueFormat"
```

Two extensions on a typed field set it, and neither touches the stored value, a query, a sort or an API payload:

```dart title="packages/beak_frontend/lib/src/formatting/beak_field_format.dart"
--8<-- "packages/beak_frontend/lib/src/formatting/beak_field_format.dart:fieldPresentations"
```

The shop's overview prints an invoice's due date without a time:

```dart title="examples/clean_beak_config/lib/overview.dart"
--8<-- "examples/clean_beak_config/lib/overview.dart:overviewFormattedFields"
```

`.currency(minorUnits: true)` is for a plain integer that holds cents: `1250` reads as `12.50`, where `scale` (0 to 12) is the number of decimals in the integer. Foodio's `grossCents` uses it. `currency()` exists on numeric fields only. A `BeakDecimal` money field formats itself and needs neither, and the limits below say why `.formatted` is a trap there.

The same enum is the `format:` of `BeakMetricBlock` (number, currency or percent), `BeakSummaryValue`, `BeakSummaryLine` and `BeakCalculated`.

## Empty values

A null cell shows `emptyValue`, an em dash unless you change it. So does a related-record cell whose record is missing, and an empty to-one relation on a read page. The same string is written into a formatted CSV export, because the policy travels with the request. There is one setting for both. `emptyValue: ''` gives blank cells in the export and blank cells on screen.

## Exports use the same policy

The Export button sends `POST /api/{table}/export` with the panel's policy as JSON, and the server formats every cell with it. `raw: true` skips the policy and writes stored values. The wire form is `BeakFormatPolicy.toJson`, and the test shows what does and does not survive the trip:

```dart title="packages/beak_core/test/src/columns/beak_format_policy_test.dart"
--8<-- "packages/beak_core/test/src/columns/beak_format_policy_test.dart:portablePolicyTest"
```

`useLocalTime` is always sent as `false`. The server has no business knowing where the browser is, so a policy on `useLocalTime: true` produces a screen in device time and a file in UTC. Set `timeZoneOffsetMinutes` when the two must match. The server rejects a policy with an unknown locale, a precision outside 0 to 12, an offset beyond a day, or a date pattern that is longer than 64 characters or that `intl` cannot format, with `422` and `Malformed export formatting: ...`. [Export to CSV](../recipes/export-to-csv.md) walks through the button, and [Search and export](../backend/search-and-export.md) lists the route.

## The language of the controls

`BeakLocalizations` holds a string or a message per member (over 160), for the controls Beak draws. The German is written in the formal `Sie` register. `BeakPanel` installs its delegate after yours, on every panel, and `supportedLocales` defaults to `[Locale('en'), Locale('de')]`. A device set to French gets English. So does an explicit `Locale('fr')`, because `BeakLocalizations` treats every language other than German as English.

### What is translated

Checked in a German panel (the Aviary with `locale: Locale('de')`): the Create, Edit and Delete buttons (`Erstellen`, `Bearbeiten`, `Löschen`), Save (`Speichern`), the table footer (`Einträge pro Seite`, `1–8 von 8 Einträgen`, `8 Einträge`), the column menu, the pagination labels, and `Nicht verfügbar` where a custom field has no renderer registered. Archive and its confirmation dialog are tested too.

Wired to `BeakLocalizations` in the source: the sign-in, register and recovery screens and their errors, yes and no badges, relative timestamps, loading and retry states, the command bar, the list toolbar, the filter sheet and the saved-views dialog, relation attach and detach, the `Back` button, the undo button and the delete toast, the notification bell and the pending-actions banner, the not-found page, a generic sentence in place of the message of a `configuration`, `storage`, `internal` or `transport` failure, and the controls of a form: the save status and compare buttons, the draft buttons and the `Draft saved` line, the `Inspect form` button, the review and leave dialogs, the wizard's step buttons, the upload field and the gallery (with a screen-reader name for each picture and each row button), and the import view's field label, buttons, hints and progress lines.

### What is not

Everything in this table stays English in a German panel. It is what a sweep of the source found, so treat it as a list of the known gaps and not as a promise that nothing else is missing.

| Area | Stays English |
| --- | --- |
| Messages a form session writes itself | `Add at least 1 row.`, `Complete the related rows.`, `Complete the new related record.`, `Enter a valid amount.`, `Enter a valid number.`, `Choose Yes or No.` and `Choose an available option.` on attribute inputs, the parse errors of a semantic input (`Use hours:minutes:seconds, for example 2:30:00.`, `Must be valid JSON.`), the notices about a draft or a recovery snapshot that could not be stored, and `The file exceeds the limit of N bytes.` in the upload field. |
| Form controls | The option pickers' `Loading options`, `No matching options.`, `Retry options` and `Options` heading. The `Add`, `Edit`, `Remove` and `Apply` buttons of related-records tables, with their screen-reader names. `More actions`, `Pick a date`, and `From` and `To` on a date range. The `Edit` link of a form section, the default `Details` card title, `Create <label>` and `Create new` on a create-in-place picker, and `Select <field> first.`. `Not set` on a three-state boolean input, and its `Yes` and `No` unless the column sets `trueLabel` and `falseLabel`. The catalog input's `Variant` and `Catalog categories`, and its `Search catalog`, `Add` and `Default` defaults, which are parameters you can set. The form inspector behind the `Inspect form` button. |
| Import view | The default `title` of `BeakImportView` and `BeakBulkEditView` (`Import records`, `Review changes`), and the error messages the import writes itself, for example `Some import fields are not writable by your account.` and `Row N has already been saved. ...`. |
| Lists | The Export button (`BeakListExport.label` defaults to `Export`), the `All` option of a choice filter (`allLabel`), and the texts of an active filter chip (`From ...`, `Through ...`, `Active`). The semantic range control's `Custom` preset. |
| Blocks | `Select a message` in the inbox, `Get Started` on a plan without a `ctaField`, the default `label` of each module block, the summary truncation line, and the text the obers_ui modules draw themselves ([Module blocks](../blocks/module-blocks.md)). |
| Failures and words in code | The exception messages of domain failures (`errorMessage` shows those as written), the default titles of `BeakMaintenanceConfig`, the words `create` and `update` in the review dialog, and the model action runner's `This action is not permitted.` and `The outcome is not yet known...`. |

Not Beak's to translate: your text, the messages the server sends, and the CSV header, which is your column labels. A boolean in a CSV reads `Yes` and `No` unless its column sets `trueLabel` and `falseLabel`.

### Add a language

Subclass `BeakLocalizations`, override the getters you want, and install a delegate that returns your subclass. The test that proves it overrides one string:

```dart title="packages/beak_frontend/test/src/panel/beak_panel_localization_test.dart"
--8<-- "packages/beak_frontend/test/src/panel/beak_panel_localization_test.dart:frenchLocalizations"
```

Anything you do not override stays English, because the base class decides German by `locale.languageCode == 'de'` and treats every other language as English. Every member carries a doc comment; the class is the checklist. Then list the language on the panel:

```dart title="packages/beak_frontend/test/src/panel/beak_panel_localization_test.dart"
--8<-- "packages/beak_frontend/test/src/panel/beak_panel_localization_test.dart:frenchPanelLocale"
```

`supportedLocales` replaces the default list, so this panel speaks only French: add `Locale('en')` and `Locale('de')` back when it should still speak them. `locale:` pins the language. Leave it out and the platform's locale is matched against `supportedLocales`. Your own delegates go in the same list, ahead of Beak's, so an application label class and the framework strings live side by side.

### Around the gaps

| Gap | Today |
| --- | --- |
| Labels, titles and enum labels | Plain strings in the schema and the screens, compile-time constants for columns, so one build speaks one language. Write them in the panel's language. |
| Rule messages | A form in a German panel words the built-in column rules in German (`BeakLocalizations.validate`), keeping a rule's own `message:` such as `BeakPattern`'s. Record rules and the messages of server-side validation keep the text they were written with ([Validation rules](../reference/validation-rules.md)). |
| Hard-coded English in the import view, the form inspector or one of the form controls above | Nothing overrides it from outside. Accept English for that control, or build the screen from blocks. |
| A live language switch | A new `locale` is a new configuration. The panel builds a new router and dependency scope and lands on `/`. |
| Your own widgets | `BeakLocalizations.of(context)` and `BeakFormatting.of(context)`, as below. |

The shop's receivables card is a widget of the last kind. It takes loading, error and retry text from `BeakLocalizations`, formats the sum with the panel's policy, and owns its two sentences, which stay English:

```dart title="examples/clean_beak_config/lib/widgets/receivables_card.dart"
--8<-- "examples/clean_beak_config/lib/widgets/receivables_card.dart:receivablesStates"
```

## Rules and limits

- **Set `formatting:` explicitly.** Without it timestamps are UTC and plain numbers are unformatted, while semantic fields already use a default policy.
- **Screen and file can disagree.** The policy never sends the device's zone, so a panel on device time exports UTC unless `timeZoneOffsetMinutes` is set.
- **An offset is not a time zone.** There is no daylight saving and no IANA zone.
- **The locale does not choose patterns.** Write `datePattern` yourself.
- **`.formatted` on a semantic field formats the decoded value.** A `BeakDecimal` money field shown with `.formatted(BeakValueFormat.currency)` prints an amount of `1234.56`, not `123456`, in the currency its semantic names, exactly as it does without the override. A `number` format prints the decimal, not the integer units it is stored as. The shop's invoice list uses `.formatted(..., label: 'Amount due')` to relabel `total`. Use `.currency(minorUnits: true)` on a plain integer column that holds cents.
- **One empty value for screen and export.** Changing it changes both.
- **Formula-looking CSV cells change.** The exporter quotes commas, quotes and line breaks, and puts a `'` in front of a cell that starts with `=`, `+`, `-` or `@` (also behind leading spaces), so a spreadsheet reads it as text instead of running it. A cell that is only a number, such as `-5`, is left alone. That cell differs from what the screen shows, by one character.
- **English and German only.** Every other language falls back to English until you supply a subclass.
- **The messages a form session and the import view write themselves stay English** in a German panel; the import view's labels, buttons and hints are translated. The list toolbar, the filter sheet, the saved-views dialog and the record actions menu are translated, and so are built-in rule messages.
- **No test covers right-to-left languages.**

## Verify it

The policy, its JSON and the German table and delete flows have tests:

```console
$ cd packages/beak_core
$ dart test test/src/columns/beak_format_policy_test.dart test/src/columns/beak_format_policy_boundaries_test.dart
00:00 +12: All tests passed!
$ cd ../beak_frontend
$ flutter test --no-pub test/src/localization/beak_localizations_test.dart test/src/panel/beak_panel_localization_test.dart test/src/form/date_input_format_test.dart test/src/form/declarative_layout_and_formatting_test.dart
00:02 +28: All tests passed!
$ flutter test --no-pub test/src/table/beak_data_table_test.dart --plain-name "table chrome"
00:00 +2: All tests passed!
$ cd ../../examples/clean_beak_config
$ flutter test --no-pub test/shop_widget_test.dart --plain-name "exact euro prices"
00:01 +1: All tests passed!
```

To see the split yourself, change `locale: const Locale('en')` to `Locale('de')` in `examples/showcase/lib/main.dart`, restart, and open Specimens. The Create button, the table footer and the `Back` button on a form are German, the column headers are not, because they are your labels. Then set `useLocalTime: false` in the Aviary's `BeakFormatting`, open a specimen, and compare its `Hatched At` with the device-time value.

## Reference

| Symbol | Where | Notes |
| --- | --- | --- |
| `BeakFormatPolicy` | `beak_core` | The policy. `number`, `currency`, `percent`, `date`, `dateTime`, `time`, `format`, `exactDecimal`, `exactCurrency`, `calendarDate`, `clockTime`, `duration`, `fileSize`, `parseNumber`, `formatColumn`, `formatCell`, `toJson`, `fromJson`. |
| `BeakFormatting` | `beak_frontend` | The policy plus `of`, `maybeOf`, `toEditorDateTime`, `fromEditorDateTime`. |
| `BeakFormattingScope` | `beak_frontend` | Overrides the policy for a subtree. |
| `BeakValueFormat` | `beak_core` | `text`, `number`, `currency`, `date`, `dateTime`, `time`, `percent`. |
| `BeakFormattedField`, `.formatted`, `.currency` | `beak_frontend` | A display-only override on a typed field. |
| `BeakExportFormat` | `beak_core` | A per-field format in an export request: `format`, `minorUnits`, `scale`. |
| `BeakLocalizations` | `beak_frontend` | Over 160 strings and messages, `of`, `delegate`, `supportedLocales`, `english`. |
| `BeakPanelConfig.locale`, `.supportedLocales`, `.localizationsDelegates`, `.formatting` | `beak_frontend` | The panel's settings. All four are also on `copyWith`. |

Every parameter and its default is in [Panel options](../reference/panel-options.md#beakformatting).

## Continue reading

- [Semantic fields](../models/semantic-fields.md) money, percentages, units and durations, and how each is stored.
- [Export to CSV](../recipes/export-to-csv.md) the Export button, formatted and raw.
- [Tables and filters](../panel/tables-and-filters.md) where `.formatted` and `.currency` appear in a list.
- [Panel options](../reference/panel-options.md) every `BeakFormatting` and `BeakPanelConfig` parameter.
