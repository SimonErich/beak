import 'dart:convert';

import 'package:meta/meta.dart';

import '../query/beak_record.dart';
import '../query/beak_value.dart';
import '../rules/beak_rule.dart';
import 'beak_column.dart';
import 'beak_json.dart';
import 'beak_semantic_values.dart';

/// Domain meaning independent of the physical storage column.
enum BeakSemanticKind {
  /// No specialization beyond the physical column.
  none,

  /// Email address.
  email,

  /// Absolute HTTP(S) URL.
  url,

  /// International or national telephone number.
  phone,

  /// Lowercase, hyphen-separated URL identifier.
  slug,

  /// Universally unique identifier in canonical hyphenated form.
  uuid,

  /// Secret input; presentation must obscure it.
  password,

  /// Gregorian calendar date, never a timestamp.
  calendarDate,

  /// Time of day, independent of a calendar date.
  time,

  /// Elapsed time, stored in integer microseconds.
  duration,

  /// Exact fixed-scale decimal, stored in integer units.
  exactDecimal,

  /// Exact monetary amount with an explicit currency policy.
  money,

  /// A ratio rendered as a percentage.
  percentage,

  /// A numeric quantity with an optional unit.
  quantity,

  /// Nonnegative integral byte count.
  fileSize,

  /// Homogeneous list of JSON primitives.
  primitiveList,

  /// Structured JSON object with declared child columns.
  object,
}

/// Supported element types for homogeneous primitive lists.
enum BeakPrimitiveType {
  /// Text values.
  string,

  /// Integral numeric values.
  integer,

  /// Finite floating-point values.
  decimal,

  /// Boolean values.
  boolean,
}

/// Reusable domain metadata and lossless codecs for a physical column.
@immutable
final class BeakSemantic {
  /// Uses the physical column's default behavior.
  const BeakSemantic({
    this.kind = BeakSemanticKind.none,
    this.scale = 2,
    this.currency,
    this.currencyColumn,
    this.percentageScale = 100,
    this.unit,
    this.listItemType,
    this.objectSchema,
    this.minItems,
    this.maxItems,
    this.distinctItems = false,
    this.itemRules = const [],
  }) : assert(scale >= 0 && scale <= 12),
       assert(percentageScale > 0),
       assert(minItems == null || minItems >= 0),
       assert(maxItems == null || maxItems >= 0),
       assert(minItems == null || maxItems == null || minItems <= maxItems),
       assert(currency == null || currencyColumn == null);

  /// Email address semantics.
  const BeakSemantic.email() : this(kind: BeakSemanticKind.email);

  /// Absolute HTTP(S) URL semantics.
  const BeakSemantic.url() : this(kind: BeakSemanticKind.url);

  /// Telephone number semantics.
  const BeakSemantic.phone() : this(kind: BeakSemanticKind.phone);

  /// Slug semantics.
  const BeakSemantic.slug() : this(kind: BeakSemanticKind.slug);

  /// UUID identifier semantics.
  const BeakSemantic.uuid() : this(kind: BeakSemanticKind.uuid);

  /// Obscured secret semantics; hashing belongs to an authentication service.
  const BeakSemantic.password() : this(kind: BeakSemanticKind.password);

  /// Timezone-free date semantics, backed by an ISO date string.
  const BeakSemantic.calendarDate() : this(kind: BeakSemanticKind.calendarDate);

  /// Time-of-day semantics, backed by an ISO time string.
  const BeakSemantic.time() : this(kind: BeakSemanticKind.time);

  /// Duration semantics, backed by integral microseconds.
  const BeakSemantic.duration() : this(kind: BeakSemanticKind.duration);

  /// Exact fixed-scale decimal semantics, backed by integral units.
  const BeakSemantic.exactDecimal({int scale = 2})
    : this(kind: BeakSemanticKind.exactDecimal, scale: scale);

  /// Monetary semantics with a fixed or record-dependent currency.
  const BeakSemantic.money({
    int scale = 2,
    String? currency,
    BeakColumn? currencyColumn,
  }) : this(
         kind: BeakSemanticKind.money,
         scale: scale,
         currency: currency,
         currencyColumn: currencyColumn,
       );

  /// Percentage semantics; [scale] is the stored value representing 100%.
  const BeakSemantic.percentage({num scale = 100})
    : this(kind: BeakSemanticKind.percentage, percentageScale: scale);

  /// A quantity carrying an optional display [unit].
  const BeakSemantic.quantity({String? unit})
    : this(kind: BeakSemanticKind.quantity, unit: unit);

  /// Integral byte-count semantics.
  const BeakSemantic.fileSize() : this(kind: BeakSemanticKind.fileSize);

  /// A homogeneous primitive list stored as JSON.
  const BeakSemantic.list(
    BeakPrimitiveType itemType, {
    int? minItems,
    int? maxItems,
    bool distinctItems = false,
    List<BeakRule> itemRules = const [],
  }) : this(
         kind: BeakSemanticKind.primitiveList,
         listItemType: itemType,
         minItems: minItems,
         maxItems: maxItems,
         distinctItems: distinctItems,
         itemRules: itemRules,
       );

  /// A structured JSON object described by [schema].
  const BeakSemantic.object(BeakObjectSchema schema)
    : this(kind: BeakSemanticKind.object, objectSchema: schema);

  /// Semantic specialization used by renderers and validators.
  final BeakSemanticKind kind;

  /// Decimal places for exact decimals and monetary amounts.
  final int scale;

  /// Constant ISO currency code, or null for a record-dependent currency.
  final String? currency;

  /// Typed column supplying the currency from the owning record.
  final BeakColumn? currencyColumn;

  /// Stored numeric value representing 100%.
  final num percentageScale;

  /// Human-readable quantity unit.
  final String? unit;

  /// Homogeneous list element type.
  final BeakPrimitiveType? listItemType;

  /// Child column declarations for structured objects.
  final BeakObjectSchema? objectSchema;

  /// Minimum number of primitive list items, if constrained.
  final int? minItems;

  /// Maximum number of primitive list items, if constrained.
  final int? maxItems;

  /// Whether primitive list items must be unique.
  final bool distinctItems;

  /// Validation rules enforced independently on each primitive list item.
  final List<BeakRule> itemRules;

  /// Whether this semantic changes the Dart value type of its storage column.
  bool get hasCodec => switch (kind) {
    BeakSemanticKind.calendarDate ||
    BeakSemanticKind.time ||
    BeakSemanticKind.duration ||
    BeakSemanticKind.exactDecimal ||
    BeakSemanticKind.money ||
    BeakSemanticKind.primitiveList ||
    BeakSemanticKind.object => true,
    _ => false,
  };

  /// Resolves the currency without requiring a field name from the caller.
  String? currencyFor(BeakRecord record) =>
      currency ??
      switch (currencyColumn) {
        final BeakColumn column => switch (record[column.key]) {
          BeakStringValue(:final value) => value,
          _ => null,
        },
        null => null,
      };

  /// Decodes a physical value into its semantic Dart type.
  ///
  /// Null remains null. Malformed data throws [FormatException], so validation
  /// cannot silently accept an invalid value as though the field were absent.
  Object? decode(BeakValue? value) {
    final raw = value?.raw;
    if (raw == null) return null;
    return switch (kind) {
      BeakSemanticKind.calendarDate => switch (raw) {
        final String value => BeakDate.parse(value),
        _ => _invalid(raw),
      },
      BeakSemanticKind.time => switch (raw) {
        final String value => BeakTime.parse(value),
        _ => _invalid(raw),
      },
      BeakSemanticKind.duration => Duration(microseconds: _integer(raw)),
      BeakSemanticKind.exactDecimal || BeakSemanticKind.money => _decimal(raw),
      BeakSemanticKind.primitiveList => _list(_json(raw)),
      BeakSemanticKind.object => switch (_json(raw)) {
        final Map<String, Object?> value => BeakJson.fromEncodable(value),
        _ => _invalid(raw),
      },
      _ => raw,
    };
  }

  /// Decodes a value without throwing; intended for tolerant record readers.
  Object? tryDecode(BeakValue? value) {
    try {
      return decode(value);
    } on FormatException {
      return null;
    }
  }

  /// Encodes a typed or already-physical value into the canonical wire shape.
  BeakValue encode(Object? value) {
    if (value == null) return const BeakNullValue();
    if (value is BeakValue) return encode(decode(value));
    return switch (kind) {
      BeakSemanticKind.calendarDate => BeakStringValue(switch (value) {
        final BeakDate date => BeakDate.parse(date.toString()).toString(),
        final String text => BeakDate.parse(text).toString(),
        _ => _invalid(value),
      }),
      BeakSemanticKind.time => BeakStringValue(switch (value) {
        final BeakTime time => BeakTime.parse(time.toString()).toString(),
        final String text => BeakTime.parse(text).toString(),
        _ => _invalid(value),
      }),
      BeakSemanticKind.duration => BeakIntValue(
        _integer(value is Duration ? value.inMicroseconds : value),
      ),
      BeakSemanticKind.exactDecimal || BeakSemanticKind.money => BeakIntValue(
        value is BeakDecimal
            ? value.rescale(scale).units
            : _decimal(value).units,
      ),
      BeakSemanticKind.primitiveList => BeakStringValue(
        jsonEncode(_list(value is String ? _json(value) : value)),
      ),
      BeakSemanticKind.object => switch (value) {
        final BeakJsonObject object => BeakStringValue(object.encode()),
        final Map<String, Object?> object => BeakStringValue(
          BeakJson.fromEncodable(object).encode(),
        ),
        final String source => encode(decode(BeakStringValue(source))),
        _ => _invalid(value),
      },
      _ => BeakValue.of(value is Enum ? value.name : value),
    };
  }

  BeakDecimal _decimal(Object raw) => BeakDecimal(_integer(raw), scale: scale);
  int _integer(Object raw) {
    final value = switch (raw) {
      final int value => value,
      final String text => int.tryParse(text),
      _ => null,
    };
    if (value == null || value.abs() > BeakDecimal.maxUnits) {
      return _invalid(raw);
    }
    return value;
  }

  Object? _json(Object raw) {
    if (raw is String) {
      final Object? decoded = jsonDecode(raw);
      return decoded;
    }
    return raw;
  }

  Object _list(Object? raw) {
    if (raw is! List<Object?>) return _invalid(raw);
    return switch (listItemType) {
      BeakPrimitiveType.string => List<String>.unmodifiable([
        for (final item in raw)
          if (item is String) item else _invalid(item),
      ]),
      BeakPrimitiveType.integer => List<int>.unmodifiable([
        for (final item in raw)
          if (item is int) item else _invalid(item),
      ]),
      BeakPrimitiveType.decimal => List<double>.unmodifiable([
        for (final item in raw)
          if (item is num && item.isFinite) item.toDouble() else _invalid(item),
      ]),
      BeakPrimitiveType.boolean => List<bool>.unmodifiable([
        for (final item in raw)
          if (item is bool) item else _invalid(item),
      ]),
      null => _invalid(raw),
    };
  }

  Never _invalid(Object? value) =>
      throw FormatException('Invalid ${kind.name} value.', value);
}

/// Declared shape of a JSON object, reusing column semantics and validation.
@immutable
final class BeakObjectSchema {
  /// Creates a structure from reusable, typed column definitions.
  const BeakObjectSchema({required this.columns, this.allowUnknown = false});

  /// Child properties; nested JSON columns can declare their own schemas.
  final List<BeakColumn> columns;

  /// Whether undeclared properties may be persisted.
  final bool allowUnknown;

  /// Reads a primitive child using its typed declaration.
  T? read<T extends Object>(BeakTypedColumn<T> column, BeakJsonObject object) {
    final value = object.entries[column.key];
    return value == null
        ? null
        : column.readValue(BeakValue.fromJson(value.toEncodable()));
  }

  /// Reads a semantic child value such as a date, exact decimal, or typed list.
  T? readValue<T extends Object>(BeakColumn column, BeakJsonObject object) {
    final record = toRecord(object);
    if (column.semantic.hasCodec) {
      return switch (column.semantic.tryDecode(record[column.key])) {
        final T value => value,
        _ => null,
      };
    }
    if (column case final BeakJsonColumn json when T != String) {
      return switch (json.readDocument(record[column.key])) {
        final T value => value,
        _ => null,
      };
    }
    return switch (column) {
      final BeakTypedColumn<T> typed => typed.readFrom(record),
      _ => null,
    };
  }

  /// Converts object properties to canonical field values for shared validation.
  BeakRecord toRecord(BeakJsonObject object) => BeakRecord(
    values: {
      for (final entry in object.entries.entries)
        entry.key: _valueFor(entry.key, entry.value),
    },
  );

  BeakValue _valueFor(String key, BeakJson value) {
    for (final column in columns) {
      if (column.key == key) {
        if (column.semantic.hasCodec) {
          return column.semantic.encode(value.toEncodable());
        }
        if (column is BeakJsonColumn) return BeakStringValue(value.encode());
        final encoded = BeakValue.fromJson(value.toEncodable());
        if (column case final BeakDateTimeColumn timestamp) {
          final instant = timestamp.readValue(encoded);
          return instant == null ? encoded : BeakDateTimeValue(instant);
        }
        return encoded;
      }
    }
    final raw = value.toEncodable();
    return value is BeakJsonObject || value is BeakJsonArray
        ? BeakStringValue(value.encode())
        : BeakValue.fromJson(raw);
  }

  /// Returns a new object with one declared property replaced.
  BeakJsonObject write(
    BeakColumn column,
    BeakJsonObject object,
    Object? value,
  ) {
    if (!columns.contains(column)) {
      throw ArgumentError.value(
        column,
        'column',
        'Not declared in this object schema.',
      );
    }
    final encoded =
        column is BeakJsonColumn &&
            !column.semantic.hasCodec &&
            value is BeakJson
        ? BeakStringValue(value.encode())
        : column.semantic.encode(value);
    final Object? jsonValue = switch (column.semantic.kind) {
      BeakSemanticKind.none when column is BeakJsonColumn => switch (encoded) {
        BeakStringValue(:final value) => BeakJson.decode(value).toEncodable(),
        _ => null,
      },
      BeakSemanticKind.object => switch (column.semantic.decode(encoded)) {
        final BeakJsonObject object => object.toEncodable(),
        _ => null,
      },
      BeakSemanticKind.primitiveList => column.semantic.decode(encoded),
      _ => encoded.toJson(),
    };
    return BeakJsonObject({
      ...object.entries,
      column.key: BeakJson.fromEncodable(jsonValue),
    });
  }
}
