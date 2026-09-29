# Transactional business rules

> Prepare a typed candidate graph while preserving validation, authorization and idempotency.

Shared model behavior runs automatically at the graph boundary. Use a server graph preparer when domain calculations span several records, such as invoice tax allocation or category-defined attribute reconciliation.

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

## Candidate graph

`BeakCandidateGraph` materializes the submitted changes with current records and relationships. It supplies typed nodes, original values, relationship traversal and staging helpers, so domain code does not reconstruct temporary identities and ownership maps. The shop preparer uses it for invoice snapshots and totals, product attributes and variant uniqueness.

A preparer receives the submitted plan, the transaction-bound data source and authenticated principal. Keep the original save identity, root and submitted operation identities. Additional operations still pass resource, row, ownership and validation checks. Use the supplied source for reads to keep calculation and persistence in the same transaction.

Use `graph.link(node, OrderModel.budgetAccount, ledger.ref)` to set a typed
belongs-to relationship. It preserves request-local identities, so a server
calculation can link a new order to a ledger created in the same atomic plan
without inventing an ID or losing its dependency ordering. Pass `null` to unlink.
The node must be live, the field must belong to its root model, and a draft target
must have a create operation in the plan. Generated links retain the original
revision guard and undergo normal commit authorization and validation.

## Revision guards and unchanged rows

Graph updates and deletes accept `expectedUpdatedAt`. The actual mutation uses
the exact stored timestamp, even when a browser can represent only milliseconds.
Unchanged updates retain their timestamps and snapshots while still returning
applied receipts; guarded no-ops keep a conditional SQL write as the race check.

Some engines report changed rows instead of matched rows. When an unchanged
conditional update returns zero, Beak only accepts a match from the explicit
`CurrentReadCapable` adapter contract. MySQL implements this on the active
connection with `SELECT ... FOR UPDATE`, using the same primary key, exact
revision and soft-delete visibility conditions. A normal snapshot read cannot
replace that check; InnoDB locking reads observe current records and keep locks
until the transaction finishes. See the [MySQL locking-read documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-locking-reads.html).

## Failure and replay

Throw `BeakValidationException` with field paths to reject a candidate. Atomic sources roll back the graph and return an unapplied receipt. The receipt fingerprint covers the original request; a confirmed replay returns the previous result without recalculating against a changed catalog. Reusing a save identity with different content is rejected.

The server checks model edit and delete guards against stored baselines. Owned-child changes also respect their parent's lifecycle. Direct CRUD cannot bypass models that require authoritative behavior. `graphOnlyTables` can additionally require graph mutation for application-specific preparers; read, query and search routes remain available.

Adapters without the required transaction or model-behavior capability reject unsupported saves explicitly. External effects such as email, payments and webhooks belong outside the transaction; use an application outbox when they must follow a successful commit.

## Continue reading

- [Model behavior](../models/behavior.md)
- [Auth and policies](auth-and-policies.md)
