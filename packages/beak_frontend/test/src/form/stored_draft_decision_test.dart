import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _title = BeakScalarField<String>(
  model: NoteModel(),
  column: BeakStringColumn(key: 'title', label: 'Title'),
);

void main() {
  testWidgets('Save waits while a stored draft asks to be resumed or dropped', (
    tester,
  ) async {
    final config = BeakFormDrafts(
      store: BeakMemoryDraftStore(),
      key: 'note',
      context: 'reader',
      debounce: Duration.zero,
    );
    final layout = BeakFormLayout(children: [_title.inputText()]);
    final writer = BeakFormSession(
      model: const NoteModel(),
      dataSource: FakeDataSource(),
      layout: layout,
      drafts: config,
    );
    await writer.load();
    writer.root.set(_title, 'Left over');
    expect(await writer.persistDraft(), isTrue);
    writer.dispose();

    final source = FakeDataSource();
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: const NoteModel(),
          dataSource: source,
          layout: layout,
          drafts: config,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('An unfinished draft is available'), findsOneWidget);
    OiButton save() => tester.widget(find.widgetWithText(OiButton, 'Save'));
    expect(save().onTap, isNull, reason: 'a tap would do nothing, silently');

    await tester.tap(find.text('Discard saved draft'));
    await tester.pumpAndSettle();
    expect(find.text('An unfinished draft is available'), findsNothing);
    expect(save().onTap, isNotNull);
  });
}
