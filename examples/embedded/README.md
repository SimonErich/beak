# Beak, embedded

Beak is not all-or-nothing. This example is an application that already
exists — its own server, its own Flutter app, its own auth — that adopts Beak
for part of its admin surface.

Four things it shows, each of which the other examples do not:

**1. Beak mounted inside an existing Shelf pipeline.** `bin/host.dart` builds
its own `Router`, keeps its own routes, and mounts `BeakServer.handler` under
`/admin` behind its own API-key middleware. Beak never sees a request the host
rejected.

```console
dart run bin/host.dart
curl -H 'x-api-key: let-me-in' -X POST localhost:8080/admin/api/tickets/query \
  -H 'content-type: application/json' -d '{"table":"tickets"}'
```

**2. Beak blocks inside an app that is not a panel.** `lib/host_app.dart` is
an ordinary `OiApp` with its own screen; one `BeakBlockHost` renders the
ticket queue from the same models and the same API. The only Beak wiring is
`registerBeakDependencies`.

**3. A table another system owns.** `@Resource(table: 'accounts',
managesSchema: false)` on `LegacyAccount` means Beak reads it, writes it,
renders it and relates to it — and generates no migration for it.
`lib/legacy_system.dart` creates that table the way the other system would.
`lib/migrations/` holds exactly one file, for the table this app does own.

**4. The S3 upload driver.** `beak_backend` depends on no driver package, so
`lib/server.dart` declares `beakStorageRegistry` and registers
`beak_storage_s3`; `beak prepare` wires it into the host. Set
`BEAK_STORAGE_DRIVER=s3` plus the `BEAK_S3_*` variables and uploads go to S3
or MinIO instead of local disk. The `xml` dependency override this needs lives
here and nowhere else.

## Tests

```console
flutter test
```
