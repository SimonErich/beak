import 'dart:convert';

import 'package:beak_core/beak_core.dart';

import 'beak_form_drafts_stub.dart'
    if (dart.library.js_interop) 'beak_form_drafts_web.dart'
    as platform;

/// Storage boundary for resumable form drafts. Contents are JSON, not records
/// committed to the application database. Scope keys to an authenticated user.
abstract interface class BeakDraftStore {
  /// Reads the last completed write for [key].
  Future<String?> read(String key);

  /// Atomically replaces the previous draft document.
  Future<void> write(String key, String document);

  /// Removes an abandoned or successfully committed draft.
  Future<void> remove(String key);
}

/// In-memory store useful in native hosts, tests, and short-lived navigation.
final class BeakMemoryDraftStore implements BeakDraftStore {
  final Map<String, String> _documents = {};
  @override
  Future<String?> read(String key) async => _documents[key];
  @override
  Future<void> write(String key, String document) async =>
      _documents[key] = document;
  @override
  Future<void> remove(String key) async => _documents.remove(key);
}

/// Browser local-storage adapter; native hosts supply their own [BeakDraftStore].
/// Storage errors are reported by the form without losing its in-memory edits.
final class BeakBrowserDraftStore implements BeakDraftStore {
  /// Creates a store whose keys are namespaced by [BeakFormDrafts].
  const BeakBrowserDraftStore();
  @override
  Future<String?> read(String key) async => platform.readDraft(key);
  @override
  Future<void> write(String key, String document) async =>
      platform.writeDraft(key, document);
  @override
  Future<void> remove(String key) async => platform.removeDraft(key);
}

/// Opt-in resumable drafts. Passwords and uncommitted file bytes are excluded.
/// A redacted recovery snapshot is stored before submission. After interruption,
/// the form checks the same save receipt and stays frozen until its outcome is
/// known; it never replays stored operations. Durable receipt support belongs to
/// the configured [BeakCommitDataSource].
final class BeakFormDrafts {
  /// [context] must distinguish the signed-in user and tenant. Change
  /// [schemaVersion] whenever the meaning or shape of the form changes.
  const BeakFormDrafts({
    required this.store,
    required this.key,
    required this.context,
    this.schemaVersion = 1,
    this.retention = const Duration(days: 7),
    this.debounce = const Duration(milliseconds: 300),
  });

  /// Durable or host-provided storage.
  final BeakDraftStore store;

  /// Stable identity of this form definition.
  final String key;

  /// Explicit authenticated user/tenant namespace, never an access token.
  final String context;

  /// Application-controlled format migration boundary.
  final int schemaVersion;

  /// Unsubmitted drafts older than this duration are discarded on load.
  /// Pending save identities are retained until receipt recovery resolves them.
  final Duration retention;

  /// Delay before serializing successive local edits.
  final Duration debounce;

  /// Unambiguous namespace including record identity and scalar identity type.
  String storageKey(String table, Object? id) =>
      'beak:draft:${jsonEncode([context, key, table, id?.runtimeType.toString(), id])}';
}

/// One proposed change in a draft's record graph, suitable for review screens.
final class BeakDraftChange {
  /// Describes a scalar change or a relationship membership change.
  const BeakDraftChange({
    required this.path,
    required this.label,
    required this.kind,
    this.before,
    this.after,
    this.column,
  });

  /// Stable graph path including local row identities.
  final String path;

  /// Human-readable model field or relationship label.
  final String label;

  /// Nature of the proposed change.
  final BeakDraftChangeKind kind;

  /// Metadata used for the panel's normal value formatting.
  final BeakColumn? column;

  /// Persisted value, redacted for password fields.
  final BeakValue? before;

  /// Proposed value, redacted for password fields.
  final BeakValue? after;
}

/// Change categories displayed in a review.
enum BeakDraftChangeKind {
  /// A field changed.
  update,

  /// A new related record will be created.
  create,

  /// An existing relationship will be detached.
  detach,

  /// An owned related record will be deleted.
  delete,
}

/// A server value and local value both changed since a draft's saved baseline.
final class BeakDraftConflict {
  /// Creates a conflict which must be resolved before submitting the form.
  const BeakDraftConflict({
    required this.path,
    required this.label,
    required this.original,
    required this.local,
    required this.remote,
    this.column,
  });

  /// Stable path used by the session to resolve this conflict.
  final String path;

  /// Field or record label shown by the conflict review.
  final String label;

  /// Metadata used for consistent currency, date and semantic formatting.
  final BeakColumn? column;

  /// Value when editing began.
  final BeakValue? original;

  /// User's proposed value.
  final BeakValue? local;

  /// Most recently fetched server value.
  final BeakValue? remote;
}

/// Development diagnostics for a configured input. Values are intentionally
/// excluded so opening the inspector does not expose passwords or file bytes.
final class BeakFieldExplanation {
  /// Creates an inspection entry from compiled configuration and current state.
  const BeakFieldExplanation({
    required this.path,
    required this.label,
    required this.visible,
    required this.enabled,
    required this.origin,
    required this.dependencies,
    required this.validation,
  });

  /// Stable field path in the draft graph.
  final String path;

  /// Input's effective label.
  final String label;

  /// Whether all enclosing visibility conditions permit display.
  final bool visible;

  /// Whether all editability and prerequisite conditions permit editing.
  final bool enabled;

  /// How the current value is supplied.
  final String origin;

  /// Tracked calculation and eligibility dependencies.
  final List<String> dependencies;

  /// Active validation rule descriptions and current errors.
  final List<String> validation;
}
