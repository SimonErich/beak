import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  const config = BeakPanelConfig(
    title: 'Demo',
    apiBaseUrl: 'http://localhost',
    resources: [
      BeakResource(model: NoteModel(), icon: BeakIconToken(OiIcons.file)),
    ],
    pages: [
      BeakScreen(
        path: '/reports',
        title: 'Reports',
        icon: BeakIconToken(OiIcons.barChart2),
        section: 'Insights',
        body: BeakTextBlock('reports'),
      ),
    ],
  );

  test('navigation commands cover the dashboard, resources, and pages', () {
    final routes = <String>[];
    final commands = beakNavigationCommands(config, routes.add);

    final labels = [for (final c in commands) c.label];
    expect(labels, containsAll(<String>['Dashboard', 'Notes', 'Reports']));

    // Executing a command routes to its destination.
    final reports = commands.firstWhere((c) => c.label == 'Reports');
    reports.onExecute!();
    expect(routes, ['/reports']);
  });

  test('the dashboard command is dropped when a page claims /', () {
    const withHome = BeakPanelConfig(
      title: 'Demo',
      apiBaseUrl: 'http://localhost',
      resources: [
        BeakResource(model: NoteModel(), icon: BeakIconToken(OiIcons.file)),
      ],
      pages: [
        BeakScreen(
          path: '/',
          title: 'Home',
          icon: BeakIconToken(OiIcons.home),
          body: BeakTextBlock('home'),
        ),
      ],
    );
    final labels = [
      for (final c in beakNavigationCommands(withHome, (_) {})) c.label,
    ];
    expect(labels, isNot(contains('Dashboard')));
    expect(labels, contains('Home'));
  });
}
