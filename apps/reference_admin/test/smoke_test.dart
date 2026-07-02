import 'package:flutter_test/flutter_test.dart';
import 'package:reference_admin/main.dart';

void main() {
  test('exposes the app version constant', () {
    expect(referenceAdminVersion, '0.0.1');
  });

  testWidgets('boots the placeholder shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ReferenceAdminApp());
    expect(find.byType(ReferenceAdminApp), findsOneWidget);
  });
}
