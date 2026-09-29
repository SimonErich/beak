# Auth and policies

> Enforce account, row, action and field access on the server.

The backend authenticates requests before evaluating resource policies. Presentation controls can hide unavailable operations, but every mutation and query still passes through the server's policy boundary.

## Resource and row access

`BeakPolicy` controls view, create, update and delete decisions. `BeakRowPolicy` adds trusted row scopes. Those scopes apply to ordinary reads, relationships, search, aggregates and graph operations. Use scopes for tenant isolation and record-level visibility; loading a record through another resource does not grant access to it.

The shop supplies its server configuration and graph policy in one place:

```dart title="examples/clean_beak_config/lib/server.dart"
import 'package:beak/server.dart';

import 'domain/shop_graph_preparer.dart';
import 'resources/categories/models/category_attribute.dart';
import 'resources/invoices/models/invoice.dart';
import 'resources/invoices/models/invoice_item.dart';
import 'resources/invoices/models/invoice_voucher.dart';
import 'resources/orders/models/order.dart';
import 'resources/orders/models/order_item.dart';
import 'resources/products/models/product.dart';
import 'resources/products/models/product_attribute.dart';
import 'resources/products/models/product_variant.dart';
import 'resources/products/models/variant_attribute.dart';
import 'resources/taxes/models/tax_rate.dart';
import 'resources/vouchers/models/voucher.dart';

/// Adds the example's transactional shop invariants to the generated host.
BeakServer beakServer(BeakServerDefaults defaults) => defaults.build(
  preparePlan: ShopGraphPreparer(defaults.registry).prepare,
  graphOnly: const [
    OrderModel(),
    OrderItemModel(),
    InvoiceModel(),
    InvoiceItemModel(),
    InvoiceVoucherModel(),
    ProductModel(),
    ProductVariantModel(),
    VariantAttributeModel(),
    ProductAttributeModel(),
    CategoryAttributeModel(),
    VoucherModel(),
    TaxRateModel(),
  ],
);
```

## Field access

Implement `BeakFieldPolicy` alongside the resource policy. `canReadField` and `canWriteField` receive the principal, table and field key. These decisions are principal/resource scoped; row visibility belongs in row policies.

Protected values are removed from response records and eagerly loaded relationships. Client filters, sorting, related paths and aggregates cannot reference unreadable fields. Search skips protected labels and searchable values, and CSV exports omit unreadable columns. Trusted server row scopes may still depend on protected fields.

Write checks apply to original supplied input before behavior or graph preparation. This lets trusted calculations produce server-owned values while rejecting caller attempts to assign protected fields. Returned commit and recovery receipts are redacted; stored receipts retain the full result for subsequent authorization and recovery. Upload operations check field access as well as resource access.

Relationship aliases and physical foreign keys share the same boundary. A
belongs-to write must allow both its alias and foreign key, including when the
caller submits only the scalar foreign key. Inverse has-many/has-one writes
also require the child's foreign key and matching belongs-to alias, plus child
update permission. Related identities must be visible under their resource and
row policies. Reads and query traversal check the relationship alias and its
linking foreign key, including the child foreign key for inverse relationships.
The capability response applies these same checks.

Write-only resources return no readable record values. Commit and recovery
responses also withhold resolved identities when the affected resource cannot
be viewed or its primary key is unreadable. Durable receipts keep the complete
server result and are redacted again under the current policy on recovery.

`GET /api/<table>/capabilities` returns field allowlists and `executableActions` for create; `?id=<identity>` resolves update access after checking row visibility. The HTTP source implements `BeakCapabilityDataSource`, so configured forms can remove unreadable inputs and disable unwritable ones. Adapters can implement the same optional interface. The action allowlist applies resource create/update permission, `BeakActionPolicy`, and `allowOnCreate`. It does not evaluate workflow state: the action’s availability predicate is a separate condition. Capabilities improve presentation; policy enforcement is still mandatory at the write boundary.

## Business actions

`BeakActionPolicy` can restrict named model actions independently of general update permission. Lifecycle guards and action availability remain additional checks. Avoid using a lifecycle predicate as a replacement for user authorization.

Storage visibility is a separate concern. A public object URL remains public after it has been shared; use storage delivery appropriate to your application's access requirements.

## Continue reading

- [Transactional business rules](graph-business-rules.md)
- [Actions](../panel/actions.md)
