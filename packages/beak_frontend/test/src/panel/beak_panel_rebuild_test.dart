import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  testWidgets('a rebuilt parent that passes the same configuration keeps the '
      'router', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const config = BeakPanelConfig(
      title: 'Demo',
      resources: [
        BeakResource(model: NoteModel(), icon: BeakIconToken(OiIcons.file)),
      ],
    );
    final source = FakeDataSource();
    final rebuild = ValueNotifier(0);
    addTearDown(rebuild.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<int>(
        valueListenable: rebuild,
        builder: (context, _, _) =>
            BeakPanel(config: config, dataSource: source),
      ),
    );
    await tester.pumpAndSettle();
    final before = GoRouter.of(tester.element(find.byType(OiAppShell)));

    rebuild.value++;
    await tester.pumpAndSettle();

    expect(GoRouter.of(tester.element(find.byType(OiAppShell))), same(before));
  });
}
