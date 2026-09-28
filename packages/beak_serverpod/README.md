# beak_serverpod

Use existing generated Serverpod Dart models and endpoints in a Beak frontend.
Serverpod owns authentication, authorization, business operations and persistence.
This bridge invokes the authenticated client; it never opens a database connection,
uses Worm for persistence, or exposes arbitrary tables.

## Generated resource path

Select read models in [beak_serverpod_generator](../beak_serverpod_generator/README.md).
It emits typed descriptors, command codecs and a model with its own data source:

```dart
final model = AdminUserDtoResource(
  client: client,
  resource: 'users',
  primaryKey: AdminUserDtoFields.accountId,
  columns: [
    AdminUserDtoFields.accountFirstName.column(
      l10n.firstName,
      options: const ServerpodColumnOptions(
        visibleOn: {BeakContext.table, BeakContext.detail},
        searchable: true,
        sortable: true,
      ),
    ),
  ],
  permissions: BeakPermissions({
    BeakOperation.read: () => account.canReadUsers,
    BeakOperation.update: () => account.canEditUsers,
  }),
);
```

Pass this model to `BeakResource(model: model, ...)`. The panel discovers
`model.dataSource`, command form metadata and operation capabilities; no resource
repository, source registration or fetch implementation is required. Configure
known domain-to-Beak exception mapping once on the panel. Every backend endpoint
must still authorize the operation; client permissions only control presentation.

The generated model calls compatible list/get/create/update/archive operations,
translates typed query fields and preserves paging totals. Capabilities reflect
which writes were actually bound. A custom create/edit screen can implement a
workflow whose result differs from the generic record shape.

## Presentation and commands

Generated `Fields` expose `.column(label, options: ...)`, `.get(entity)`,
`.read(record)` and `.readRequired(record)`. Column types and nullability come from
the original Dart model. Options control exposure, sorting, searching, filtering,
validation and enum labels. Read columns default to detail-only.

Create/edit forms use their discovered command DTOs automatically, with generated
enum-slot pools sized to the command rather than the default 32-field pool. Labels and enum
labels inherit from an exact or uniquely matching read-column leaf. Use typed
`createLabels` / `editLabels` maps for password, relation IDs, ambiguous fields or
other command-only labels. Field controls remain frontend configuration: scalar
collections need an explicit list/choice control, and an empty list is valid
unless a domain rule forbids it. Commands with required nullable fields submit a
complete record; explicit null clears a value, omission is a validation error.

For a domain projection, the generated static `editInput` maps every compatible,
unique scalar leaf and requires typed parameters only for unresolved values:

```dart
editValues: (value) => AdminUserDtoResource.editInput(
  value,
  email: value.profile?.email ?? '', // Deliberate application policy.
  roleIds: [
    for (final assignment in value.account.roleAssignments ?? [])
      assignment.roleId,
  ],
),
```

The generator never invents a nonnull email or converts related objects into IDs.
Adding a compatible property to the source models regenerates this projection.
An unresolved new property becomes a required helper parameter. Generated relation
references reconstruct typed objects from complete loaded records for custom
presentation; they do not enable relation writes.

## Explicit exceptions

Generated constructors accept typed query/get/create/update/archive overrides for
compatible discovered operations, plus form-model overrides, a typed sort-field
map, page-origin override, and a live locale callback when required by the endpoint.
`onChanged` runs after successful writes for host refresh; it is not part of the
server transaction. Ordinary delete invokes the bound archive/delete endpoint.
Restore, force-delete and relation attach/detach are never inferred.

For a contract outside the generator's documented conventions, compose
`ServerpodResource<Entity, Id, CreateInput, UpdateInput>` directly with generated
codecs and typed callbacks. It is also a `BeakModel` with a stable data source.
Use `ServerpodModel` for its selected presentation metadata. `ServerpodDataSource`
is available for custom dispatch, but standard panels need no separate registry.
Edit loading crosses the same exception boundary as other data operations.

UUID route strings and integer IDs decode to their declared type before an
endpoint call. Unsupported queries and unbound operations fail explicitly rather
than dropping constraints or reporting success. The bridge supports conjunctions
of allowlisted equality filters, one declared sort and endpoint search; custom
range predicates or relations require an explicit query override.

Run `dart test` and `dart analyze` in this package.
