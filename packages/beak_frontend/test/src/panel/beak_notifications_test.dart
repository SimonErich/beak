import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

/// A tiny notification model: title, body, a read flag, and a timestamp.
final class _NotifModel extends BeakModel {
  const _NotifModel();

  @override
  String get table => 'notifications';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'title', label: 'Title'),
    BeakStringColumn(key: 'body', label: 'Body'),
    BeakBoolColumn(key: 'is_read', label: 'Read'),
    BeakDateTimeColumn(key: 'created_at', label: 'When'),
  ];
}

void main() {
  const source = BeakNotificationSource(
    model: _NotifModel(),
    titleField: BeakStringColumn(key: 'title', label: 'Title'),
    bodyField: BeakStringColumn(key: 'body', label: 'Body'),
    timeField: BeakDateTimeColumn(key: 'created_at', label: 'When'),
    readField: BeakBoolColumn(key: 'is_read', label: 'Read'),
  );

  testWidgets('the bell shows the unread count and opens the panel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final dataSource = FakeDataSource(
      records: {
        'notifications': {
          'n1': BeakRecord.fromRow(const {
            'id': 'n1',
            'title': 'New order',
            'body': 'Order ORD-1 placed',
            'is_read': false,
            'created_at': '2026-02-01T00:00:00.000Z',
          }),
          'n2': BeakRecord.fromRow(const {
            'id': 'n2',
            'title': 'Payment received',
            'body': 'Invoice paid',
            'is_read': true,
            'created_at': '2026-01-01T00:00:00.000Z',
          }),
        },
      },
    );
    registerBeakDependencies(
      config: const BeakPanelConfig(
        title: 'Demo',
        apiBaseUrl: 'http://localhost',
        resources: [
          BeakResource(model: _NotifModel(), icon: BeakIconToken(OiIcons.bell)),
        ],
      ),
      dataSource: dataSource,
    );

    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: const BeakNotificationBell(source: source),
      ),
    );
    await tester.pumpAndSettle();

    // One of the two notifications is unread → a "1" badge on the bell.
    expect(find.text('1'), findsOneWidget);

    await beakDependencies(
      tester.element(find.byType(BeakNotificationBell)),
    )<BeakDataSource>().create(
      'notifications',
      BeakRecord.fromRow({
        'id': 'n3',
        'title': 'Delivery update',
        'body': 'The route has changed',
        'is_read': false,
        'created_at': '2026-02-02T00:00:00.000Z',
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    // Tapping the bell opens the notification panel.
    await tester.tap(find.byType(OiButton));
    await tester.pumpAndSettle();
    expect(find.byType(OiNotificationCenter), findsOneWidget);
    expect(find.text('New order'), findsWidgets);
    expect(find.text('Delivery update'), findsWidgets);
    tester.takeException();
  });
}
