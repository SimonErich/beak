import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

enum _Status { draft, published }

final class _Model extends BeakModel {
  const _Model();

  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    filterable: true,
  );
  static const status = BeakEnumColumn<_Status>(
    key: 'status',
    label: 'Status',
    values: _Status.values,
    filterable: true,
  );

  @override
  String get table => 'articles';

  @override
  String get displayColumnKey => title.key;

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    title,
    status,
  ];
}

void main() {
  tearDown(beakLocator.reset);

  testWidgets('derived enum filters have one typed control on a resource', (
    tester,
  ) async {
    final source = FakeDataSource(models: const [_Model()]);
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(
        config: const BeakPanelConfig(
          title: 'Admin',
          resources: [
            BeakResource(
              model: _Model(),
              icon: BeakIconToken(OiIcons.notebook),
            ),
          ],
        ),
        dataSource: source,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Articles').first);
    await tester.pumpAndSettle();

    final OiTable<BeakRecord> table = tester.widget(
      find.byType(OiTable<BeakRecord>),
    );
    expect(
      table.columns.where((column) => column.filterable),
      isEmpty,
      reason:
          'The typed filter bar must not have duplicate text header filters.',
    );
    tester
        .widget<OiFilterChip>(
          find.byWidgetPredicate(
            (widget) => widget is OiFilterChip && widget.label == 'Status',
          ),
        )
        .onTap!
        .call();
    await tester.pumpAndSettle();
    final OiSelect<Enum> select = tester.widget(find.byType(OiSelect<Enum>));
    select.onChanged!(_Status.published);
    await tester.pumpAndSettle();
    expect(
      source.queryCalls.last.filter,
      const BeakFieldFilter(
        column: _Model.status,
        operator: BeakOperator.eq,
        value: BeakStringValue('published'),
      ),
    );
    select.onChanged!(null);
    await tester.pumpAndSettle();
    expect(source.queryCalls.last.filter, isNull);
    tester
        .widget<OiFilterChip>(
          find.byWidgetPredicate(
            (widget) => widget is OiFilterChip && widget.label == 'Title',
          ),
        )
        .onTap!
        .call();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'Launch');
    await tester.pumpAndSettle();
    expect(
      source.queryCalls.last.filter,
      const BeakFieldFilter(
        column: _Model.title,
        operator: BeakOperator.contains,
        value: BeakStringValue('Launch'),
      ),
    );
  });
}
