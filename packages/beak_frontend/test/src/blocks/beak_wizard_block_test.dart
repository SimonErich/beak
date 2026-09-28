import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, BeakBlock block) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakBlockHost(block: block),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders an OiWizard with the first step body', (tester) async {
    await pump(
      tester,
      const BeakWizardBlock(
        stepperStyle: OiStepperStyle.horizontal,
        steps: [
          BeakBlockWizardStep(
            title: 'Seller',
            body: BeakTextBlock('seller step body'),
          ),
          BeakBlockWizardStep(
            title: 'Bank',
            body: BeakTextBlock('bank step body'),
          ),
        ],
      ),
    );

    final wizard = tester.widget<OiWizard>(find.byType(OiWizard));
    expect(wizard.steps, hasLength(2));
    expect(wizard.stepperStyle, OiStepperStyle.horizontal);
    expect(find.text('seller step body'), findsOneWidget);
  });

  testWidgets('a step canAdvance gate is threaded to the wizard step', (
    tester,
  ) async {
    var allowed = false;
    await pump(
      tester,
      BeakWizardBlock(
        steps: [
          BeakBlockWizardStep(
            title: 'One',
            body: const BeakTextBlock('one'),
            canAdvance: () => allowed,
          ),
          const BeakBlockWizardStep(title: 'Two', body: BeakTextBlock('two')),
        ],
      ),
    );

    final wizard = tester.widget<OiWizard>(find.byType(OiWizard));
    final validate = wizard.steps.first.validate;
    expect(validate, isNotNull);
    expect(validate!(const {}), isFalse);
    allowed = true;
    expect(validate(const {}), isTrue);
  });
}
