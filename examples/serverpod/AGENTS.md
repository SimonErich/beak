# Beak on Serverpod: notes for coding agents

A Serverpod 4.0.3 workspace with a Beak admin panel for two tables, `author`
and `book`. Beak's API runs inside the Serverpod server behind one gated
endpoint method. Read `README.md` first for what it does and does not cover.

## Packages

| Package | What it is | You edit |
| --- | --- | --- |
| `bookshop_server` | Serverpod server. `lib/src/catalog/*.spy.yaml` are the models; `lib/src/beak/` holds the endpoint, the engine, the policy and the scopes; `bin/beak_admin.dart` grants and revokes admin access. | yes |
| `bookshop_client` | Generated client. | never |
| `bookshop_flutter` | The template's app. | no |
| `bookshop_beak` | Pure Dart Beak schema classes (`lib/models/*.dart`), generated parts (`*.beak.dart`, `lib/beak/registry.g.dart`) and the barrel `lib/bookshop_beak.dart`. | the schema classes and the barrel |
| `bookshop_admin` | Flutter web panel: `lib/resources/*_resource.dart` and `lib/src/bookshop_admin.dart`. | yes |

`lib/src/generated/` in the server, `bookshop_client`, and every `*.beak.dart`
and `*.g.dart` file are generated: never edit them. The `migration.sql` of a
generated migration may be edited by hand when the SQL would lose data; leave
the other files in a migration directory alone.

## The loop after a model change

```console
cd bookshop_server
../../../tool/serverpod_cli_4/serverpod generate
../../../tool/serverpod_cli_4/serverpod create-migration --tag <what-changed>
# mirror the change in bookshop_beak/lib/models/<name>.dart, then:
cd ../bookshop_beak && ./tool/prepare
cd ../bookshop_server && dart test
```

Use the pinned CLI in `tool/serverpod_cli_4` (resolve it once with `dart pub
get` there); a globally activated `serverpod` may be another release. Run the
server with `dart run bin/main.dart --apply-migrations`, never the interactive
`serverpod start`.

`dart test` fails when a Beak column is not a physical column of its table,
when the supplier cost gets modelled, or when the `BookFormat` enum in
`bookshop_beak` differs from the Serverpod one.

## Rules

- Never write a table or column name as a string in panel code. Reference the
  generated model: `BookModel.title.inputText()`, `BookModel.author.relationFilter()`.
- A Serverpod column Beak must not expose (`supplierCostInCents`) is left out
  of the Beak schema class. Do not add it.
- New tables are closed until `lib/src/beak/bookshop_policy.dart` names them.
- Serverpod owns the schema: Beak schema classes say `managesSchema: false`.
  Change tables with a `.spy.yaml` and a migration, never with SQL.
- Never import `package:flutter/material.dart` or `cupertino.dart` in Beak
  code. Widgets are `HookWidget`; `StatefulWidget` is not used.
- The email verification code is printed in the server log in development. In
  a deployed run mode, configure a real sender.

## Commands

```console
dart pub get                                        # workspace root
cp bookshop_server/config/passwords.example.yaml bookshop_server/config/passwords.yaml   # first run only
cd bookshop_server && dart test                     # embedded Postgres, no Docker
cd bookshop_admin && flutter test                   # widget tests
cd bookshop_admin && flutter analyze
cd bookshop_admin && flutter build web
```
