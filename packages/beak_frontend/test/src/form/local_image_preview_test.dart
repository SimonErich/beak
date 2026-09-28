import 'dart:async';
import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';

Future<void> _expectDecodedImage(WidgetTester tester) async {
  final image = tester.widget<Image>(find.byType(Image));
  final decoded = await tester.runAsync(() async {
    final result = Completer<ImageInfo?>();
    final stream = image.image.resolve(
      createLocalImageConfiguration(tester.element(find.byType(Image))),
    );
    final listener = ImageStreamListener(
      (info, _) => result.complete(info),
      onError: (Object error, StackTrace? stack) => result.complete(null),
    );
    stream.addListener(listener);
    try {
      return await result.future.timeout(const Duration(seconds: 5));
    } finally {
      stream.removeListener(listener);
    }
  });
  expect(
    decoded,
    isNotNull,
    reason:
        'A local PNG preview must decode, not become an asset-load placeholder.',
  );
  expect(decoded?.image.width, 1);
  expect(decoded?.image.height, 1);
  decoded?.dispose();
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('stored image decodes a direct image data URI', (tester) async {
    final assets = _HostAssets();
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: DefaultAssetBundle(
          bundle: assets,
          child: const BeakStoredImage(
            column: _Pictures.picture,
            storageKey: 'data:image/png;base64,$_png',
            alt: 'Local image',
          ),
        ),
      ),
    );
    await _expectDecodedImage(tester);
    final bundle = DefaultAssetBundle.of(tester.element(find.byType(Image)));
    expect(await bundle.loadString('assets/other.txt'), 'host asset');
    expect(
      assets.requests,
      containsAll(['AssetManifest.bin', 'assets/other.txt']),
    );
    expect(assets.requests.any((key) => key.startsWith('data:')), isFalse);
  });

  testWidgets('choosing a draft file decodes its preview without uploading', (
    tester,
  ) async {
    final server = _Uploads();
    final uploads = BeakDraftUploads(server);
    addTearDown(uploads.dispose);
    final controller = BeakFormController(model: const _Pictures());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakUploadField(
          controller: controller,
          column: _Pictures.picture,
          uploader: uploads,
          filePicker: () async => BeakUpload(
            filename: 'local.png',
            mimeType: 'image/png',
            bytes: base64Decode(_png),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(
      controller.valueOf<String>(_Pictures.picture),
      startsWith('beak-draft:'),
    );
    expect(find.text('local.png'), findsOneWidget);
    expect(server.calls, 0);
    await _expectDecodedImage(tester);
  });

  testWidgets('malformed image data URI displays the image placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: const BeakStoredImage(
          column: _Pictures.picture,
          storageKey: 'data:image/png;base64,invalid',
          alt: 'Invalid image',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OiIcon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _HostAssets extends CachingAssetBundle {
  final List<String> requests = [];

  @override
  Future<ByteData> load(String key) {
    requests.add(key);
    return key == 'assets/other.txt'
        ? Future.value(
            ByteData.sublistView(Uint8List.fromList(utf8.encode('host asset'))),
          )
        : rootBundle.load(key);
  }
}

final class _Pictures extends BeakModel {
  const _Pictures();
  static const picture = BeakImageColumn(
    key: 'picture',
    label: 'Picture',
    storagePath: 'pictures',
  );
  @override
  String get table => 'pictures';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    picture,
  ];
}

final class _Uploads implements BeakUploadClient {
  int calls = 0;
  @override
  Future<BeakStoredFile> upload(
    String table,
    String columnKey,
    BeakUpload file,
  ) async {
    calls++;
    throw StateError('The preview must not upload.');
  }
}
