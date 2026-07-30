/// The shared half of Beak: typed columns, models, relationships, the
/// serializable query spec, and the storage abstraction.
///
/// This is what a model file, the generated registry, a screen and the server
/// all have in common, and it depends on neither Flutter nor `dart:io`. The
/// panel widgets live in `package:beak/panel.dart`, the Shelf host in
/// `package:beak/server.dart`.
///
/// Keeping the widgets out of here is not tidiness: `bin/serve.dart` reaches
/// the registry, the registry reaches the models, and if either of those
/// pulled in `dart:ui` the server would stop compiling ahead-of-time.
///
/// ```dart
/// import 'package:beak/beak.dart';
///
/// const price = BeakDecimalColumn(key: 'price', label: 'Price');
/// final cheap = const BeakQuerySpec(table: 'products')
///     .withFilter(BeakFieldFilter(
///       column: price,
///       operator: BeakOperator.lt,
///       value: BeakValue.of(10),
///     ));
/// ```
library;

export 'package:beak_core/beak_core.dart';
