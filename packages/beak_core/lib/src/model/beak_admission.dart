import 'package:meta/meta.dart';

import '../columns/beak_column.dart';

/// The constant facts a generator records about what a model admits.
///
/// A model's [BeakModel.columns] say what a table is. Its admission says what
/// may cross the boundary: which columns a client may write, which never leave
/// the server, and which key restores a soft-deleted row. The server enforces
/// these facts and the panel reads them, so both agree without either one
/// hard-coding a list of column names.
///
/// `beak generate` emits an admission as a constant on each generated model.
/// Write one by hand only for a model you maintain yourself:
///
/// ```dart
/// @override
/// BeakAdmission get admission => const BeakAdmission(
///   writable: [MenuColumns.name, MenuColumns.notes],
///   hidden: [MenuColumns.secretToken],
///   write: ShopWrite.menu,
/// );
/// ```
///
/// A model without an admission (`BeakModel.admission` is `null`) predates the
/// review and is not served through the admitted policy.
@immutable
final class BeakAdmission {
  /// Declares the admitted facts; everything omitted is closed.
  const BeakAdmission({
    this.writable = const [],
    this.hidden = const [],
    this.restoreKey = const [],
    this.translation,
    this.write,
    this.reason,
  });

  /// The reviewed write fields: the only columns a client may set.
  ///
  /// Every other column is server-owned and read-only for writes.
  final List<BeakColumn> writable;

  /// Columns that never leave the server through Beak, such as secrets.
  final List<BeakColumn> hidden;

  /// The key that identifies a soft-deleted row to bring back.
  ///
  /// Creating a row whose values for these columns match a soft-deleted row
  /// restores that row instead, keeping its id and creation time. Empty when
  /// the model never restores.
  final List<BeakColumn> restoreKey;

  /// How this table is a translation child, or `null` when it is not.
  final BeakTranslationSpec? translation;

  /// The generated write-binding value that selects this model's write
  /// handler, such as `ShopWrite.menu`, or `null` for a read-only model.
  final Enum? write;

  /// Why writes are closed, for a read-only model. Shown in docs and in
  /// `beak doctor`.
  final String? reason;
}

/// How a table holds the translations of another table's rows.
///
/// A translation child carries a foreign key to its owner and a locale; one row
/// exists per owner and locale.
///
/// ```dart
/// const spec = BeakTranslationSpec(
///   owner: MenuTranslationColumns.menuId,
///   locale: MenuTranslationColumns.locale,
/// );
/// ```
@immutable
final class BeakTranslationSpec {
  /// Names the foreign key to the owner and the locale column.
  const BeakTranslationSpec({required this.owner, required this.locale});

  /// The foreign key column pointing at the translated row.
  final BeakColumn owner;

  /// The column holding the translation's locale.
  final BeakColumn locale;
}
