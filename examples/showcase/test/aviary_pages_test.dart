import 'package:beak/panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcase/main.dart';
import 'package:showcase/widgets/band_code_cell.dart';

import 'support/aviary_pump.dart';

void main() {
  setUp(registerAviaryRenderers);
  tearDown(BeakCustomRenderers.reset);

  final BeakPanel panel = buildPanel();
  for (final page in panel.pages) {
    testWidgets('${page.title} renders', (tester) async {
      await pumpAviaryAt(tester, page.path);

      expect(tester.takeException(), isNull);
      expect(find.byType(BeakBlockHost), findsWidgets);
    });
  }
}
