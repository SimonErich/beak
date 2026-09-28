import '../common/beak_exception.dart';
import '../model/beak_model.dart';
import '../query/beak_record.dart';

/// Optional transport for authoritative model validation without writing data.
abstract interface class BeakValidationDataSource {
  /// Checks trusted server declarations, excluding the current id on edits.
  Future<BeakValidationReport> validateRecord(BeakValidationRequest request);
}

/// Candidate values sent for authoritative validation; rules stay server-owned.
final class BeakValidationRequest {
  /// Creates a transport request for [table]. Prefer [forModel] in app code.
  const BeakValidationRequest({
    required this.table,
    required this.record,
    this.recordId,
  });

  /// Creates a request without repeating the model's table name.
  BeakValidationRequest.forModel(BeakModel model, this.record, {this.recordId})
    : table = model.table;

  /// Model being validated.
  final String table;

  /// Candidate values and staged relation contents.
  final BeakRecord record;

  /// Existing identity for edits; null means creation.
  final Object? recordId;

  /// Serializes candidate state only, never executable rules or query scopes.
  Map<String, Object?> toJson() => {
    'table': table,
    'record': record.toJson(),
    if (recordId != null) 'recordId': recordId,
  };

  /// Decodes the public validation request.
  factory BeakValidationRequest.fromJson(Map<String, Object?> json) {
    final table = json['table'];
    final record = json['record'];
    final id = json['recordId'];
    if (table is! String ||
        table.isEmpty ||
        record is! Map<String, Object?> ||
        (id != null && id is! String && id is! int)) {
      throw const BeakConfigurationException('Invalid validation request.');
    }
    return BeakValidationRequest(
      table: table,
      record: BeakRecord.fromJson(record),
      recordId: id,
    );
  }
}

/// Structured validation errors safe to route back to their typed form fields.
final class BeakValidationReport {
  /// Creates a report; an empty map means the current candidate is valid.
  const BeakValidationReport({this.fieldErrors = const {}});

  /// Field or relation paths with all actionable errors.
  final Map<String, List<String>> fieldErrors;

  /// Whether this candidate passed the checks that were evaluated.
  bool get valid => fieldErrors.isEmpty;

  /// Serializes the report for an optional remote validation transport.
  Map<String, Object?> toJson() => {'fieldErrors': fieldErrors};

  /// Decodes a report, rejecting malformed field errors.
  factory BeakValidationReport.fromJson(Map<String, Object?> json) {
    final raw = json['fieldErrors'];
    if (raw is! Map<String, Object?>) {
      throw const BeakConfigurationException('Invalid validation report.');
    }
    final errors = <String, List<String>>{};
    for (final entry in raw.entries) {
      final messages = entry.value;
      if (messages is! List<Object?> ||
          messages.any((message) => message is! String)) {
        throw const BeakConfigurationException('Invalid validation messages.');
      }
      errors[entry.key] = messages.whereType<String>().toList(growable: false);
    }
    return BeakValidationReport(fieldErrors: errors);
  }
}
