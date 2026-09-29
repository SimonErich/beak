# Tutorial

> Build a small shop admin in six chapters, from an empty folder to a panel behind a sign-in, an API that refuses strangers, tests and two build outputs.

First Flight builds one project, called `shop`, in six chapters. It starts as an empty folder and ends as a panel behind a sign-in, an API that refuses strangers, four tests and two things you can deploy. You type most of it, and every command output on these pages was produced by running that command on this project.

The `shop` is a slice of the maintained example in [`examples/clean_beak_config`](https://github.com/SimonErich/beak/tree/v0.9.0/examples/clean_beak_config). Its code blocks are quoted from that example's files, so they compile, and the chapters say when a block is your own or not part of your project. If you would rather read the finished thing than build it, [Clean shop](../examples/clean-shop.md) is the tour.

## What you will end up with

- **Categories and products**, with exact money, rules that hold in the form and at the API, and links between them.
- **A panel you shaped**: table columns, filters, search, an overview page, a brand colour and a money format.
- **A seeded database** you can rebuild in seconds, and an API you have called by hand.
- **Authorization on the server**, a sign-in in the panel, and tests for the panel, the API and the policy.
- **A server bundle and a static panel**, built the way a host would run them.

## How the chapters work

Every chapter opens with what you will build and what you need before you start, walks through the steps, and ends with a command you run and the output you should see, followed by a checkpoint you can compare your project against. The project runs at every checkpoint, so you can stop after any chapter and come back.

A `What just happened` box after a step says what Beak did for you. A `What this skipped` box names the pages that cover what the step left out.

## Before you start

| You need | Why |
| --- | --- |
| Dart `^3.11` and Flutter stable `3.41` or newer | The CLI and the server run on Dart, the panel on Flutter. |
| The `beak` command | [Installation](../start-here/installation.md) has the one line. |
| Chrome and `curl` | Chrome runs the panel, `curl` talks to the API. |
| Port `8080` free | The API listens there. |

No database to install. A new project uses a SQLite file that Beak creates on the first migrate.

Two things are worth knowing before chapter 1:

- The tutorial uses the **authored** panel: you own `lib/main.dart` and list your resources in it, which is what `beak create --authored` writes. The [quickstart](../start-here/quickstart.md) uses the generated one instead, and [Two ways to boot a panel](../start-here/generated-or-authored.md) compares them. The chapters say which form they assume.
- Until a release exists, `beak create` needs a local checkout of Beak to point at. Chapter 1 shows the flag and what changes in `pubspec.yaml`.

## Which page to read

| You want to... | Read | For that |
| --- | --- | --- |
| Start a project and get one resource running | [Your first resource](01-your-first-resource.md) | `beak create`, a schema class, a resource, a migration, the panel and the REST API |
| Store money and make a rule hold in two places | [Columns and validation](02-columns-and-validation.md) | Products, exact prices, `BeakMin`, and the same error from the form and the server |
| Link records and edit them together | [Related records](03-relationships.md) | A picker, an owned table of attributes, a drift migration and one save for the whole draft |
| Fill the database and see what the panel sends | [Seeding and the API](04-seeding-and-the-api.md) | A repeatable seeder, queries and graph commits by hand |
| Change how the panel looks and what it finds | [Shaping the panel](05-shaping-the-panel.md) | Columns, filters, search, an overview page, a brand and a money format |
| Lock it down, test it and build it | [Auth, tests, and shipping](06-auth-tests-and-shipping.md) | Policies, a sign-in, three kinds of test, and the server and panel builds |

## Continue reading

- [Your first resource](01-your-first-resource.md): start here.
- [Quickstart](../start-here/quickstart.md): the ten-minute version, with the generated panel.
- [Concepts](../concepts/index.md): the reasons behind what the tutorial has you type.
