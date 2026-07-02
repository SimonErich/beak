import 'package:flutter/widgets.dart';

/// The version of the reference admin app skeleton.
const String referenceAdminVersion = '0.0.1';

/// Placeholder root widget until the Beak panel is composed in later phases.
final class ReferenceAdminApp extends StatelessWidget {
  /// Creates the placeholder shell.
  const ReferenceAdminApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Color(0xFF101014));
}

void main() => runApp(const ReferenceAdminApp());
