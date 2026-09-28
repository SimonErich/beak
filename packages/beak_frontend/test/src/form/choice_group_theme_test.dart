import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  for (final asField in [false, true]) {
    testWidgets(
      'radio ${asField ? "field" : "section"} labels retain independent option gaps',
      (tester) async {
        const field = BeakScalarField<String>(
          model: NoteModel(),
          column: BeakStringColumn(key: 'title', label: 'Payment method'),
        );
        late BeakFormSession session;
        await tester.pumpWidget(
          OiApp(
            theme: OiThemeData.light().copyWith(
              components: const OiComponentThemes(
                radio: OiRadioThemeData(
                  size: 16,
                  groupLabelStyle: TextStyle(fontSize: 16, height: 1.5),
                  groupLabelSpacing: 12,
                ),
                textInput: OiTextInputThemeData(
                  labelStyle: TextStyle(fontSize: 14, height: 20 / 14),
                  labelGap: 6,
                ),
                radioTile: OiRadioTileThemeData(
                  titleStyle: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w500,
                  ),
                  minHeight: 48,
                  padding: EdgeInsets.all(12),
                ),
              ),
            ),
            home: BeakConfiguredForm(
              model: const NoteModel(),
              dataSource: FakeDataSource(),
              onSession: (value) => session = value,
              layout: BeakFormLayout(
                children: [
                  field.inputRadio(
                    cards: true,
                    groupLabelAsField: asField,
                    options: (_) => const [
                      BeakInputOption('company', 'Company invoice'),
                      BeakInputOption('private', 'Private card'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final label = tester.renderObject<RenderParagraph>(
          find.text('Payment method'),
        );
        expect(label.text.style!.fontSize, asField ? 14 : 16);
        expect(label.text.style!.height, asField ? 20 / 14 : 1.5);
        final title = tester.renderObject<RenderParagraph>(
          find.text('Company invoice'),
        );
        expect(title.text.style!.fontSize, 14);
        expect(title.text.style!.height, 20 / 14);
        expect(title.text.style!.fontWeight, FontWeight.w500);
        final choice = find.byType(OiRadioTile<Object>).first;
        expect(tester.getSize(choice).height, 48);
        final choices = find.byType(OiRadioTile<Object>);
        final labelBounds = tester.getRect(find.text("Payment method"));
        final firstBounds = tester.getRect(choices.at(0));
        final secondBounds = tester.getRect(choices.at(1));
        expect(firstBounds.top - labelBounds.bottom, asField ? 6 : 12);
        expect(secondBounds.top - firstBounds.bottom, 8);
        await tester.tap(find.text('Company invoice'));
        await tester.pumpAndSettle();
        expect(session.root.read(field), 'company');
        expect(tester.getSize(choice).height, 48);
      },
    );
  }
}
