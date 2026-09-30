/// The Flutter half of Beak: the panel shell, the data table, forms, detail
/// views, actions, dashboard blocks and their configuration.
///
/// Import this from `main.dart`, from a screen, and from a resource
/// definition. It re-exports `package:beak/beak.dart`, so one import covers
/// all of Beak: a screen naming both `BeakPanel` and `BeakFilter` needs no
/// other Beak import. A generated model such as `ProductModel` lives in the
/// project's own model file, which the screen imports alongside.
///
/// A model file and the generated registry deliberately import only
/// `package:beak/beak.dart`: they are shared with the server, and reaching
/// `dart:ui` from there would stop `bin/serve.dart` compiling.
///
/// A panel boots one of two ways. An authored `lib/main.dart` lists its
/// resources itself:
///
/// ```dart
/// import 'package:beak/panel.dart';
/// import 'package:flutter/widgets.dart';
///
/// import 'resources/orders/order_resource.dart';
/// import 'resources/products/product_resource.dart';
///
/// void main() => runApp(
///   BeakPanel(
///     title: 'Shop',
///     resources: [ProductResource(), OrderResource()],
///   ),
/// );
/// ```
///
/// A project that leaves the panel to `beak prepare` boots the generated
/// `BeakApp` from `lib/beak/app.g.dart` instead, with
/// `runApp(const BeakApp())`. That widget builds the same `BeakPanel`, from
/// the configuration `beak prepare` writes to `lib/beak/panel.g.dart`.
library;

export 'package:beak_frontend/beak_frontend.dart';

export 'beak.dart';
