/// The obers_ui widget set Beak is built on: `OiCard`, `OiColumn`, `OiTable`
/// and the autoform widgets.
///
/// A project only needs this when it composes its own screens beyond the
/// generated ones — which is exactly when it would otherwise have to add
/// three more dependencies and keep their versions in step with Beak's.
///
/// Kept separate from `package:beak/panel.dart` so the panel's own names stay
/// unambiguous at the import site, and the chart widgets are kept separate
/// again in `package:beak/charts.dart`: obers_ui and obers_ui_charts both
/// declare an `OiAnnotationType` — one annotates an image, the other a chart
/// axis — and a single re-export would make the name ambiguous for everyone.
///
/// ```dart
/// import 'package:beak/panel.dart';
/// import 'package:beak/ui.dart';
///
/// final screen = BeakScreen(
///   path: '/welcome',
///   builder: (context) => const OiCard(child: OiText('Hello')),
/// );
/// ```
library;

export 'package:obers_ui/obers_ui.dart';
export 'package:obers_ui_autoforms/obers_ui_autoforms.dart';
