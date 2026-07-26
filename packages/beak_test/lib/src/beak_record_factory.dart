import 'dart:math';

import 'package:beak_core/beak_core.dart';

import 'in_memory_beak_data_source.dart';

/// Builds records that satisfy a model's own column metadata and rules.
///
/// Hand-written fixtures drift from the model the moment a rule changes: a
/// `BeakMaxLength(60)` added today makes yesterday's 200-character fixture a
/// lie that no test catches until the API rejects it. Deriving the fixture
/// from the same metadata the validator reads keeps them in step by
/// construction.
///
/// Deterministic under a fixed [seed], so a failing test reproduces.
///
/// ```dart
/// final factory = BeakRecordFactory(seed: 7);
/// final record = factory.build(const ProductModel());
/// final overridden = factory.build(
///   const ProductModel(),
///   overrides: {ProductColumns.name.key: BeakValue.of('Espresso')},
/// );
/// ```
final class BeakRecordFactory {
  /// Creates a factory whose values are reproducible under [seed].
  BeakRecordFactory({int seed = 20260726}) : _random = Random(seed);

  final Random _random;
  int _sequence = 0;

  /// A record for [model] with a plausible value per column.
  ///
  /// Columns present in [overrides] take that value verbatim. Columns the
  /// model marks detail-only, such as timestamps, are still populated — a
  /// fixture that omits them cannot exercise a detail view.
  BeakRecord build(
    BeakModel model, {
    Map<String, BeakValue> overrides = const {},
  }) {
    _sequence += 1;
    return BeakRecord(
      values: {
        for (final column in model.columns)
          if (!_isSoftDeleteMarker(model, column))
            column.key: overrides[column.key] ?? _valueFor(model, column),
        ...overrides,
      },
    );
  }

  /// Whether [column] is the soft-delete marker of a soft-deleting model.
  ///
  /// Left unset unless explicitly overridden: a generated fixture that
  /// arrives already deleted is invisible to every query, which makes for
  /// baffling test failures.
  bool _isSoftDeleteMarker(BeakModel model, BeakColumn column) =>
      model.softDeletes &&
      column.key == InMemoryBeakDataSource.softDeleteColumnKey;

  /// [count] records for [model], each with distinct generated values.
  List<BeakRecord> buildMany(
    BeakModel model,
    int count, {
    Map<String, BeakValue> overrides = const {},
  }) => [
    for (var index = 0; index < count; index++)
      build(model, overrides: overrides),
  ];

  /// A value satisfying [column]'s type and its declared rules.
  BeakValue _valueFor(BeakModel model, BeakColumn column) {
    if (column.key == model.primaryKey.key) {
      return BeakValue.of('${model.table}-$_sequence');
    }
    return switch (column) {
      BeakStringColumn() => BeakValue.of(
        _text(column, '${column.label} $_sequence'),
      ),
      BeakTextColumn() || BeakRichTextColumn() => BeakValue.of(
        _text(column, '${column.label} body $_sequence.'),
      ),
      BeakJsonColumn() => BeakValue.of('{"n":$_sequence}'),
      BeakColorColumn() => BeakValue.of(
        '#${_random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
      ),
      BeakUploadColumn(:final storagePath) => BeakValue.of(
        '$storagePath/file-$_sequence.bin',
      ),
      BeakIntColumn() => BeakValue.of(_integer(column)),
      BeakDecimalColumn() => BeakValue.of(_decimal(column)),
      BeakBoolColumn() => BeakValue.of(_sequence.isEven),
      BeakDateTimeColumn() => BeakValue.of(
        DateTime.utc(2026, 1, 1).add(Duration(hours: _sequence)),
      ),
      BeakEnumColumn(:final values, :final defaultValue) => BeakValue.of(
        (defaultValue ?? values[_sequence % values.length]).name,
      ),
      BeakCustomColumn() => BeakValue.of('custom-$_sequence'),
    };
  }

  /// Text bounded by the column's length rules, and matching a pattern rule
  /// where the shape is known.
  String _text(BeakColumn column, String candidate) {
    for (final rule in column.rules) {
      if (rule is BeakEmail) {
        return 'user$_sequence@example.com';
      }
      if (rule is BeakUrl) {
        return 'https://example.com/$_sequence';
      }
      if (rule is BeakInList) {
        return rule.allowed.isEmpty
            ? candidate
            : '${rule.allowed[_sequence % rule.allowed.length]}';
      }
    }
    var text = candidate;
    for (final rule in column.rules) {
      if (rule is BeakMinLength && text.length < rule.minLength) {
        text = text.padRight(rule.minLength, 'x');
      }
      if (rule is BeakMaxLength && text.length > rule.maxLength) {
        text = text.substring(0, rule.maxLength);
      }
    }
    if (column case BeakStringColumn(
      :final maxLength?,
    ) when text.length > maxLength) {
      text = text.substring(0, maxLength);
    }
    return text;
  }

  /// An integer inside the column's declared bounds.
  int _integer(BeakIntColumn column) {
    final int low = column.min ?? _boundOf(column, isMin: true)?.toInt() ?? 0;
    final int high =
        column.max ?? _boundOf(column, isMin: false)?.toInt() ?? low + 1000;
    return high <= low ? low : low + _random.nextInt(high - low + 1);
  }

  /// A decimal inside the column's declared bounds, at its precision.
  double _decimal(BeakDecimalColumn column) {
    final double low = _boundOf(column, isMin: true)?.toDouble() ?? 0;
    final double high =
        _boundOf(column, isMin: false)?.toDouble() ?? low + 1000;
    final double value = high <= low
        ? low
        : low + _random.nextDouble() * (high - low);
    return double.parse(value.toStringAsFixed(column.precision));
  }

  /// The numeric bound a [BeakMin]/[BeakMax] rule declares, if any.
  num? _boundOf(BeakColumn column, {required bool isMin}) {
    for (final rule in column.rules) {
      if (isMin && rule is BeakMin) {
        return rule.min;
      }
      if (!isMin && rule is BeakMax) {
        return rule.max;
      }
    }
    return null;
  }
}

/// A single record for [model], for a test that needs one and does not care
/// about reproducibility across calls.
///
/// Prefer a [BeakRecordFactory] when a test builds several and wants them to
/// differ predictably.
BeakRecord beakFakeRecord(
  BeakModel model, {
  Map<String, BeakValue> overrides = const {},
  int seed = 20260726,
}) => BeakRecordFactory(seed: seed).build(model, overrides: overrides);
