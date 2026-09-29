---
title: Shaping the panel
description: Choose table columns, add typed filters and search, set the brand and money formatting, and add an overview page and a workspace page built from blocks.
type: tutorial
audience: [beginner]
status: stable
---

# Shaping the panel

The panel you have works, and it looks like every Beak panel on its first day. This chapter changes what it shows: which columns a table has, which filters sit above it, what the search finds, how money reads, and two extra pages that are not lists at all.

## What you'll build

- a Products table with a Category column, and three filters above it,
- a command-bar search that finds a product by its category's name and a category by its attributes,
- a brand colour and a money format for the whole panel,
- a Shop overview page with a live product count, and an Operations page with a category import.

## Before you start

You need chapter 4 finished, with the seeded data in place. Stop `beak dev` while you edit; you restart it at the end.

Nothing here touches the database, so there is no migration in this chapter.

## Shape the resource

Three additions to `ProductResource`, in one file: which columns the list shows, which filters sit above it, and what the search reaches. The identity and the form screen are unchanged from chapter 3:

```dart title="lib/resources/products/product_resource.dart"
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'models/product.dart';
import 'screens/product_form.dart';

/// Catalog management.
final class ProductResource extends BeakResource {
  /// Creates the products section.
  ProductResource()
    : super(
        --8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:ProductResourceIdentity"
        globalSearchSources: [
          --8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:ProductSearchOwnFields"
          --8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:ProductSearchCategory"
        ],
        --8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:listProductFilters"
        screens: [
          --8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:listProductFields"
          BeakFormScreen(
            --8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:ProductFormLayout"
          ),
        ],
      );
}
```

### The columns

Without a `screens:` entry for the list, Beak shows every scalar column of the model. A `BeakTableScreen` says which ones instead, and in what order. It replaces only the list, and the form screen from chapter 3 stays where it is.

In the table screen's field list, the third entry is the interesting one. `ProductModel.category.name` follows the `category` link to the category's name, and `.formatted(BeakValueFormat.text, label: 'Category')` gives the column a heading of its own, so it does not read `Name` twice. Beak loads the category with the page, one query and not one per row. A related column displays but cannot be sorted, because a sort names a column of the listed model.

### The filters

Filters are typed too. Each is a method on a generated field, and the method you pick says what control appears:

| Field | Filter | Control |
| --- | --- | --- |
| `ProductModel.category` | `relationFilter()` | A picker of categories |
| `ProductModel.active` | `boolFilter(label: 'Available')` | Yes or no |
| `ProductModel.price` | `rangeFilter(label: 'Net price')` | Two inputs, from and to, in the price's currency |

### The search

`globalSearchSources` lists the fields that the command bar searches for this resource. It can reach through a link: `ProductModel.category.name` is in there, so a search for `coffee` finds the product whose category is called that, even though the word is not in the product.

The shop's product resource searches more: image captions, attribute values and variant SKUs, which your project does not have. It also has bulk actions and record duplication. The three ideas are the same.

The category resource gets the same treatment. Its search reaches into its own children, the attribute definitions from chapter 3, so typing `level` finds the category that defines a "Roast level":

```dart title="lib/resources/categories/category_resource.dart"
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'models/category.dart';
import 'models/category_attribute.dart';
import 'screens/category_form.dart';

/// Catalog organization and reusable attribute definitions.
final class CategoryResource extends BeakResource {
  /// Creates the categories section.
  CategoryResource()
    : super(
        --8<-- "examples/clean_beak_config/lib/resources/categories/category_resource.dart:CategoryIdentity"
        --8<-- "examples/clean_beak_config/lib/resources/categories/category_resource.dart:CategorySearchAndFilters"
        screens: [
          --8<-- "examples/clean_beak_config/lib/resources/categories/category_resource.dart:CategoryTableScreen"
          --8<-- "examples/clean_beak_config/lib/resources/categories/category_resource.dart:CategoryFormScreen"
        ],
      );
}
```

## Two pages that are not lists

A resource gets a list, a form and a detail page. Anything else is a `BeakScreen`: a route, a title, an icon and a body built from blocks. The overview is the first one.

```dart title="lib/overview.dart"
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import 'resources/products/models/product.dart';

/// Live overview assembled entirely from Beak's data blocks.
BeakScreen shopOverview() => BeakScreen(
  path: '/',
  title: 'Shop overview',
  icon: const BeakIconToken(OiIcons.layoutDashboard),
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [
      const BeakTextBlock('Your catalog at a glance.'),
      BeakGridBlock(
        minColumnWidthInPixels: 220,
        children: [
          --8<-- "examples/clean_beak_config/lib/overview.dart:overviewProductsMetric"
        ],
      ),
    ],
  ),
);
```

`BeakMetricBlock` takes an aggregate, here `const ProductModel().count()`, and shows it as a card. The number is a query, not a constant, and it fetches again after a save or delete made in the panel. The shop's overview has metrics for orders, invoices and stock, plus tables and text blocks. Yours has one card, and adding the next takes one more entry in the grid.

The second page is a workspace for tasks that do not belong on a list. The shop's has an import for categories, and it works against your `CategoryModel` as it is:

```dart title="lib/operations.dart"
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import 'resources/categories/models/category.dart';

/// A custom operations route sharing ordinary resource queries and mutations.
BeakScreen shopOperations() => BeakScreen(
  path: '/operations',
  title: 'Operations',
  navigationGroup: 'Workspace',
  icon: const BeakIconToken(OiIcons.listChecks),
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [
      --8<-- "examples/clean_beak_config/lib/operations.dart:categoryImportBlock"
    ],
  ),
);
```

`navigationGroup: 'Workspace'` puts the page under its own heading in the sidebar. The overview names no group, so it follows the resources.

## Give the panel a look

Brand and formatting are arguments of `BeakPanel`, so they belong in `main.dart`. Register the pages there too:

```dart title="lib/main.dart"
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';

import 'operations.dart';
import 'overview.dart';
import 'resources/categories/category_resource.dart';
import 'resources/products/product_resource.dart';

/// Boots the panel.
void main() => runApp(buildPanel());

/// The panel, and every resource it shows.
///
/// This file is yours: `beak prepare` never rewrites it, so add each
/// resource class you write to `resources`.
///
/// [dataSource] replaces the HTTP-backed source, so a widget test
/// can pump this exact panel against an in-memory one.
BeakPanel buildPanel({BeakDataSource? dataSource}) => BeakPanel(
  title: 'Shop',
  --8<-- "examples/clean_beak_config/lib/main.dart:shopBranding"
  pages: [shopOverview(), shopOperations()],
  resources: [ProductResource(), CategoryResource()],
  dataSource: dataSource,
);
```

`theme` and `darkTheme` are made from one brand colour each, and the panel follows the system setting to choose between them. `locale` is the language of the panel's own text. `formatting` is separate on purpose: it says how numbers, currency and dates read, and here that is Austrian German (`12,50`, `dd.MM.yyyy`) around an English interface.

## Run it

```bash
beak dev
```

```bash
flutter run -d chrome
```

Open Products. The table has Name, Sku, Category, Net price and Active, and the net price now reads `€ 12,50`. Above the table sit three dashed chips, `Category`, `Available` and `Net price`. Press the last one and two inputs open, one for the lowest price and one for the highest, each with `EUR` on the right. Type `20` in the lower bound and the table narrows to the products at or above twenty euros.

Press Ctrl-K, or Cmd-K on a Mac, or the magnifier in the top bar. A dialog called Go to opens. Type `coffee`. It lists the Ethiopia product, which contains no such word but sits in the `Specialty coffee` category, and both categories, one through its name and one through its description. That is `globalSearchSources` at work.

Open Shop overview, which lives at the panel's home route `/`. It shows a Products card with the current count. Create a product, come back, and the number has caught up. Blocks refetch after a write made through this panel; they cannot see a colleague's write in another browser.

Open Operations. The category import asks for CSV with the headers `Name` and `Description`, previews the records, and imports them one by one. The page says so itself: records save individually, and the ones that succeeded stay saved if a later one fails.

!!! note "What just happened"
    - Every choice was a typed reference on a resource: a field for a column, a method for a filter, a path for a search. Rename `active` and every place that mentions it fails to compile.
    - A filter, a sort or a search is a value in the query body from chapter 4. The table asks the server for the page you see, with the filters applied.
    - The overview is made of the same blocks you could embed anywhere. A block queries and mutates through the panel's data source, so it stays in step with the tables around it.
    - Formatting changed how money reads without touching the stored value or the API.

!!! question "What this skipped"
    - Columns, sorts, scopes and filter kinds: [Tables and filters](../panel/tables-and-filters.md).
    - Saved views, presets and a search field on the list: [Composed lists](../panel/composed-lists.md).
    - Every block, chart and summary: [Blocks](../blocks/index.md), and the page on [dashboards](../panel/dashboards.md).
    - Forms as tabs, wizards or read-only documents: [Form screens](../forms/form-screens.md) and [Multi-step forms](../forms/multi-step-forms.md).
    - Your own widget in a page: below.

## A widget of your own

Blocks cover the common cases. When they do not, `BeakWidgetBlock` embeds any widget, and `beakDependencies(context)` hands that widget the same data source the rest of the panel uses. The shop's receivables card is the working example. It reads invoices, which your project does not have, so this is a look and not a step:

```dart
--8<-- "examples/clean_beak_config/lib/widgets/receivables_card.dart:receivablesData"
```

Three things are in there. The widget takes the panel's `BeakDataSource` from the scope, `useBeakDataRevision` re-runs the request when a save or delete touches the `invoices` table, and `BeakResourceRepository.run` turns a thrown error into a value, so the widget shows a message and a retry button instead of crashing. [Custom screens](../panel/custom-screens.md) covers the pattern.

## Checkpoint

```bash
beak doctor
```

```console
$ beak doctor
  OK   project depends on Beak
  OK   beak.yaml parses
  OK   discovered 3 models · 2 resource classes · 0 screens · 0 overrides
  OK   lib/main.dart lists every resource class
  OK   generated files up to date
  OK   every model has a migration
  ...
All checks passed.
```

The panel now has a brand, a money format, table columns you chose, three filters, a search that follows links, an overview and a workspace page. The `0 screens` in `beak doctor` counts `BeakScreen` declarations under `lib/screens/`, which is where the generated panel looks for pages. Yours live beside `main.dart` and your `pages:` list registers them by hand, which is the authored way.

Next: who is allowed to do any of this, and how to prove it stays that way.

## Continue reading

- [Auth, tests, and shipping](06-auth-tests-and-shipping.md): policies, tests for the API and the panel, and a build you can deploy.
- [Tables and filters](../panel/tables-and-filters.md): everything a list can be told.
- [Dashboards](../panel/dashboards.md): more blocks for pages like the overview.
