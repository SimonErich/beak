---
title: Why Beak?
description: The case for one declaration over three hand-written layers, the UX you get for free, and the honest tradeoffs of the approach.
---

# Why Beak?

After this page you will understand the bet Beak makes, what you gain by taking
it, and where it stops being the right tool. It is a short argument in four
parts, followed by the tradeoffs, so you can decide with open eyes.

The admin panel is the part of an app that is most similar between projects and
least fun to build twice. Beak's bet is that you should declare it, not
hand-write it, and still be holding a normal Flutter app at the end.

## Config over code

An admin resource is a database table, a REST surface for it, and a set of
screens over that surface. Written by hand, those three drift: a field gets a
new validation rule in the API but not the form, a column is renamed in the
table but not the export. Beak collapses the three into one declaration and
reads it from every side.

Adding a resource is one file:

```dart title="examples/store/lib/models/category.dart"
@Resource()
final class Category extends BeakSchema {
  /// What the category is called.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// The one-line blurb shown above the product list.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? blurb;
}
```

Then three commands, none of which you edit a list for:

```bash
beak prepare   # columns, model, relationships, record view, migration, wiring
beak migrate   # create the table
beak dev       # serve the API, print the panel's run line
```

There is no step where you wire the pieces together, and nothing to keep a
register of: a file under `lib/models/` is a resource. The wiring is what Beak
does. What is left is the set of decisions a person actually makes, and each
one has a home.

| Decision | Where it lives |
| --- | --- |
| Columns, relationships, table name, soft deletes, timestamps | The `@Resource` class in `lib/models/<name>.dart`. |
| Panel title, API origin, server port | `beak.yaml`. |
| A resource's icon, label, section, or hiding it | `beak.yaml`, under `resources.<table>`. |
| A resource's filters, actions, view modes, detail layout, form steps | `lib/resources/<table>.dart`: a `BeakResource beakResource(BeakResource generated)` returning `generated.copyWith(…)`, scaffolded by `beak eject resource <table>`. |
| Theme, auth, the `/` screen, the server | `lib/theme.dart`, `lib/auth.dart`, `lib/dashboard.dart`, `lib/server.dart`, each written for you by `beak eject`. |
| Everything else | Generated into `lib/beak/*.g.dart` and `lib/models/*.beak.dart`. Committed, never edited. |

Every one of those files is presence-based. Create it and Beak uses it; delete
it and the default comes back.

## Optimized UX out of the box

Because Beak generates the UI, it generates a *good* UI, once, and every
resource inherits it. Server-side sort, filter, and pagination in tables. Forms
with client-side validation that mirrors the server rule for rule. Detail
views, relation managers, global search, CSV export, and dashboards. You do not
opt into these per resource; they come with the model.

Three defaults are worth naming, because they are the ones you would otherwise
hand-write for every resource:

- **Filters you never listed.** A resource that declares no filters gets one
  control per `@Column(filterable: true)` column.
- **A show page that follows the model.** With no `detail` layout, the page is
  a headline card of the first few fields, the rest below it, and a tab per
  to-many relationship. Add a column to the class and the page changes, with
  nothing to regenerate.
- **Relationships instead of foreign keys.** A list table renders a column per
  to-one relationship showing the related record's name rather than its id,
  loaded with the page in one query.

File handling is a fair example of the same idea. You describe the rules on the
field and Beak enforces them in the browser (for fast feedback) and again in
the API (because the server never trusts the client), then runs your transform
pipeline and returns a typed result with its variants:

```dart title="examples/store/lib/models/product.dart"
  @Image(
    storagePath: 'products',
    maxSizeInBytes: 5 * 1024 * 1024,
    allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
    thumbnail: BeakDimensions(widthInPixels: 160, heightInPixels: 160),
    transforms: [
      BeakThumbnailTransform(
        size: BeakDimensions(widthInPixels: 160, heightInPixels: 160),
      ),
      BeakFormatTransform.webp(),
    ],
  )
  late final BeakImageRef? image;
```

You wrote a description. You received size limits, type checks, a thumbnail, a
webp rendition, and an upload endpoint that validates before it stores.

## Consistent, and hard to get wrong

The type system does the enforcing, so a whole category of admin bugs cannot
compile. Field references are generated constants, so a typo in a column name
is a missing symbol rather than a runtime surprise. You never touch `dynamic`.
Filter operands travel as a typed `BeakValue`, results come back as a sealed
`BeakResult`, and errors are a sealed `BeakException` family the server maps to
stable HTTP status codes. Every resource in your panel behaves the same way
because they are all rendered by the same code from the same shape of
declaration.

The nullability rule is the sharpest version of this. `String name` is required
and `BeakText? blurb` is not, and that single fact produces the form validator,
the API's validation and the column's `NOT NULL` together. There is no third
place to forget.

This is also why Beak reads well to an AI agent. A resource is a schema an
agent can generate correctly, because there is one right way to describe it and
the compiler checks the result. A generated project even ships an `AGENTS.md`
saying where things go.

## Still a normal Flutter app, so never locked in

The tradeoff people fear with a framework like this is the ceiling: the day the
generated thing is not what you need. Beak is designed so that day is a small
step down, not a wall.

- **Adjust one resource.** `lib/resources/<table>.dart` receives the generated
  `BeakResource` and returns a `copyWith`, so you change the one thing you care
  about and keep the rest.
- **Drop to a custom widget.** Any block tree can host a plain `HookWidget`
  through the widget escape hatch, so a bespoke chart or a one-off control lives
  right next to generated blocks.
- **Add a custom screen or page.** A `BeakScreen` is any block tree (or any
  widget) mounted in the panel shell with its own route and nav entry, next to
  your generated resources.
- **Take a default over.** `beak eject theme`, `auth`, `dashboard`, `server` or
  `panel` writes the Beak default out as a file you own, pre-filled so it
  compiles and changes nothing until your first edit.
- **Use the widgets standalone.** obers_ui is a normal widget library. You can
  render a single `Oi*` widget, or Beak's `BeakBlockHost`, inside an ordinary
  Flutter screen with no panel at all.
- **Swap the data source.** `BeakDataSource` is an interface. worm is today's
  implementation, not a marriage; a future `beak_serverpod` can supply a
  `ServerpodDataSource` without your models or Beak's server half changing.

You are always one step away from ordinary Flutter code, because that is all
Beak ever was.

## The honest tradeoffs

No approach is free. Here is where the bet costs you something.

| Tradeoff | What it means |
| --- | --- |
| A learning curve up front | You trade writing familiar hand code for learning Beak's vocabulary (annotations, columns, blocks, the generate step). The payoff arrives on the second resource, not the first line. |
| A generate step | `beak prepare` runs before anything else, and the files it writes are committed. `beak doctor` fails when they are stale, so the cost is a command, not a mystery. |
| Convention over total control | Generated pages follow Beak's layout choices. Deep bespoke layouts mean reaching for custom blocks and screens, which is supported but is more code than a config line. |
| The obers_ui and worm dependency | Beak commits you to obers_ui for UI and (today) worm for data. Both come in with the `beak` package; the data side is behind an interface, the UI side is not. |
| Pre-1.0 | Beak is pre-1.0. The design is settled and tested end to end, but the surface can still move before 1.0. |
| Admin-shaped, not everything-shaped | Beak is sharp for internal tools and dashboards. It is the wrong tool for a consumer-facing app, where you want full control of every pixel. |

If those tradeoffs read as acceptable for the back office you are about to
build, Beak will save you the three-times-over work. If you need total layout
control over a public app, use Flutter directly.

## Continue reading

- [What is Beak?](what-is-beak.md) the definition, the name, and the eight
  libraries.
- [The one-definition promise](../concepts/the-one-definition-promise.md) the
  mechanism that makes config-over-code hold together.
- [Project structure](project-structure.md) every optional file that overrides a
  default, and what it receives.
- [Using Beak widgets standalone](../extending/using-beak-widgets-standalone.md)
  the escape hatch to plain Flutter.
- [Custom screens and pages](../extending/custom-screens-and-pages.md) mount your
  own screens in the panel shell.
