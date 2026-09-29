# Going to production

> Build the API and panel, run migrations, and configure production state explicitly.

Beak produces an ordinary Dart server and Flutter application. Generate their
host wiring from the same revision, build both, and apply migrations before
serving code that depends on the new schema.

The canonical shop is a local demonstration, not a ready-made production security
configuration. A deployed application must supply its own authentication,
authorization, secrets, database, media storage and operational policies.

## Build a project

Resolve the Flutter package and run generation before compiling its ignored
entrypoints. From the application's directory:

```sh
flutter pub get
dart run ../../packages/beak_cli/bin/beak.dart prepare
dart compile exe bin/serve.dart -o build/beak-server
dart compile exe bin/migrate.dart -o build/beak-migrate
flutter build web --release --dart-define=BEAK_API_BASE_URL=https://api.example.com
```

The relative CLI path above is for `examples/clean_beak_config` in this repository.
Installed projects can use their installed `beak prepare` command. A container
build needs the whole dependency workspace when pubspecs use path dependencies,
and a Flutter SDK while resolving a package that declares Flutter dependencies.

The server executable runs the generated host. The migration executable uses the
same registry and migration list. The `build/web` directory is static frontend
content; serve it with a web server that falls back to `index.html` for panel routes.
The repository's `deploy/` directory contains container and reverse-proxy starting
points; adapt them to the actual project and build environment.

## Configure the runtime

Set `DATABASE_URL`, `HOST` and `PORT` for the server. Use persistent storage and a
backup policy appropriate to the data. Run the migration executable as a deployment
step; do not run a destructive fresh/reset command against production data.
Demonstration seeds are separate from migration and should not be run by default.

The frontend's API origin is a build-time value. `BEAK_API_BASE_URL` must match the
browser-visible API address, not an internal container hostname. A generated host
can also use `api.baseUrl: auto` when panel and API intentionally share an origin.
Configure CORS and TLS for the chosen deployment topology.

## Preserve lifecycle guarantees

Named actions, snapshots and graph calculations require the authoritative atomic
provider. Keep receipt storage durable alongside business data so interrupted
requests can recover by the same save identity. Do not turn a failed or unknown
response into a new action request with a different identifier.

Field and row authorization belongs to the backend. Configure user/tenant draft
namespaces when enabling local persistence. Public local media URLs remain public;
use an appropriate private/signed storage driver for private files and authorize
URL resolution and deletion.

## Operate and verify

Use `/healthz` for process liveness and `/readyz` for database readiness. Verify a
real create/read/edit flow, an authorized action, media handling, and recovery from
an interrupted save in the deployment environment. Protect log and trace access
and avoid recording secrets or password fields.

The example's tests prove local SQLite behavior. Database/storage adapters have
separate service-backed suites; run the relevant suites before deploying a changed
adapter. A container build, database migration and browser smoke test remain
separate deployment checks.

See [environment and configuration](environment-and-config.md),
[auth and policies](../backend/auth-and-policies.md), and
[uploads and galleries](../forms/uploads-and-galleries.md).

## Continue reading

- [Environment and configuration](environment-and-config.md).
- [Security](security.md).
