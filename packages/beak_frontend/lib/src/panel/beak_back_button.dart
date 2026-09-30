import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../localization/beak_localizations.dart';

/// Returns to the originating list with its query choices intact.
class BeakBackButton extends StatelessWidget {
  /// [fallback] is used for direct links without a valid local return route.
  const BeakBackButton({this.fallback = '/', this.label, super.key});

  /// Safe local route used when no contextual list was recorded.
  final String fallback;

  /// Accessible action label; the panel language's "Back" when null.
  final String? label;

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

  /// [destination] with the page the person is on attached as its return
  /// address, so the page it opens can lead back with the list's search,
  /// filters, sort and page.
  ///
  /// A page opened from a page that already carries a return address passes
  /// that one on, so a chain of pages still ends at the list it began on.
  static String carry(Uri current, String destination) {
    final back = current.queryParameters['returnTo'] ?? current.toString();
    return Uri.parse(
      destination,
    ).replace(queryParameters: {'returnTo': back}).toString();
  }

  /// [destination] with the return address [current] already carries, and none
  /// when it carries none: for a page that replaces the current one, such as
  /// the record page an edit returns to.
  static String keep(Uri current, String destination) {
    final back = current.queryParameters['returnTo'];
    return back == null
        ? destination
        : Uri.parse(
            destination,
          ).replace(queryParameters: {'returnTo': back}).toString();
  }

  @override
  Widget build(BuildContext context) => OiButton.ghost(
    label: label ?? BeakLocalizations.of(context).back,
    icon: OiIcons.arrowLeft,
    onTap: () =>
        context.go(destination(GoRouterState.of(context).uri, fallback)),
  );
}
