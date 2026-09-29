# Theming basics

> Set light and dark themes once at the panel boundary.

Pass `theme` and `darkTheme` to `BeakPanel`, or configure them through `BeakPanelConfig`. Beak uses Obers UI widgets and tokens throughout the shell, forms and blocks. The theme controller exposes the current mode to custom widgets.

Use semantic colors and typography from the nearest theme rather than hardcoded values. Set data formatting separately through `BeakFormatting`; a color theme should not alter currency or date meaning.

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

## Continue reading

- [Colors and tokens](colors-and-tokens.md)
- [Typography and icons](typography-and-icons.md)
