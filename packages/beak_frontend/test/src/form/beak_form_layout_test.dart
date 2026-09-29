import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_autoforms/obers_ui_autoforms.dart';

import '../../support/panel_fixtures.dart';

void main() {
  test('inputCombobox takes the same live options as the other lookups', () {
    const category = BeakToOneField(
      model: ArticleModel(),
      relation: ArticleRelations.category,
      target: LabelModel(),
    );
    String? guidance(BeakFormReader state) => 'Pick one';
    String? refuse(BeakRecord option, BeakFormReader state) => 'Taken';

    final input = category.inputCombobox(
      dependencies: const [category],
      descriptionBuilder: guidance,
      disabledReason: refuse,
    );

    expect(input.dependencies, const [category]);
    expect(input.descriptionBuilder, same(guidance));
    expect(input.disabledReason, same(refuse));
  });

  test('the tabs projection keeps a section\'s trailing and spacing', () {
    final trailing = BeakValueBinding<Object>.field(
      const BeakScalarField<String>(
        model: ArticleModel(),
        column: ArticleColumns.title,
      ),
    );
    final sections = BeakFormSections(
      sections: [
        BeakSection(
          title: 'Basics',
          trailing: trailing,
          divider: true,
          dividerAfterSpacingInPixels: 12,
          children: const [],
        ),
      ],
    );

    expect(
      sections.tabs.tabs.single.children.single,
      isA<BeakSection>()
          .having((section) => section.trailing, 'trailing', same(trailing))
          .having((section) => section.divider, 'divider', isTrue)
          .having(
            (section) => section.dividerAfterSpacingInPixels,
            'dividerAfterSpacingInPixels',
            12,
          ),
    );
  });

  // A structured layout: a Basics card plus a Pricing card, exactly the shape
  // a detail screen would use — reused here to drive the form.
  final layout = BeakFormLayout(
    children: [
      BeakCard(
        title: 'Basics',
        children: [
          const BeakScalarField<String>(
            model: ArticleModel(),
            column: ArticleColumns.title,
          ).input(),
          const BeakScalarField<String>(
            model: ArticleModel(),
            column: ArticleColumns.summary,
          ).input(),
        ],
      ),
      BeakCard(
        title: 'Pricing',
        children: [
          const BeakScalarField<double>(
            model: ArticleModel(),
            column: ArticleColumns.price,
          ).input(),
          const BeakScalarField<int>(
            model: ArticleModel(),
            column: ArticleColumns.stock,
          ).input(),
        ],
      ),
    ],
  );

  testWidgets('a layout form renders inputs inside the structured cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final dataSource = FakeDataSource(records: const {});

    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: const ArticleModel(),
          dataSource: dataSource,
          layout: layout,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The layout's cards are present…
    expect(find.byType(OiCard), findsWidgets);
    expect(find.text('Basics'), findsOneWidget);
    expect(find.text('Pricing'), findsOneWidget);
    // …and the field blocks rendered *inputs*, not read-only values.
    expect(find.byType(OiAfTextInput<Enum>), findsWidgets);
    expect(find.byType(OiAfNumberInput<Enum>), findsNWidgets(2));
    expect(find.text('Save'), findsOneWidget);
    // A column absent from the layout registered no field, so no select shows.
    expect(find.byType(OiAfSelect<Enum, Enum>), findsNothing);
  });
}
