import 'dart:convert';
import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:file_selector/file_selector.dart';

import 'beak_record_document.dart';
import 'beak_document_delivery_stub.dart'
    if (dart.library.js_interop) 'beak_document_delivery_web.dart'
    as platform;

/// One presentation attempt, opened during the originating user gesture.
abstract interface class BeakDocumentDelivery {
  /// Presents a frozen snapshot or saves its portable HTML fallback.
  Future<void> show(BeakDocumentSnapshot document);

  /// Closes any empty presentation surface when loading fails or is cancelled.
  void cancel();
}

/// Reserves a browser print window; other platforms use an HTML save dialog.
BeakDocumentDelivery beginBeakDocumentDelivery() => platform.beginDelivery();

/// Portable HTML delivery for hosts without a browser print surface.
final class BeakDocumentDownload implements BeakDocumentDelivery {
  /// Opens no surface until the authorized snapshot is available.
  const BeakDocumentDownload();
  @override
  Future<void> show(BeakDocumentSnapshot document) async {
    try {
      final location = await getSaveLocation(
        suggestedName: document.fileName,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'HTML document', extensions: ['html']),
        ],
      );
      if (location == null) return;
      await XFile.fromData(
        Uint8List.fromList(utf8.encode(document.html)),
        name: document.fileName,
        mimeType: 'text/html',
      ).saveTo(location.path);
    } on Exception {
      throw const BeakStorageException('The document could not be saved.');
    }
  }

  @override
  void cancel() {}
}
