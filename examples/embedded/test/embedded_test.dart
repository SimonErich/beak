import 'dart:io';

import 'package:beak/beak.dart';
import 'package:beak/testing.dart';
import 'package:embedded/beak/registry.g.dart';
import 'package:embedded/host_app.dart';
import 'package:embedded/models/ticket.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Beak blocks render inside an app that is not a panel', (
    tester,
  ) async {
    final registry = buildBeakRegistry();
    final source = InMemoryBeakDataSource(registry: registry)
      ..seed(const TicketModel(), [
        BeakRecord.fromRow(const {
          'id': 't1',
          'subject': 'Card declined',
          'status': 'open',
          'account_id': 'acc-1',
        }),
      ]);

    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(HostApp(dataSource: source));
    await tester.pumpAndSettle();

    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Card declined'), findsOneWidget);
  });

  test('a table another system owns is registered but not migrated', () {
    expect(buildBeakRegistry().byTable('accounts'), isNotNull);
    // `@Resource(managesSchema: false)` is why `beak prepare` wrote a
    // migration for tickets and none for accounts.
    expect(
      Directory('lib/migrations').listSync().map((entity) => entity.path),
      [endsWith('create_tickets_table.dart')],
    );
  });
}
