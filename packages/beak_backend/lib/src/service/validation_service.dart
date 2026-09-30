import 'package:beak_core/beak_core.dart';

// --8<-- [start:ValidationService]
/// Applies the shared core validator at the backend write boundary.
final class ValidationService {
  /// Creates the stateless validation boundary.
  const ValidationService();

  /// Rejects malformed fields and shared model rules with structured errors.
  /// [initial] supplies omitted fields and relations for partial updates.
  /// Graph commits defer record rules until the final transaction state exists.
  void validate(
    BeakModel model,
    BeakRecord input, {
    required bool isCreate,
    BeakRecord? initial,
    bool includeRecordRules = true,
  }) {
    final errors = const BeakValidation().validate(
      model,
      input,
      isCreate: isCreate,
      initial: initial,
      includeRecordRules: includeRecordRules,
    );
    if (errors.isNotEmpty) {
      throw BeakValidationException(
        'Validation failed for "${model.table}".',
        fieldErrors: errors,
      );
    }
  }
}
// --8<-- [end:ValidationService]
