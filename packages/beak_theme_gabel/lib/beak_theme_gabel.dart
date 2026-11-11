/// The official Gabel design for a Beak panel.
///
/// Add the package, then select the theme on the panel configuration:
///
/// ```dart
/// import 'package:beak/panel.dart';
/// import 'package:beak_theme_gabel/beak_theme_gabel.dart';
///
/// final config = BeakPanelConfig(
///   title: 'Gabel Admin',
///   theme: GabelTheme(),
///   resources: resources,
/// );
/// ```
///
/// The umbrella `beak` package does not depend on this one, so a panel that
/// does not select it ships none of its fonts.
library;

export 'src/gabel_fonts.dart';
export 'src/gabel_icons.dart';
export 'src/gabel_numeric_styles.dart';
export 'src/gabel_theme.dart';
export 'src/tokens/gabel_dark.dart';
export 'src/tokens/gabel_light.dart';
