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

const _title = BeakScalarField<String>(
  model: _NotifModel(),
  column: BeakStringColumn(key: 'title', label: 'Title'),
);
const _body = BeakScalarField<String>(
  model: _NotifModel(),
  column: BeakStringColumn(key: 'body', label: 'Body'),
);
const _createdAt = BeakScalarField<DateTime>(
  model: _NotifModel(),
  column: BeakDateTimeColumn(key: 'created_at', label: 'When'),
);
const _isRead = BeakScalarField<bool>(
  model: _NotifModel(),
  column: BeakBoolColumn(key: 'is_read', label: 'Read'),
);

void main() {
  final source = BeakNotificationSource(
    titleField: _title,
    bodyField: _body,
    timeField: _createdAt,
    readField: _isRead,
  );

  test('the source reads its model from the fields it is given', () {
    expect(source.model.table, 'notifications');
  });

  test('every field must belong to the title field\'s model', () {
    const foreign = BeakScalarField<String>(
      model: NoteModel(),
      column: BeakStringColumn(key: 'name', label: 'Name'),
    );
    expect(
      () => BeakNotificationSource(titleField: _title, bodyField: foreign),
      throwsA(isA<BeakConfigurationException>()),
    );
  });

  test('a field reached through a relationship cannot be a notification', () {
    const related = BeakScalarField<bool>(
      model: _NotifModel(),
      column: BeakBoolColumn(key: 'is_read', label: 'Read'),
      path: [
        BeakBelongsTo(
          key: 'recipient',
          label: 'Recipient',
          relatedTable: 'users',
          displayColumnKey: 'name',
          foreignKey: 'recipient_id',
        ),
      ],
    );
    expect(
      () => BeakNotificationSource(titleField: _title, readField: related),
      throwsA(isA<BeakConfigurationException>()),
    );
  });

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
        home: BeakNotificationBell(source: source),
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

    // Marking one notification read writes the flag back through the source.
    final center = tester.widget<OiNotificationCenter>(
      find.byType(OiNotificationCenter),
    );
    center.onMarkRead!(
      center.notifications.firstWhere((item) => item.key == 'n1'),
    );
    await tester.pumpAndSettle();
    expect(dataSource.updateCalls.map((call) => call.$2), ['n1']);
    expect(_isRead.readFrom(dataSource.updateCalls.single.$3), isTrue);
    expect(find.text('1'), findsWidgets);

    // Marking all read leaves nothing unread and hides the badge.
    center.onMarkAllRead!();
    await tester.pumpAndSettle();
    expect(dataSource.updateCalls.map((call) => call.$2), ['n1', 'n3']);
    tester.takeException();
  });

  testWidgets(
    'a refused mark-as-read keeps the notification unread and says so',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      registerBeakDependencies(
        config: const BeakPanelConfig(
          title: 'Demo',
          apiBaseUrl: 'http://localhost',
          resources: [
            BeakResource(
              model: _NotifModel(),
              icon: BeakIconToken(OiIcons.bell),
            ),
          ],
        ),
        dataSource: _RefusingUpdates(
          records: {
            'notifications': {
              'n1': BeakRecord.fromRow(const {
                'id': 'n1',
                'title': 'New order',
                'is_read': false,
                'created_at': '2026-02-01T00:00:00.000Z',
              }),
            },
          },
        ),
      );
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakNotificationBell(source: source),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OiButton));
      await tester.pumpAndSettle();

      final center = tester.widget<OiNotificationCenter>(
        find.byType(OiNotificationCenter),
      );
      center.onMarkRead!(center.notifications.single);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Not your notification.'), findsOneWidget);
      expect(
        tester
            .widget<OiNotificationCenter>(find.byType(OiNotificationCenter))
            .notifications
            .single
            .read,
        isFalse,
      );
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets('a row without a time is not listed under an invented date', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    registerBeakDependencies(
      config: const BeakPanelConfig(
        title: 'Demo',
        apiBaseUrl: 'http://localhost',
        resources: [
          BeakResource(model: _NotifModel(), icon: BeakIconToken(OiIcons.bell)),
        ],
      ),
      dataSource: FakeDataSource(
        records: {
          'notifications': {
            'n1': BeakRecord.fromRow(const {
              'id': 'n1',
              'title': 'Dated',
              'is_read': false,
              'created_at': '2026-02-01T00:00:00.000Z',
            }),
            'n2': BeakRecord.fromRow(const {
              'id': 'n2',
              'title': 'Undated',
              'is_read': false,
              'created_at': null,
            }),
          },
        },
      ),
    );

    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakNotificationBell(source: source),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OiButton));
    await tester.pumpAndSettle();

    final center = tester.widget<OiNotificationCenter>(
      find.byType(OiNotificationCenter),
    );
    expect(center.notifications.map((entry) => entry.title), ['Dated']);
  });
}

final class _RefusingUpdates extends FakeDataSource {
  _RefusingUpdates({super.records});

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) =>
      throw const BeakAuthorizationException('Not your notification.');
}
