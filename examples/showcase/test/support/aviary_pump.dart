import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:showcase/main.dart';

import 'aviary_fixtures.dart';

/// Pumps the Aviary panel over [aviarySource] and navigates to [location].
///
/// The surface is wide enough for the desktop shell, and the panel is the one
/// `main` builds, so a page that breaks here breaks in the app.
Future<void> pumpAviaryAt(WidgetTester tester, String location) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(buildPanel(dataSource: aviarySource()));
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.byType(OiAppShell))).go(location);
  await tester.pumpAndSettle();
}
