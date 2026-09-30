import 'package:beak_core/beak_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// Platform boundary for declarative contact and link actions.
/// A host may inject a launcher for managed navigation or tests.
typedef BeakUriLauncher = Future<bool> Function(Uri uri);

/// Opens a safe absolute web or contact URI through the platform handler.
///
/// Only HTTP(S), email, telephone, and SMS destinations are accepted. Relative
/// paths and executable/file schemes cannot escape the panel's action boundary.
/// Failures remain typed so action runners and form hosts use their normal
/// accessible error presentation. The launcher is invoked directly, without a
/// capability preflight that could lose the browser's user-gesture activation.
Future<void> launchBeakUri(Uri uri, {BeakUriLauncher? launcher}) async {
  const allowed = {'https', 'http', 'mailto', 'tel', 'sms'};
  final web = uri.scheme == 'https' || uri.scheme == 'http';
  if (!allowed.contains(uri.scheme) ||
      (web ? uri.host.isEmpty : uri.path.trim().isEmpty)) {
    throw const BeakValidationException('This link address is not supported.');
  }
  try {
    final opened = await (launcher ?? _launch)(uri);
    if (!opened) {
      throw const BeakValidationException(
        'No application is available to open this link.',
      );
    }
  } on BeakException {
    rethrow;
  } catch (_) {
    throw const BeakValidationException('The link could not be opened.');
  }
}

Future<bool> _launch(Uri uri) => launchUrl(uri);
