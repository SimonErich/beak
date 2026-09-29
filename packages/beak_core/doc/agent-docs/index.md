# Beak

> Beak builds an admin panel, a REST API and migrations for Dart and Flutter from annotated schema classes and declarative resources.

Beak builds an admin panel, a REST API and migrations for Dart and Flutter from annotated schema classes and declarative resources. You write the schema, the resource and the few screens that differ from the default. Beak handles loading, typed inputs, validation, relationship drafts, saving and refresh.

```dart title="examples/clean_beak_config/lib/main.dart"
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';

import 'overview.dart';
import 'operations.dart';
import 'resources/fulfillment/fulfillment_policy_resource.dart';
import 'resources/categories/category_resource.dart';
import 'resources/companies/company_resource.dart';
import 'resources/invoices/invoice_resource.dart';
import 'resources/orders/order_resource.dart';
import 'resources/products/product_resource.dart';
import 'resources/products/variant_resource.dart';
import 'resources/profiles/profile_resource.dart';
import 'resources/taxes/tax_rate_resource.dart';
import 'resources/users/user_resource.dart';
import 'resources/vouchers/voucher_resource.dart';

/// Resource registration and one formatting policy are the complete panel setup.
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

The maintained shop includes products and variants, category-defined attributes, orders, invoices with taxes and vouchers, draft recovery, imports and custom operational widgets. The minimal quickstart uses the same contracts.

## Which page to read

| You want to… | Read | For |
| --- | --- | --- |
| Try Beak on a new project | [Installation](start-here/installation.md), then [Quickstart](start-here/quickstart.md) | Beginners |
| Learn Beak one chapter at a time | [Tutorial](tutorial/index.md) | Beginners |
| Decide whether Beak fits | [What is Beak?](start-here/what-is-beak.md), [Why Beak?](start-here/why-beak.md) and [Examples](examples/index.md) | Beginners and experts |
| See where every file lives | [Project structure](start-here/project-structure.md), then [Two ways to boot a panel](start-here/generated-or-authored.md) | Beginners and agents |
| Start from something that already exists | [Choose your path](start-here/paths/index.md) | Beginners, experts and agents |
| Move from an older version | [Upgrading](start-here/upgrading.md) | Experts and agents |
| Use Beak with Serverpod | [Serverpod](serverpod/index.md) | Beginners, experts and agents |
| Look up an API | [Reference](reference/index.md), then [Cheatsheet](reference/cheatsheet.md) | Experts and agents |
| Point a coding agent at Beak | [AI directory](ai/index.md) | Agents |
| Change Beak itself | [Contributing](contributing/index.md) | Contributors |

## Continue reading

- [Quickstart](start-here/quickstart.md): Generate and run the minimal maintained Beak application.
- [Tutorial](tutorial/index.md): Learn the declarative resource model through the maintained shop example.
- [Reference](reference/index.md): Look up any annotation, field type, rule, block, option, REST route, CLI command or exception.
