import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';

/// Points [BeakLabels.language] at the locale of the surrounding
/// [Localizations], so every model, column, relationship and enum label
/// below resolves in the language the panel is shown in.
///
/// Beak's panel routes install it; it depends on the locale, so a changed
/// locale re-applies the language before the pages below rebuild.
class BeakLabelLanguage extends StatelessWidget {
  /// Applies the surrounding locale's language to [child].
  const BeakLabelLanguage({required this.child, super.key});

  /// The subtree whose labels follow the locale.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    BeakLabels.language = Localizations.maybeLocaleOf(context)?.languageCode;
    return child;
  }
}
