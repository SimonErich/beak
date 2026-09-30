import 'package:beak_core/beak_core.dart';
import 'package:meta/meta.dart';

import 'beak_access.dart';
import 'beak_action_policy.dart';
import 'beak_auth_guard.dart';
import 'beak_field_policy.dart';
import 'beak_policy.dart';

/// The access rules of one model: who reads it, who writes it, who deletes
/// it, which rows a principal sees, and which fields the server owns.
///
/// Every part is optional and every part left out is denied, so a rule states
/// what is allowed and nothing else. Access is never implied: a rule that
/// lists only [write] lets those principals write and never read.
///
/// ```dart
/// BeakModelRules(
///   const OrderModel(),
///   read: staff,
///   write: manager,
///   rowScope: (principal) => OrderModel.status.notEq(OrderStatus.draft),
///   readOnlyFields: {OrderModel.totalInCents, OrderModel.number},
///   hiddenFields: {OrderModel.marginInCents: staff},
///   actions: {OrderModel.ship: staff},
/// )
/// ```
@immutable
final class BeakModelRules {
  /// Creates the rules of [model].
  ///
  /// Throws a [BeakConfigurationException] when a [readOnlyFields] or
  /// [hiddenFields] entry is not a direct field of [model], or when [actions]
  /// names a command the model does not declare: a rule that could never
  /// apply is a mistake worth failing on at startup.
  BeakModelRules(
    this.model, {
    this.read,
    this.write,
    this.delete,
    this.rowScope,
    Set<BeakFieldRef<Object>> readOnlyFields = const {},
    Map<BeakFieldRef<Object>, BeakAccess> hiddenFields = const {},
    Map<BeakModelAction, BeakAccess> actions = const {},
  }) : readOnlyFields = Set.unmodifiable(readOnlyFields),
       hiddenFields = Map.unmodifiable(hiddenFields),
       actions = Map.unmodifiable(actions),
       _readOnlyKeys = _readOnlyKeysOf(model, readOnlyFields),
       _hiddenAccessByKey = _hiddenAccessOf(model, hiddenFields),
       _actionAccessByName = _actionAccessOf(model, actions);

  /// The model these rules govern.
  final BeakModel model;

  /// Who may read records of [model], query, count, summarize and export them.
  ///
  /// `null` grants nobody.
  final BeakAccess? read;

  /// Who may create and update records of [model], attach and detach its
  /// relationships and upload its files.
  ///
  /// `null` grants nobody.
  final BeakAccess? write;

  /// Who may delete records of [model], and remove its uploaded files.
  ///
  /// `null` grants nobody.
  final BeakAccess? delete;

  /// The filter every read and write of [model] is constrained by, built for
  /// the signed-in principal, or `null` for every row.
  ///
  /// It is a typed predicate, never a column name:
  /// `(principal) => OrderModel.userId.eq(principal.id)`. An anonymous request
  /// has no principal to build it for, so it sees no rows at all.
  final BeakFilter? Function(BeakPrincipal principal)? rowScope;

  /// Fields the server owns: a request that supplies a value for one is
  /// rejected with a 422 field error, and forms are told not to offer it.
  ///
  /// Values the server derives itself (a calculated total, a number minted at
  /// creation) are unaffected.
  final Set<BeakFieldRef<Object>> readOnlyFields;

  /// Fields hidden from the principals each [BeakAccess] grants.
  ///
  /// A hidden field is neither readable nor writable for them: it is left out
  /// of responses, refused in filters, sorts and searches, and refused when
  /// they supply a value. Everyone else keeps whatever [read] and [write]
  /// give. Hiding narrows access and never grants it, and the access value
  /// names who is hidden *from*, so `BeakAccess.not(manager)` hides a field
  /// from everyone but managers:
  ///
  /// ```dart
  /// hiddenFields: {ProductModel.supplierCostInCents: BeakAccess.not(manager)}
  /// ```
  final Map<BeakFieldRef<Object>, BeakAccess> hiddenFields;

  /// Who may run each command of [model].
  ///
  /// A command left out cannot be run by anyone.
  final Map<BeakModelAction, BeakAccess> actions;

  final Set<String> _readOnlyKeys;
  final Map<String, BeakAccess> _hiddenAccessByKey;
  final Map<String, BeakAccess> _actionAccessByName;

  static Set<String> _readOnlyKeysOf(
    BeakModel model,
    Set<BeakFieldRef<Object>> fields,
  ) {
    for (final field in fields) {
      if (field.model.table != model.table || field.path.isNotEmpty) {
        throw BeakConfigurationException(
          'Read-only field "${field.qualifiedKey}" of "${field.model.table}" '
          'is not a direct field of "${model.table}".',
        );
      }
    }
    return {for (final field in fields) field.key};
  }

  static Map<String, BeakAccess> _hiddenAccessOf(
    BeakModel model,
    Map<BeakFieldRef<Object>, BeakAccess> fields,
  ) {
    for (final field in fields.keys) {
      if (field.model.table != model.table || field.path.isNotEmpty) {
        throw BeakConfigurationException(
          'Hidden field "${field.qualifiedKey}" of "${field.model.table}" '
          'is not a direct field of "${model.table}".',
        );
      }
    }
    return {
      for (final MapEntry(:key, :value) in fields.entries) key.key: value,
    };
  }

  static Map<String, BeakAccess> _actionAccessOf(
    BeakModel model,
    Map<BeakModelAction, BeakAccess> actions,
  ) {
    for (final action in actions.keys) {
      if (!model.behavior.actions.any(
        (declared) => declared.name == action.name,
      )) {
        throw BeakConfigurationException(
          'Model "${model.table}" declares no action "${action.name}".',
        );
      }
    }
    return {
      for (final MapEntry(:key, :value) in actions.entries) key.name: value,
    };
  }
}

/// The typed policy of a server: one [BeakModelRules] per model, and
/// everything not listed denied.
///
/// This is what a production server passes as its `policy`. It compiles the
/// rules to the four hooks the handlers consult ([BeakPolicy],
/// [BeakRowPolicy], [BeakFieldPolicy] and [BeakActionPolicy]) plus the
/// read-only fields the server enforces, so no rule is written against a table
/// name, a column name or an action name:
///
/// ```dart
/// final staff = BeakAccess.role('staff');
/// final manager = BeakAccess.role('manager');
///
/// final bookshopPolicy = BeakPolicies(
///   rules: [
///     BeakModelRules(const BookModel(), read: staff, write: staff, delete: manager),
///     BeakModelRules(
///       const OrderModel(),
///       read: staff,
///       write: manager,
///       rowScope: (principal) => OrderModel.status.notEq(OrderStatus.draft),
///       readOnlyFields: {OrderModel.totalInCents, OrderModel.number},
///     ),
///   ],
/// );
/// ```
///
/// A model with no rule is invisible: its endpoints answer 401 to an anonymous
/// request and 403 to anyone else, and no other model's relationship exposes
/// it. That is deliberate, so a model added later stays closed until someone
/// opens it. [BeakAllowAllPolicy] is the opposite default, for tests and quick
/// starts.
final class BeakPolicies
    implements
        BeakRowPolicy,
        BeakFieldPolicy,
        BeakReadOnlyFieldPolicy,
        BeakActionPolicy {
  /// Creates the policy from [rules].
  ///
  /// Throws a [BeakConfigurationException] when two rules govern the same
  /// model.
  BeakPolicies({required List<BeakModelRules> rules})
    : rules = List.unmodifiable(rules),
      _rulesByTable = _index(rules);

  /// The rules, one per governed model.
  final List<BeakModelRules> rules;

  final Map<String, BeakModelRules> _rulesByTable;

  static Map<String, BeakModelRules> _index(List<BeakModelRules> rules) {
    final byTable = <String, BeakModelRules>{};
    for (final rule in rules) {
      if (byTable.containsKey(rule.model.table)) {
        throw BeakConfigurationException(
          'Model "${rule.model.table}" has more than one set of rules.',
        );
      }
      byTable[rule.model.table] = rule;
    }
    return byTable;
  }

  @override
  bool canView(BeakPrincipal? principal, BeakModel model) =>
      _rulesByTable[model.table]?.read?.allows(principal) ?? false;

  @override
  bool canCreate(BeakPrincipal? principal, BeakModel model) =>
      _canWrite(principal, model);

  @override
  bool canUpdate(BeakPrincipal? principal, BeakModel model, Object id) =>
      _canWrite(principal, model);

  @override
  bool canDelete(BeakPrincipal? principal, BeakModel model, Object id) =>
      _canDelete(principal, model);

  @override
  bool canDeleteUpload(
    BeakPrincipal? principal,
    BeakModel model,
    BeakUploadColumn column,
    String storageKey,
  ) => _canDelete(principal, model);

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) {
    final scope = _rulesByTable[model.table]?.rowScope;
    if (scope == null) {
      return null;
    }
    return principal == null ? _matchesNothing(model) : scope(principal);
  }

  @override
  bool canReadField(
    BeakPrincipal? principal,
    BeakModel model,
    BeakFieldRef<Object> field,
  ) => canView(principal, model) && !_isHidden(principal, model, field);

  @override
  bool canWriteField(
    BeakPrincipal? principal,
    BeakModel model,
    BeakFieldRef<Object> field,
  ) => _canWrite(principal, model) && !_isHidden(principal, model, field);

  @override
  bool isFieldReadOnly(
    BeakPrincipal? principal,
    BeakModel model,
    BeakFieldRef<Object> field,
  ) =>
      field.model.table == model.table &&
      (_rulesByTable[model.table]?._readOnlyKeys.contains(field.qualifiedKey) ??
          false);

  @override
  bool canExecuteAction(
    BeakPrincipal? principal,
    BeakModel model,
    Object? id,
    BeakModelAction action,
  ) =>
      _rulesByTable[model.table]?._actionAccessByName[action.name]?.allows(
        principal,
      ) ??
      false;

  bool _isHidden(
    BeakPrincipal? principal,
    BeakModel model,
    BeakFieldRef<Object> field,
  ) =>
      field.model.table == model.table &&
      (_rulesByTable[model.table]?._hiddenAccessByKey[field.qualifiedKey]
              ?.allows(principal) ??
          false);

  bool _canWrite(BeakPrincipal? principal, BeakModel model) =>
      _rulesByTable[model.table]?.write?.allows(principal) ?? false;

  bool _canDelete(BeakPrincipal? principal, BeakModel model) =>
      _rulesByTable[model.table]?.delete?.allows(principal) ?? false;

  // The primary key is never null and never both null and not null, so this
  // holds for every row of every model without naming any other column.
  BeakFilter _matchesNothing(BeakModel model) => BeakAndFilter([
    BeakFieldFilter(
      column: model.primaryKey,
      operator: BeakOperator.isNull,
      value: const BeakNullValue(),
    ),
    BeakFieldFilter(
      column: model.primaryKey,
      operator: BeakOperator.isNotNull,
      value: const BeakNullValue(),
    ),
  ]);
}
