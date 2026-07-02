/// Beak's own ORM-neutral comparison operators for filters and query specs.
///
/// The frontend serializes an operator by its [name]; the backend translates
/// it to the worm operator set. Substring operators have no direct worm
/// counterpart and translate to `ilike` with a wildcard pattern built from
/// the filter value.
///
/// Translation table (kept exhaustive by `beak_operator_test.dart` — adding
/// a value without extending the table breaks the build):
///
/// | BeakOperator   | worm translation                     |
/// |----------------|--------------------------------------|
/// | [eq]           | `Operator.eq`                        |
/// | [neq]          | `Operator.neq`                       |
/// | [gt]           | `Operator.gt`                        |
/// | [gte]          | `Operator.gte`                       |
/// | [lt]           | `Operator.lt`                        |
/// | [lte]          | `Operator.lte`                       |
/// | [like]         | `Operator.like`                      |
/// | [ilike]        | `Operator.ilike`                     |
/// | [contains]     | `Operator.ilike` with pattern `%value%` |
/// | [startsWith]   | `Operator.ilike` with pattern `value%`  |
/// | [endsWith]     | `Operator.ilike` with pattern `%value`  |
/// | [isNull]       | `Operator.isNull`                    |
/// | [isNotNull]    | `Operator.isNotNull`                 |
/// | [inList]       | `Operator.inList`                    |
/// | [notInList]    | `Operator.notInList`                 |
/// | [between]      | `Operator.between`                   |
/// | [notBetween]   | `Operator.notBetween`                |
enum BeakOperator {
  /// Equal to (`=`).
  eq,

  /// Not equal to (`!=`).
  neq,

  /// Greater than (`>`).
  gt,

  /// Greater than or equal to (`>=`).
  gte,

  /// Less than (`<`).
  lt,

  /// Less than or equal to (`<=`).
  lte,

  /// Case-sensitive pattern match; the value is a raw `LIKE` pattern.
  like,

  /// Case-insensitive pattern match; the value is a raw `LIKE` pattern.
  ilike,

  /// Case-insensitive substring match (`%value%`).
  contains,

  /// Case-insensitive prefix match (`value%`).
  startsWith,

  /// Case-insensitive suffix match (`%value`).
  endsWith,

  /// The column has no value (`IS NULL`).
  isNull,

  /// The column has a value (`IS NOT NULL`).
  isNotNull,

  /// The value is one of a given list (`IN (...)`).
  inList,

  /// The value is none of a given list (`NOT IN (...)`).
  notInList,

  /// The value lies inside an inclusive range (`BETWEEN`).
  between,

  /// The value lies outside an inclusive range (`NOT BETWEEN`).
  notBetween,
}
