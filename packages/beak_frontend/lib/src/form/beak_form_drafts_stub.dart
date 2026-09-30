/// Native applications should inject a platform-specific draft store.
String? readDraft(String key) => throw UnsupportedError(
  'Browser draft storage is only available on the web. Supply a BeakDraftStore on this platform.',
);

/// Native applications should inject a platform-specific draft store.
void writeDraft(String key, String document) => readDraft(key);

/// Native applications should inject a platform-specific draft store.
void removeDraft(String key) => readDraft(key);
