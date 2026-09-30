# A schema class and its resource

Verified against a project created with `beak create` at Beak 0.9. Names are
examples; every field reference below exists only because the schema declares it.

## The schema class

`lib/resources/suppliers/models/supplier.dart`

```dart
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../../companies/models/company.dart';

part 'supplier.beak.dart';

/// A supplier.
@Resource(timestamps: true)
final class Supplier extends BeakSchema {
  /// The supplier's name.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Email.
  @Column(searchable: true)
  late final String? email;

  /// Phone.
  @Column(searchable: true)
  late final String? phone;

  /// Whether the supplier is used.
  @Column(filterable: true)
  late final bool active;

  /// The company this supplier belongs to.
  @BelongsTo(inverse: false)
  late final Company? company;
}
```

Notes: `@Resource(timestamps: true)` adds `created_at` and `updated_at`.
`softDeletes: true` adds `deleted_at` and turns deletes into markers.
`@BelongsTo` on a nullable field is optional, on a non-nullable field it is
required. `inverse: false` skips the back-reference (`Company.suppliers`) on
the other side.

## The resource

`lib/resources/suppliers/supplier_resource.dart`

```dart
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import 'models/supplier.dart';

/// How the panel presents suppliers.
final class SupplierResource extends BeakResource {
  /// Creates the suppliers resource.
  SupplierResource()
    : super(
        model: const SupplierModel(),
        title: 'Suppliers',
        icon: const BeakIconToken(OiIcons.truck),
        navigationGroup: 'Purchasing',
        filters: [
          SupplierModel.name.textFilter(),
          SupplierModel.active.boolFilter(),
          SupplierModel.company.relationFilter(),
        ],
        screens: [
          BeakTableScreen(
            fields: [
              SupplierModel.name,
              SupplierModel.company.name,
              SupplierModel.active,
            ],
          ),
          BeakFormScreen(
            roles: const {
              BeakScreenRole.read,
              BeakScreenRole.create,
              BeakScreenRole.edit,
            },
            layout: BeakFormLayout(
              children: [
                BeakCard(
                  title: 'Contact',
                  children: [
                    SupplierModel.name.inputText(),
                    SupplierModel.email.inputText(),
                    SupplierModel.phone.inputText(),
                  ],
                ),
                BeakCard(
                  title: 'Status',
                  children: [
                    SupplierModel.company.inputCombobox(),
                    SupplierModel.active.inputToggle(),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
}
```

## Choices

- `make:resource` writes `const SupplierResource() : super(model:, icon:)`.
  Adding filters or screens built from function calls makes the constructor
  non-const; drop the `const`.
- Omit `screens` and Beak generates the table and form from the model. Add
  `BeakTableScreen` or `BeakFormScreen` only to arrange something.
- One `BeakFormScreen` with `read`, `create` and `edit` roles gives a detail
  page that switches to editing in place.
- Tabs, wizards, owned-child tables, galleries, custom pages and custom inputs
  belong to `beak-frontend-build-screens`.
- `beak eject resource <table>` writes a resource class for a model that has
  none, for example after `beak introspect`.
