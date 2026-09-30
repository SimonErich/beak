import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _cards = BeakToManyField(
  model: _Board(),
  relation: _Board.cards,
  target: _Card(),
);
const _text = BeakScalarField<String>(model: _Card(), column: _Card.text);

void main() {
  testWidgets('the Remove button of every row names the row it removes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    BeakFormSession? session;
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: const _Board(),
          dataSource: FakeDataSource(models: const [_Board(), _Card()]),
          layout: BeakFormLayout(
            children: [
              _cards.tableForm(children: [_text.input()]),
            ],
          ),
          onSession: (value) => session = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    session!.root
      ..addRow(_cards)
      ..addRow(_cards);
    await tester.pumpAndSettle();

    // Two buttons that both read "Remove" cannot be told apart by a screen reader.
    expect(find.bySemanticsLabel('Remove Cards 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Remove Cards 2'), findsOneWidget);
    semantics.dispose();
  });
}

final class _Board extends BeakModel {
  const _Board();
  static const cards = BeakHasMany(
    key: 'cards',
    label: 'Cards',
    relatedTable: 'cards',
    displayColumnKey: 'text',
    foreignKey: 'board_id',
  );
  @override
  String get table => 'boards';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
  ];
  @override
  List<BeakRelationship> get relationships => const [cards];
  @override
  List<BeakModel> get relatedModels => const [_Card()];
}

final class _Card extends BeakModel {
  const _Card();
  static const text = BeakStringColumn(key: 'text', label: 'Text');
  @override
  String get table => 'cards';
  @override
  String get displayColumnKey => 'text';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'board_id', label: 'Board'),
    text,
  ];
}
