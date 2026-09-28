import 'package:meta/meta.dart';

import '../storage/file_rules/beak_file_type.dart';
import '../columns/beak_semantic_values.dart';
import '../columns/beak_json.dart';

part 'beak_allowed_file_types.dart';
part 'beak_email.dart';
part 'beak_future_date.dart';
part 'beak_in_list.dart';
part 'beak_max.dart';
part 'beak_max_file_size.dart';
part 'beak_max_length.dart';
part 'beak_min.dart';
part 'beak_min_length.dart';
part 'beak_pattern.dart';
part 'beak_required.dart';
part 'beak_url.dart';

/// Base of every declarative validation rule a column can carry.
///
/// The hierarchy is sealed so both ends of the wire (form validation in
/// `beak_frontend`, request validation in `beak_backend`) can switch
/// exhaustively over rules. Each rule pattern-matches the runtime type of the
/// value it receives: a rule that does not apply to the value's type reports
/// it as valid, so rules compose freely and presence stays [BeakRequired]'s
/// job alone.
///
/// Attach rules to a column's `rules` list; they run in order and the first
/// non-null message wins:
///
/// ```dart
/// static const email = BeakStringColumn(
///   key: 'email',
///   label: 'Email',
///   rules: [BeakRequired(), BeakEmail(), BeakMaxLength(255)],
/// );
///
/// // Because non-applicable types pass, the value's own type decides which
/// // rules bite:
/// const rule = BeakMaxLength(3);
/// rule.validate('abcd'); // 'Must be at most 3 characters.'
/// rule.validate(42);     // null (not a string)
/// ```
// --8<-- [start:BeakRule]
@immutable
sealed class BeakRule {
  const BeakRule();

  /// Stable machine-readable identity for serialization to either side of
  /// the wire.
  String get id;

  /// Returns `null` when [value] is valid, else a human-readable message.
  String? validate(Object? value);
}

// --8<-- [end:BeakRule]

// Compare a fixed decimal and a numeric rule bound without rounding either.
int _compareDecimalBound(BeakDecimal value, num bound) {
  if (!bound.isFinite) return bound.isNegative ? 1 : -1;
  final parts = RegExp(
    r'^(-?)([0-9]+)(?:\.([0-9]+))?(?:[eE]([+-]?[0-9]+))?$',
  ).firstMatch(bound.toString())!;
  final fraction = parts.group(3) ?? '';
  final exponent = int.parse(parts.group(4) ?? '0');
  final boundScale = fraction.length - exponent;
  final scale = [value.scale, boundScale, 0].reduce((a, b) => a > b ? a : b);
  final coefficient = BigInt.parse(
    '${parts.group(1)}${parts.group(2)}$fraction',
  );
  return (BigInt.from(value.units) * BigInt.from(10).pow(scale - value.scale))
      .compareTo(coefficient * BigInt.from(10).pow(scale - boundScale));
}
