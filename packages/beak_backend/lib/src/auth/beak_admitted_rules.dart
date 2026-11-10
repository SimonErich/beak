import 'package:beak_core/beak_core.dart';

/// The parts of a [BeakModelRules] that a model's own permissions, admission
/// and capabilities decide.
///
/// Kept apart from the rule class so the derivation is one readable function
/// that tests can call on its own.
final class BeakAdmittedRules {
  const BeakAdmittedRules._({
    required this.read,
    required this.create,
    required this.update,
    required this.delete,
    required this.readOnlyFields,
    required this.hiddenFields,
    required this.actions,
    required this.removableUploadKeys,
  });

  /// Derives the rules [model] describes about itself.
  ///
  /// Throws a [BeakConfigurationException] when [model] has no admission.
  factory BeakAdmittedRules.of(BeakModel model) {
    final admission = model.admission;
    if (admission == null) {
      throw BeakConfigurationException(
        'Model "${model.table}" has no admission, so no rule can be derived '
        'for it. Generate the model with `beak generate`, or write its '
        'BeakModelRules by hand.',
      );
    }
    final permissions = model.permissions;
    final capabilities = model.capabilities;
    // A model with no write binding is read only, whatever its permissions
    // and capabilities claim: nothing could execute the write.
    final writes = admission.write != null;
    BeakAccess? access(BeakOperation operation) =>
        capabilities.contains(operation) &&
            (operation == BeakOperation.read || writes)
        ? permissions.accessFor(operation)
        : null;
    final writable = {for (final column in admission.writable) column.key};
    final updates = access(BeakOperation.update) != null;
    return BeakAdmittedRules._(
      read: access(BeakOperation.read),
      create: access(BeakOperation.create),
      update: access(BeakOperation.update),
      delete: access(BeakOperation.delete),
      readOnlyFields: {
        for (final column in model.columns)
          if (!writable.contains(column.key))
            BeakScalarField<Object>(model: model, column: column),
      },
      hiddenFields: {
        for (final column in admission.hidden)
          BeakScalarField<Object>(model: model, column: column):
              BeakAccess.anyone,
      },
      actions: {
        if (updates)
          for (final action in model.behavior.actions)
            action: ?permissions.accessForAction(action),
      },
      removableUploadKeys: writable,
    );
  }

  /// Who may read, or `null` when nobody may.
  final BeakAccess? read;

  /// Who may create, or `null` when nobody may.
  final BeakAccess? create;

  /// Who may update, or `null` when nobody may.
  final BeakAccess? update;

  /// Who may delete, or `null` when nobody may.
  final BeakAccess? delete;

  /// Every column outside the admission's writable set.
  final Set<BeakFieldRef<Object>> readOnlyFields;

  /// The admission's hidden columns, hidden from everyone.
  final Map<BeakFieldRef<Object>, BeakAccess> hiddenFields;

  /// The commands someone may run, with the access that admits them.
  final Map<BeakModelAction, BeakAccess> actions;

  /// The keys of the upload columns whose files may be removed.
  final Set<String> removableUploadKeys;
}
