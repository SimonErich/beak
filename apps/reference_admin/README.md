# reference_admin

The Beak reference panel: six resources (Products, Categories, Tags, Users,
Orders, Order items), a dashboard with aggregate stats and a chart, plus the
custom-filter and custom-action escape hatches — all from
[`lib/main.dart`](lib/main.dart) and the shared definitions in
`../reference_admin_models`.

## Run it

```bash
# From the repo root: services, schema, sample data, backend
melos run up && cp .env.example .env
(cd apps/reference_admin_server && \
  dart run bin/worm.dart migrate && \
  dart run bin/worm.dart db:seed && \
  dart run bin/reference_admin_server.dart) &

# The panel (talks to http://localhost:8080)
cd apps/reference_admin
flutter run -d chrome
```

## Tests

```bash
flutter test          # boots the panel against an in-memory fake source
flutter build web     # the production bundle
```
