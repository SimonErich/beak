/// Server-resolved field access for one resource and current identity.
///
/// Null sets allow every field; empty sets allow none. These values guide
/// presentation. The server rechecks its policy on every read and write.
final class BeakAccessCapabilities {
  /// Creates an access description, unrestricted unless a set is supplied.
  const BeakAccessCapabilities({
    this.readableFields,
    this.writableFields,
    this.executableActions,
  });

  /// Fields the current identity may read, or null for all fields.
  final Set<String>? readableFields;

  /// Fields the current identity may write, or null for all fields.
  final Set<String>? writableFields;

  /// Named model actions permitted for this account, or null when unspecified.
  final Set<String>? executableActions;

  /// Whether a named model action may be offered to this identity.
  bool canExecuteAction(String name) =>
      executableActions?.contains(name) ?? true;

  /// Whether [key] may be displayed or queried.
  bool canRead(String key) => readableFields?.contains(key) ?? true;

  /// Whether [key] may be submitted by this identity.
  bool canWrite(String key) => writableFields?.contains(key) ?? true;

  /// Encodes the access description at the transport boundary.
  Map<String, Object?> toJson() => {
    'readableFields': readableFields?.toList(),
    'writableFields': writableFields?.toList(),
    'executableActions': executableActions?.toList(),
  };

  /// Decodes a server access description, rejecting malformed allowlists.
  factory BeakAccessCapabilities.fromJson(Map<String, Object?> json) =>
      BeakAccessCapabilities(
        readableFields: _fields(json['readableFields']),
        writableFields: _fields(json['writableFields']),
        executableActions: _fields(json['executableActions']),
      );

  static Set<String>? _fields(Object? value) {
    if (value == null) return null;
    if (value is! List<Object?> || value.any((key) => key is! String)) {
      throw const FormatException('Field capabilities must be string lists.');
    }
    return Set.unmodifiable(value.whereType<String>());
  }
}

/// Optional data-source capability for server-authoritative field permissions.
abstract interface class BeakCapabilityDataSource {
  /// Resolves access for the current identity, optionally targeting a record.
  Future<BeakAccessCapabilities> capabilities(String table, {Object? id});
}
