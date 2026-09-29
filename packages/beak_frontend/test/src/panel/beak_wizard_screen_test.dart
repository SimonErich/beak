import 'dart:io';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

/// The `BeakFormScreen` parameters a wizard deliberately does not take, with
/// the reason each cannot work over steps.
const Map<String, String> _notOnWizards = {
  'layout': 'a wizard is laid out by its steps',
  'recordHeader': 'the record heading belongs to the single-page frame',
  'editingLabel': 'the editing badge belongs to the single-page heading',
};

/// The named parameters [className]'s generative constructor forwards to
/// its field or to its super constructor (`this.x` or `super.x`).
Set<String> _constructorParameters(String source, String className) {
  final start = source.indexOf('  const $className({');
  final end = source.indexOf('  });', start);
  return {
    for (final match in RegExp(
      r'(?:this|super)\.(\w+)',
    ).allMatches(source.substring(start, end)))
      match.group(1)!,
  };
}

void main() {
  test(
    'BeakWizardScreen forwards every BeakFormScreen parameter it can honour',
    () {
      final source = File(
        'lib/src/panel/beak_resource_screen.dart',
      ).readAsStringSync();
      final form = _constructorParameters(source, 'BeakFormScreen');
      final wizard = _constructorParameters(source, 'BeakWizardScreen');

      expect(form, isNotEmpty);
      expect(
        form.difference(wizard),
        _notOnWizards.keys.toSet(),
        reason:
            'A BeakFormScreen parameter that BeakWizardScreen neither forwards '
            'nor lists in _notOnWizards is silently dropped.',
      );
      expect(wizard.difference(form), isEmpty);
    },
  );

  test('a wizard carries every option it forwards', () {
    const screen = BeakWizardScreen(
      steps: [BeakWizardStep(title: 'One', children: [])],
      asideFraction: 0.25,
      asideWidthInPixels: 300,
      submitIcon: OiIcons.check,
      outlinedCancel: true,
      showActionsWhileEditing: false,
      showChangeBar: true,
      showBack: false,
      pagePadding: EdgeInsets.all(48),
      pageGapInPixels: 40,
    );

    expect(screen.asideFraction, 0.25);
    expect(screen.asideWidthInPixels, 300);
    expect(screen.submitIcon, OiIcons.check);
    expect(screen.outlinedCancel, isTrue);
    expect(screen.showActionsWhileEditing, isFalse);
    expect(screen.showChangeBar, isTrue);
    expect(screen.showBack, isFalse);
    expect(screen.pagePadding, const EdgeInsets.all(48));
    expect(screen.pageGapInPixels, 40);
    expect(screen.layout, isNull);
  });

  group('the page chrome options act on a wizard', () {
    Future<void> openCreate(
      WidgetTester tester,
      BeakWizardScreen wizard,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        BeakPanel(
          dataSource: FakeDataSource(models: const [NoteModel()]),
          resources: [
            BeakResource(model: const NoteModel(), screens: [wizard]),
          ],
        ),
      );
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(OiAppShell))).go('/notes/create');
      await tester.pumpAndSettle();
    }

    BeakWizardScreen wizard({
      bool showBack = true,
      EdgeInsetsGeometry? pagePadding,
    }) => BeakWizardScreen(
      showBack: showBack,
      pagePadding: pagePadding,
      steps: const [
        BeakWizardStep(
          title: 'Basics',
          children: [
            BeakInput<Object>(
              field: BeakScalarField<Object>(
                model: NoteModel(),
                column: BeakStringColumn(key: 'title', label: 'Title'),
              ),
            ),
          ],
        ),
      ],
    );

    testWidgets('showBack keeps the Back control by default', (tester) async {
      await openCreate(tester, wizard());
      expect(find.byType(BeakBackButton), findsOneWidget);
    });

    testWidgets('showBack: false hides the Back control', (tester) async {
      await openCreate(tester, wizard(showBack: false));
      expect(find.byType(BeakBackButton), findsNothing);
    });

    testWidgets('pagePadding insets the page', (tester) async {
      await openCreate(tester, wizard(pagePadding: const EdgeInsets.all(96)));

      final layout = tester.widget<OiPageLayout>(
        find.byType(OiPageLayout).first,
      );
      expect(layout.padding, const EdgeInsets.all(96));
    });
  });
}
