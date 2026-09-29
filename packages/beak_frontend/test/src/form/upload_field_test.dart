import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_frontend/src/form/beak_form_controller_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late BeakFormController controller;
  late _RecordingUploader uploader;

  setUp(() {
    controller = BeakFormController(model: const ArticleModel());
    uploader = _RecordingUploader();
    addTearDown(controller.dispose);
  });

  BeakUpload png(int sizeInBytes) => BeakUpload(
    filename: 'photo.png',
    mimeType: 'image/png',
    bytes: Uint8List(sizeInBytes),
  );

  Future<void> pumpField(
    WidgetTester tester, {
    required BeakUpload? Function() pick,
  }) async {
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakUploadField(
          controller: controller,
          column: ArticleColumns.avatar,
          uploader: uploader,
          filePicker: () async => pick(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a valid pick uploads and stores the returned key', (
    tester,
  ) async {
    await pumpField(tester, pick: () => png(8));

    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    expect(uploader.calls, [('articles', 'avatar')]);
    expect(
      controller.valueOf<String>(ArticleColumns.avatar),
      'articles/avatars/stored.png',
    );
    expect(find.byType(OiImage), findsOneWidget);
    final OiImage preview = tester.widget(find.byType(OiImage));
    expect(preview.src, 'https://cdn.test/thumb.png');
  });

  testWidgets('an oversize file is rejected client-side before upload', (
    tester,
  ) async {
    await pumpField(tester, pick: () => png(17));

    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    expect(uploader.calls, isEmpty);
    expect(controller.valueOf<String>(ArticleColumns.avatar), isNull);
    expect(
      find.textContaining('exceeding the limit of 16 bytes'),
      findsOneWidget,
    );
  });

  testWidgets('a disallowed type is rejected with the rule message', (
    tester,
  ) async {
    await pumpField(
      tester,
      pick: () => BeakUpload(
        filename: 'notes.pdf',
        mimeType: 'application/pdf',
        bytes: Uint8List(4),
      ),
    );

    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    expect(uploader.calls, isEmpty);
    expect(
      find.textContaining('The MIME type "application/pdf" is not allowed.'),
      findsOneWidget,
    );
  });

  testWidgets('a backend rejection surfaces its message', (tester) async {
    uploader.failure = const BeakStorageException('bucket offline');
    await pumpField(tester, pick: () => png(8));

    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    expect(find.textContaining('bucket offline'), findsOneWidget);
    expect(controller.valueOf<String>(ArticleColumns.avatar), isNull);
  });

  testWidgets('a cancelled pick is a no-op', (tester) async {
    await pumpField(tester, pick: () => null);

    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    expect(uploader.calls, isEmpty);
    expect(find.byType(OiImage), findsNothing);
  });

  testWidgets('renders disabled without an uploader', (tester) async {
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakUploadField(
          controller: controller,
          column: ArticleColumns.avatar,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final OiButton button = tester.widget(
      find.widgetWithText(OiButton, 'Choose file'),
    );
    expect(button.onTap, isNull, reason: 'no uploader — the pick is off');
    expect(find.byType(OiImage), findsNothing);
  });
}

/// Records upload calls and returns a canned stored file (or throws
/// [failure] when set).
final class _RecordingUploader implements BeakUploadClient {
  final List<(String, String)> calls = [];
  BeakException? failure;

  @override
  Future<BeakStoredFile> upload(
    String table,
    String columnKey,
    BeakUpload file,
  ) async {
    final BeakException? pending = failure;
    if (pending != null) {
      throw pending;
    }
    calls.add((table, columnKey));
    return BeakStoredFile(
      key: 'articles/avatars/stored.png',
      url: Uri.parse('https://cdn.test/stored.png'),
      sizeInBytes: file.sizeInBytes,
      mimeType: file.mimeType,
      variants: {
        'thumbnail': BeakStoredFileVariant(
          key: 'articles/avatars/stored_thumb.png',
          url: Uri.parse('https://cdn.test/thumb.png'),
        ),
      },
    );
  }
}
