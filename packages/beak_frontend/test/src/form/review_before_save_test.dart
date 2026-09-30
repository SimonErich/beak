import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource source;

  setUp(() => source = FakeDataSource());

  Future<void> pumpReviewedForm(
    WidgetTester tester, {
    BeakModel model = const NoteModel(),
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: model,
          dataSource: source,
          reviewBeforeSave: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'Reviewed');
    await tester.pumpAndSettle();
  }

  testWidgets('Continue in the review saves, Back keeps editing', (
    tester,
  ) async {
    await pumpReviewedForm(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(source.createCalls, isEmpty);
    expect(find.text('Continue'), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(source.createCalls, hasLength(1));
    expect(
      source.createCalls.single.$2['title'],
      const BeakStringValue('Reviewed'),
    );
  });

  testWidgets('a double tap on Save opens one review and saves once', (
    tester,
  ) async {
    // The authoritative check is slow, so the second tap lands while the first
    // is still validating: the window a real double click has.
    final check = Completer<BeakValidationReport>();
    final slow = _SlowValidation(check);
    source = slow;
    await pumpReviewedForm(tester, model: const _UniqueTitleModel());

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    check.complete(const BeakValidationReport());
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsNothing);
    expect(source.createCalls, hasLength(1));
  });
}

/// Answers the authoritative validation only when the test says so.
final class _SlowValidation extends FakeDataSource
    implements BeakValidationDataSource {
  _SlowValidation(this._answer) : super(models: const [_UniqueTitleModel()]);

  final Completer<BeakValidationReport> _answer;

  @override
  Future<BeakValidationReport> validateRecord(BeakValidationRequest request) =>
      _answer.future;
}

/// A note whose title must be unique, so saving asks the server to check it.
final class _UniqueTitleModel extends BeakModel {
  const _UniqueTitleModel();

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'title', label: 'Title', unique: true),
  ];
}
