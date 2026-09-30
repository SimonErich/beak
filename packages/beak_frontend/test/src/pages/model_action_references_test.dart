import 'dart:ui' show PointerDeviceKind;

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _title = BeakScalarField<String>(
  model: _TicketModel(),
  column: BeakStringColumn(key: 'title', label: 'Title'),
);

/// Each command is declared once and referenced by object everywhere else.
abstract final class _TicketActions {
  static const close = BeakModelAction(name: 'close', label: 'Close ticket');
  static const reopen = BeakModelAction(name: 'reopen', label: 'Reopen ticket');
  static const open = BeakModelAction(
    name: 'open',
    label: 'Open ticket',
    allowOnCreate: true,
  );
}

final class _TicketModel extends BeakModel {
  const _TicketModel();

  @override
  String get table => 'tickets';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'title', label: 'Title', sortable: true),
  ];

  @override
  BeakModelBehavior get behavior => const BeakModelBehavior(
    actions: [_TicketActions.close, _TicketActions.reopen, _TicketActions.open],
  );
}

FakeDataSource _source() => FakeDataSource(
  models: const [_TicketModel()],
  records: {
    'tickets': {
      'a': BeakRecord.fromRow(const {'id': 'a', 'title': 'Broken link'}),
    },
  },
);

Future<void> _pumpTickets(
  WidgetTester tester,
  BeakListDefinition definition, {
  List<BeakResourceScreen> more = const [],
  bool canEdit = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    BeakPanel(
      dataSource: _source(),
      resources: [
        BeakResource(
          model: const _TicketModel(),
          canEdit: canEdit,
          screens: [
            BeakTableScreen(definition: definition),
            ...more,
          ],
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.byType(OiAppShell))).go('/tickets');
  await tester.pumpAndSettle();
}

Future<void> _selectFirstRow(WidgetTester tester) async {
  await tester.tap(
    find.byWidgetPredicate(
      (widget) =>
          widget is OiCheckbox && widget.semanticLabel == 'Select row 1',
    ),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
}

void main() {
  test('a model presentation refers to its command by object', () {
    final presented = BeakActionPresentation.model(
      _TicketActions.close,
      label: 'Close',
    );
    expect(presented.modelAction, same(_TicketActions.close));
    expect(
      presented.key,
      BeakActionPresentation.keyOfModelAction(_TicketActions.close),
    );
    expect(presented.label, 'Close');
    const builtIn = BeakActionPresentation(key: 'view');
    expect(builtIn.modelAction, isNull);
    expect(builtIn.key, 'view');
  });

  testWidgets('bulk model commands are offered for the selected rows', (
    tester,
  ) async {
    await _pumpTickets(
      tester,
      BeakListDefinition(
        columns: [BeakTableColumn.field(_title)],
        bulkModelActions: const [_TicketActions.close],
      ),
    );
    await _selectFirstRow(tester);
    expect(find.text('Close ticket'), findsOneWidget);
    expect(find.text('Reopen ticket'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a resource that cannot be edited offers no bulk command', (
    tester,
  ) async {
    await _pumpTickets(
      tester,
      BeakListDefinition(
        columns: [BeakTableColumn.field(_title)],
        bulkModelActions: const [_TicketActions.close],
      ),
      canEdit: false,
    );
    // With no command left there is nothing to select rows for.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is OiCheckbox && widget.semanticLabel == 'Select row 1',
      ),
      findsNothing,
    );
    expect(find.text('Close ticket'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a bulk presentation includes and relabels its command', (
    tester,
  ) async {
    await _pumpTickets(
      tester,
      BeakListDefinition(
        columns: [BeakTableColumn.field(_title)],
        bulkActions: [
          BeakActionPresentation.model(
            _TicketActions.reopen,
            label: 'Reopen selected',
          ),
        ],
      ),
    );
    await _selectFirstRow(tester);
    expect(find.text('Reopen selected'), findsOneWidget);
    expect(find.text('Close ticket'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a form screen submits with the command it names', (
    tester,
  ) async {
    await _pumpTickets(
      tester,
      BeakListDefinition(columns: [BeakTableColumn.field(_title)]),
      more: const [
        BeakFormScreen(
          roles: {BeakScreenRole.create},
          submitAction: _TicketActions.open,
        ),
      ],
    );
    GoRouter.of(tester.element(find.byType(OiAppShell))).go('/tickets/create');
    await tester.pumpAndSettle();
    expect(find.text('Open ticket'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
