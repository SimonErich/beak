# Rule cookbook

Every snippet was compiled and run in a project created with `beak create` at
Beak 0.9. The repository's shop example (`examples/clean_beak_config` at
https://github.com/SimonErich/beak) shows the same shapes at full size:
`resources/invoices/models/invoice.dart` (rules, behavior, actions),
`resources/orders/models/order_item.dart` (suggested values, `BeakRequiredIf`,
`BeakExists` with `BeakFieldMatch`) and `test/shop_api_test.dart`.

## One schema class with all four kinds

`lib/resources/tickets/models/ticket.dart`

```dart
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../../suppliers/models/supplier.dart';

part 'ticket.beak.dart';

/// Where a ticket is in its life.
enum TicketStatus {
  /// Being worked on.
  open,

  /// Finished; the record is locked.
  closed,
}

/// The ticket's business commands, each declared once and referenced by object.
abstract final class TicketActions {
  /// Closes an open ticket.
  static final close = BeakModelAction(
    name: 'close',
    label: 'Close ticket',
    availableWhen: (record) =>
        TicketModel.status.readFrom(record) == TicketStatus.open,
    values: [
      BeakValueBehavior.derived(
        field: TicketModel.status,
        resolve: (_) => TicketStatus.closed,
      ),
    ],
  );
}

/// A support ticket.
@Resource(timestamps: true)
final class Ticket extends BeakSchema {
  /// Cross-field and relationship rules, checked in the form and again on the
  /// server.
  static List<BeakRecordRule> get validationRules => [
    BeakRequiredIf(
      TicketModel.resolution,
      when: BeakWhen.equals(TicketModel.status, TicketStatus.closed),
      message: 'Say how it was resolved.',
    ),
    BeakExists(
      TicketModel.supplierId,
      SupplierModel.id,
      where: SupplierModel.active.eq(true),
    ),
  ];

  /// Values that follow other fields, and the states that lock the record.
  static BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior.initial(
        field: TicketModel.openedNote,
        resolve: (_) => 'New ticket',
      ),
      BeakValueBehavior.snapshot(
        field: TicketModel.closedNote,
        onAction: TicketActions.close,
        dependencies: [TicketModel.title],
        resolve: (state) => 'Closed: ${state.read(TicketModel.title)}',
      ),
    ],
    actions: [TicketActions.close],
    editableWhen: (record) =>
        (TicketModel.status.readFrom(record) ?? TicketStatus.open) ==
        TicketStatus.open,
    deletableWhen: (_) => false,
  );

  /// What the ticket is about.
  @Display()
  @Column(searchable: true)
  late final String title;

  /// Where it stands.
  @Column(defaultValue: TicketStatus.open, filterable: true)
  late final TicketStatus status;

  /// How it was resolved.
  late final String? resolution;

  /// Note written when the ticket is created.
  late final String? openedNote;

  /// Note frozen when the ticket is closed.
  late final String? closedNote;

  /// Who handles it; only active suppliers are eligible.
  @BelongsTo(inverse: false)
  late final Supplier? supplier;
}
```

The four value lifecycles: `initial` supplies a value on creation when omitted;
`suggested` follows its `dependencies` until the user overrides it; `derived` is
server-owned and callers cannot assign it; `snapshot` captures a value when its
`onAction` runs and keeps it. `dependencies` name every field `resolve` reads,
which orders the evaluation and loads related records. `BeakFieldMatch(target:
Other.field, source: This.field)` in `matching:` requires the selected record's
field to equal this record's field (for example the profile must belong to the
order's customer).

## Unit test

```dart
test('a supplier needs an email or a phone number', () {
  final errors = Supplier.validationRules.first.validate(
    BeakRecord(values: {SupplierModel.name.key: SupplierModel.name.encode('Acme')}),
  );
  expect(errors[SupplierModel.email.key], ['Give an email or a phone number.']);
});
```

`validate` covers the synchronous rules. `BeakExists` and `BeakUnique` need
stored data and are proven in the server test.

## Server test

The server half runs Beak's real host over an in-memory SQLite database and
talks to it with the same client the panel uses. Needs only `flutter_test` and
the project's generated `beak/server.g.dart`.

```dart
import 'dart:io';

import 'package:beak/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop/beak/server.g.dart';
import 'package:shop/resources/tickets/models/ticket.dart';

void main() {
  late DatabaseAdapter adapter;
  late HttpServer server;
  late BeakClient client;

  setUp(() async {
    final probe = await ServerSocket.bind('127.0.0.1', 0);
    final port = probe.port;
    await probe.close();
    final host = beakHost(
      environment: {
        'DATABASE_URL': 'sqlite::memory:',
        'HOST': '127.0.0.1',
        'PORT': '$port',
        'BEAK_STORAGE_DRIVER': 'none',
      },
    );
    adapter = adapterFromUrl(host.config.databaseUrl);
    await adapter.connect();
    await MigrationRunner(
      adapter: adapter,
      migrations: host.migrations,
    ).migrate();
    server = await host.buildServer(adapter: adapter).start();
    client = BeakClient(baseUrl: 'http://127.0.0.1:$port');
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
    await adapter.disconnect();
    await Worm.reset();
  });
  // tests go here
}
```

A plain rule (no behavior on the model) is refused on a direct write:

```dart
final record = BeakRecord(
  values: {
    SupplierModel.name.key: SupplierModel.name.encode('Acme'),
    SupplierModel.active.key: SupplierModel.active.encode(true),
  },
);
await expectLater(
  client.create(const SupplierModel().table, record),
  throwsA(
    isA<BeakValidationException>().having(
      (error) => error.fieldErrors[SupplierModel.email.key],
      'email errors',
      ['Give an email or a phone number.'],
    ),
  ),
);
```

A model with behavior is written by graph commit, and an action rides on the plan:

```dart
const draft = BeakRecordRef.draft('tickets', 'ticket');
final created = await client.commit(
  BeakSavePlan(
    saveId: 'create-ticket',
    root: draft,
    operations: [
      BeakSaveOperation(
        id: 'ticket',
        kind: BeakSaveOperationKind.create,
        target: draft,
        values: BeakRecord(
          values: {TicketModel.title.key: TicketModel.title.encode('Late delivery')},
        ),
      ),
    ],
  ),
);
final root = BeakRecordRef.existing('tickets', created.identities['ticket']!);

BeakSavePlan close(String saveId, BeakRecord values) => BeakSavePlan(
  saveId: saveId,
  root: root,
  action: TicketActions.close.name,
  operations: [
    BeakSaveOperation(
      id: 'ticket',
      kind: BeakSaveOperationKind.update,
      target: root,
      values: values,
    ),
  ],
);

expect((await client.commit(close('close-1', const BeakRecord(values: {})))).complete, isFalse);
final closed = await client.commit(
  close('close-2', BeakRecord(values: {
    TicketModel.resolution.key: TicketModel.resolution.encode('Refunded'),
  })),
);
expect(closed.complete, isTrue);
expect(TicketModel.status.readFrom(closed.rootRecord!), TicketStatus.closed);
expect(TicketModel.closedNote.readFrom(closed.rootRecord!), 'Closed: Late delivery');
```

The table name `'tickets'` in `BeakRecordRef` is the physical table; take it from
`const TicketModel().table` when the test allows. A failed plan returns
`complete == false` with an `outcomes` list carrying the error and field errors;
print `result.toJson()` in the `reason:` of the expectation while developing.
Reusing a `saveId` replays the stored result instead of running twice.

## Widget test

```dart
testWidgets('the form shows the rule message', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final registry = buildBeakRegistry();
  BeakFormSession? session;
  await tester.pumpWidget(
    OiApp(
      theme: OiThemeData.light(),
      home: BeakConfiguredForm(
        model: const SupplierModel(),
        registry: registry,
        dataSource: InMemoryBeakDataSource(registry: registry),
        mode: BeakFormMode.create,
        onSession: (value) => session = value,
      ),
    ),
  );
  await tester.pumpAndSettle();
  session!.root.set(SupplierModel.name, 'Acme');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
  expect(find.text('Give an email or a phone number.'), findsWidgets);
});
```

Imports: `package:beak/panel.dart`, `package:beak/testing.dart`,
`package:beak/ui.dart`, `package:flutter/widgets.dart`,
`package:flutter_test/flutter_test.dart`, the project's `beak/registry.g.dart`
and the schema file.

## A rule that needs a server preparer

When a rule spans several records (totals across lines, tax allocation), write a
`BeakSavePlanPreparer` and pass it to `defaults.build(preparePlan: ...,
graphOnly: const [InvoiceModel(), InvoiceItemModel()])` in `lib/server.dart`
(`beak eject server` writes the file). Throw `BeakValidationException` with
field paths to reject. Read the shop's `lib/domain/shop_graph_preparer.dart` and
`.dart_tool/beak/docs/backend/graph-business-rules.md`.
