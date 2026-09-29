# Two ways to boot a panel

> Choose between the generated BeakApp and an authored BeakPanel, and switch with beak eject main.

This page is a draft. It will cover the two ways a project boots its panel: the generated `BeakApp` that `beak prepare` writes to `lib/beak/app.g.dart` from `beak.yaml`, and an authored `BeakPanel(resources: [...])` in `lib/main.dart`. It will show how to choose between them and how `beak eject main` switches from the first to the second.

## Continue reading

- [Beak](../index.md): Beak builds an admin panel, a REST API and migrations for Dart and Flutter from annotated schema classes and declarative resources.
- [Choose your path](paths/index.md): Pick the starting situation that matches your project and follow its first pages.
- [Project structure](project-structure.md): Separate model behavior, resource navigation and screen layout in one application.
