# Hiding a field from some roles

`BeakPolicies` decides per model. To take one field away from some principals
(a cost price, a legacy id), wrap it in a policy that implements the field hook
and delegates everything else. Compiled and tested at Beak 0.9.

`lib/shop_policy.dart`

```dart
import 'package:beak/server.dart';

import 'resources/suppliers/models/supplier.dart';

/// [BeakPolicies] plus one rule it cannot express: only admins see or write a
/// supplier's legacy id.
final class ShopPolicy
    implements
        BeakRowPolicy,
        BeakFieldPolicy,
        BeakReadOnlyFieldPolicy,
        BeakActionPolicy {
  /// Wraps [rules].
  const ShopPolicy(this.rules);

  /// The model-level rules every decision starts from.
  final BeakPolicies rules;

  bool _hidden(BeakPrincipal? principal, BeakFieldRef<Object> field) =>
      field.isSameFieldAs(SupplierModel.legacyId) &&
      !(principal?.hasRole('admin') ?? false);

  @override
  bool canView(BeakPrincipal? principal, BeakModel model) =>
      rules.canView(principal, model);

  @override
  bool canCreate(BeakPrincipal? principal, BeakModel model) =>
      rules.canCreate(principal, model);

  @override
  bool canUpdate(BeakPrincipal? principal, BeakModel model, Object id) =>
      rules.canUpdate(principal, model, id);

  @override
  bool canDelete(BeakPrincipal? principal, BeakModel model, Object id) =>
      rules.canDelete(principal, model, id);

  @override
  bool canDeleteUpload(
    BeakPrincipal? principal,
    BeakModel model,
    BeakUploadColumn column,
    String storageKey,
  ) => rules.canDeleteUpload(principal, model, column, storageKey);

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) =>
      rules.scopeFor(principal, model);

  @override
  bool canReadField(
    BeakPrincipal? principal,
    BeakModel model,
    BeakFieldRef<Object> field,
  ) => !_hidden(principal, field) && rules.canReadField(principal, model, field);

  @override
  bool canWriteField(
    BeakPrincipal? principal,
    BeakModel model,
    BeakFieldRef<Object> field,
  ) => !_hidden(principal, field) && rules.canWriteField(principal, model, field);

  @override
  bool isFieldReadOnly(
    BeakPrincipal? principal,
    BeakModel model,
    BeakFieldRef<Object> field,
  ) => rules.isFieldReadOnly(principal, model, field);

  @override
  bool canExecuteAction(
    BeakPrincipal? principal,
    BeakModel model,
    Object? id,
    BeakModelAction action,
  ) => rules.canExecuteAction(principal, model, id, action);
}
```

Use it as `policy: ShopPolicy(BeakPolicies(rules: [...]))` in `lib/server.dart`.
Compare fields with `isSameFieldAs`, never by key: generated models hand out a
new reference per access path, so `==` and `identical` are both false.

The test that proves it reads the same rows as two roles and asserts the key is
absent for one of them:

```dart
final seenByStaff = (await staff.query(table, query)).items;
expect(seenByStaff.single.values.keys, isNot(contains('legacy_id')));
expect(csv, isNot(contains('L-Acme'))); // staff.export(table, query)
```

Write attempts on a hidden field by a role without access are refused before
behavior or graph preparation runs, so a server calculation can still fill the
field. Row visibility does not belong here: use `rowScope` in `BeakModelRules`.
