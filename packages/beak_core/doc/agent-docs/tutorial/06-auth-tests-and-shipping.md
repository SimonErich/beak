# Auth, tests, and shipping

> Verify the declarative contracts and configure authority before deployment.

Test the shared model rules, the server and the actual configured screens. Each layer catches a different class of failure.

```bash
cd examples/clean_beak_config
flutter analyze
flutter test
flutter build web --release
```

`beak doctor` checks generated files, migrations and server/panel import boundaries. The repository also runs documentation, web-safety and Material-import guards.

## Authority

The local shop is an open demonstration. Configure `BeakPolicy` on the server for resource operations, `BeakRowPolicy` for row scopes and `BeakFieldPolicy` for protected fields. Field restrictions apply to queries, search, aggregates, export, uploads and mutations. Server-returned capabilities guide the form; they do not grant authority.

Keep business transitions in model actions. Tests should prove that direct updates cannot bypass a workflow guard and that failed graph writes leave no partial records.

## Deployment

Build the Flutter panel and deploy its static output. Run the generated Shelf server as a separate process with a configured database and storage driver. Set the API origin for that environment. Keep secrets in the server environment, outside the panel bundle.

Back up the database before applying reviewed migrations. Retain commit receipts long enough for interrupted clients to recover. Treat external effects such as email or payment capture as separate durable integrations with explicit retry semantics.

## Continue reading

- [Security](../shipping/security.md)
- [Deployment](../shipping/going-to-production.md)
