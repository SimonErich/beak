import 'dart:js_interop';

import 'beak_document_delivery.dart';
import 'beak_record_document.dart';

@JS('window.open')
external _PrintWindow? _open(String url, String target);

extension type _PrintWindow(JSObject _) implements JSObject {
  external _Document get document;
  external set opener(JSAny? value);
  external bool get closed;
  external void focus();
  external void print();
  external void close();
}

extension type _Document(JSObject _) implements JSObject {
  external void open();
  external void write(String html);
  external void close();
}

/// Reserves the print surface before asynchronous authorized record loading.
BeakDocumentDelivery beginDelivery() {
  final window = _open('', '_blank');
  if (window == null) return const BeakDocumentDownload();
  window.opener = null;
  return _BrowserDelivery(window);
}

final class _BrowserDelivery implements BeakDocumentDelivery {
  const _BrowserDelivery(this.window);
  final _PrintWindow window;
  @override
  Future<void> show(BeakDocumentSnapshot document) async {
    if (window.closed) return;
    window.document.open();
    window.document.write(document.html);
    window.document.close();
    window.focus();
    window.print();
  }

  @override
  void cancel() {
    if (!window.closed) window.close();
  }
}
