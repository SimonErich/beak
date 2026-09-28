import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  const column = BeakImageColumn(
    key: 'image',
    label: 'Image',
    storagePath: 'pictures',
  );
  testWidgets('stored image resolves its key and shows a loading state', (
    tester,
  ) async {
    final client = _Urls();
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakStoredImage(
          column: column,
          storageKey: 'pictures/key.png',
          alt: 'Front view',
          table: 'pictures',
          client: client,
        ),
      ),
    );
    expect(find.text('Loading image…'), findsOneWidget);
    expect(client.calls, [('pictures', 'image', 'pictures/key.png')]);
    client.url.complete(Uri.parse('https://cdn.example.com/signed.png'));
    await tester.pumpAndSettle();
    expect(find.text('Loading image…'), findsNothing);
    final image = tester.widget<OiImage>(find.byType(OiImage));
    expect(image.src, 'https://cdn.example.com/signed.png');
    expect(image.alt, 'Front view');
    expect(tester.takeException(), isNull);
  });
  testWidgets('resolution failure becomes a placeholder without throwing', (
    tester,
  ) async {
    final client = _Urls();
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakStoredImage(
          column: column,
          storageKey: 'pictures/missing.png',
          alt: 'Missing picture',
          table: 'pictures',
          client: client,
        ),
      ),
    );
    client.url.completeError(const BeakNotFoundException('Gone'));
    await tester.pumpAndSettle();
    expect(find.text('Loading image…'), findsNothing);
    expect(find.byType(OiIcon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _Urls implements BeakUploadUrlClient {
  final url = Completer<Uri>();
  final List<(String, String, String)> calls = [];
  @override
  Future<Uri> uploadUrl(String table, String columnKey, String key) {
    calls.add((table, columnKey, key));
    return url.future;
  }
}
