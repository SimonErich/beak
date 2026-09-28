import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

/// Returns to the originating list with its query choices intact.
class BeakBackButton extends StatelessWidget {
  /// [fallback] is used for direct links without a valid local return route.
  const BeakBackButton({this.fallback = '/', this.label = 'Back', super.key});

  /// Safe local route used when no contextual list was recorded.
  final String fallback;

  /// Accessible action label.
  final String label;

  /// Validates untrusted URL context without permitting an external redirect.
  static String destination(Uri current, String fallback) {
    final value = current.queryParameters['returnTo'];
    final uri = value == null ? null : Uri.tryParse(value);
    return uri != null &&
            !uri.hasScheme &&
            !uri.hasAuthority &&
            uri.path.startsWith('/') &&
            !uri.path.startsWith('//')
        ? uri.toString()
        : fallback;
  }

  @override
  Widget build(BuildContext context) => OiButton.ghost(
    label: label,
    icon: OiIcons.arrowLeft,
    onTap: () =>
        context.go(destination(GoRouterState.of(context).uri, fallback)),
  );
}
