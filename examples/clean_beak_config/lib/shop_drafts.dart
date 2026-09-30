import 'package:beak/panel.dart';
import 'package:flutter/foundation.dart';

final BeakDraftStore _shopDraftStore = kIsWeb
    ? const BeakBrowserDraftStore()
    : BeakMemoryDraftStore();

/// Resumable drafts for this single-user, local demonstration panel.
///
/// An authenticated host supplies its stable user and tenant identity here.
BeakFormDrafts shopDrafts(String form) => BeakFormDrafts(
  store: _shopDraftStore,
  key: form,
  context: 'clean-shop:local-demo',
  schemaVersion: 2,
);
