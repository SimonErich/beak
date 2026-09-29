import 'package:beak_core/beak_core.dart';

final Expando<Set<String>> _recordKeys = Expando<Set<String>>(
  'Beak record keys',
);

/// The keys a record of [model] may carry: its declared columns and the
/// foreign keys of its belongs-to relations, in declaration order.
///
/// The soft-delete marker is not among them unless the model declares it:
/// it is framework-owned, and a record carrying an undeclared key would fail
/// the "unknown field" check of every validator that reads it back.
///
/// This is the allowlist behind every SELECT and RETURNING list Beak sends,
/// every row it hydrates and every record it redacts. A column the model
/// does not declare, such as a Serverpod `scope=serverOnly` field or one
/// the model simply leaves out, never leaves the database through Beak.
Set<String> beakRecordKeys(BeakModel model) =>
    _recordKeys[model] ??= Set.unmodifiable(<String>{
      for (final column in model.columns) column.key,
      for (final relation in model.relationships)
        if (relation case BeakBelongsTo(:final foreignKey)) foreignKey,
    });
