import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  final record = BeakRecord.fromRow({
    'id': 'a1',
    'title': 'Launch day',
    'summary': 'Short recap',
    'price': 19.5,
    'stock': 4,
    'active': true,
    'status': 'published',
    'published_at': DateTime(2026, 2, 3, 9, 15),
    'brand_color': '#663399',
    'body': 'Rich body',
    'meta': '{"k":1}',
    'avatar': 'https://cdn.test/a.png',
    'attachment': 'files/a.pdf',
    'category_id': 'c1',
  });

  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakDetailView(model: const ArticleModel(), record: record),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders every detail column formatted by its intent', (
    tester,
  ) async {
    await pumpDetail(tester);

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Launch day'), findsOneWidget);
    expect(find.text('€19.50'), findsOneWidget);
    expect(find.text('2026-02-03 09:15'), findsOneWidget);
    expect(find.text('#663399'), findsOneWidget);
    expect(find.byType(OiBadge), findsNWidgets(2));
    expect(find.text('published'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.byType(OiImage), findsOneWidget);
  });

  testWidgets('renders no Material or Cupertino widgets', (tester) async {
    await pumpDetail(tester);

    const banned = {
      'Material',
      'Scaffold',
      'AppBar',
      'ElevatedButton',
      'TextField',
      'CupertinoApp',
      'CupertinoPageScaffold',
      'MaterialApp',
    };
    final offenders = tester.allWidgets
        .where((widget) => banned.contains(widget.runtimeType.toString()))
        .toList();
    expect(offenders, isEmpty, reason: 'obers_ui only — no Material');
  });
}
