import 'dart:async';

import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  Future<void> openDirtyCreateForm(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(
        resources: const [BeakResource(model: NoteModel())],
        dataSource: FakeDataSource(),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
    unawaited(router.push<void>('/notes/create'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'Unsaved');
    await tester.pumpAndSettle();
  }

  testWidgets('the system back gesture on a dirty form asks, and Stay stays', (
    tester,
  ) async {
    await openDirtyCreateForm(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave this form?'), findsWidgets);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.byType(BeakConfiguredForm), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      'Unsaved',
    );
  });

  testWidgets('the system back gesture leaves once the user agrees', (
    tester,
  ) async {
    await openDirtyCreateForm(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes').last);
    await tester.pumpAndSettle();

    expect(find.byType(BeakConfiguredForm), findsNothing);
    expect(find.text('Leave this form?'), findsNothing);
  });

  testWidgets('a clean form goes back without a question', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(
        resources: const [BeakResource(model: NoteModel())],
        dataSource: FakeDataSource(),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
    unawaited(router.push<void>('/notes/create'));
    await tester.pumpAndSettle();
    expect(find.byType(BeakConfiguredForm), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(BeakConfiguredForm), findsNothing);
    expect(find.text('Leave this form?'), findsNothing);
  });
}
