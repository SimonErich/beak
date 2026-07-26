/// The Flutter half of Beak: the panel shell, the data table, forms, detail
/// views, actions, dashboard blocks and their configuration.
///
/// Import this from `main.dart`, from a screen, and from a resource override.
/// It re-exports `package:beak/beak.dart`, so one import is enough — a screen
/// naming both `BeakPanel` and `BeakQuerySpec` needs nothing else.
///
/// A model file and the generated registry deliberately import only
/// `package:beak/beak.dart`: they are shared with the server, and reaching
/// `dart:ui` from there would stop `bin/serve.dart` compiling.
///
/// ```dart
/// import 'package:beak/panel.dart';
///
/// void main() => runApp(const BeakApp());
/// ```
library;

export 'package:beak_frontend/beak_frontend.dart';

export 'beak.dart';
