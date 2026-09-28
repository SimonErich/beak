import 'dart:js_interop';

@JS('localStorage')
external _Storage get _storage;

extension type _Storage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

/// Reads an explicitly scoped local draft.
String? readDraft(String key) => _storage.getItem(key);

/// Replaces an explicitly scoped local draft.
void writeDraft(String key, String document) => _storage.setItem(key, document);

/// Removes an explicitly scoped local draft.
void removeDraft(String key) => _storage.removeItem(key);
