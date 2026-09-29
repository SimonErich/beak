# beak_serverpod_server

Runs Beak's admin API inside a Serverpod 4 server, behind one gated endpoint
method, on Serverpod's own database.

- `BeakServerpodEngine` runs Beak's stock Shelf pipeline in memory. The
  endpoint method hands it one string (envelope v1, see `beak_serverpod`), the
  engine answers with one string. A policy is required: there is no allow-all
  default.
- `BeakAdminGate` is a getter-only mixin that puts `requireLogin` and the
  `beak.admin` scope in front of the endpoint, before any Beak code runs.
- `ServerpodSessionAdapter` is a worm `DatabaseAdapter` over the request
  Session's pool and transactions (`session.db.unsafeQuery`, `unsafeExecute`,
  `transaction`). Nested transactions are savepoints, and Serverpod's database
  errors become the worm exceptions Beak's services catch.
- `BeakServerpod.runInSession` is the zone that carries the Session into Beak;
  `sessionOf` and `transactionOf` hand typed Serverpod ORM writes the same
  session and transaction.
- `beakServerpodFrameworkTables` maps Beak's graph-commit receipts onto the
  `beak_commit_receipt` Serverpod model, so `serverpod create-migration` owns
  the table.

Only `/api/**` (minus `/api/auth/**`) is reachable through the tunnel, and only
`content-type`, `accept`, `if-unmodified-since` and `x-beak-request-id`
headers travel. The principal comes from `session.authenticated` alone.

The unit tests here run against a fake Session. Tests that need a live Serverpod
database live in the example project.
