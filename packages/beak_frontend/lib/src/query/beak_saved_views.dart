import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals_flutter.dart';

import '../data/beak_data_changes.dart';
import '../data/beak_resource_repository.dart';
import '../form/beak_configured_form.dart';
import '../form/beak_form_layout.dart';
import '../form/beak_form_session.dart';
import '../localization/beak_localizations.dart';
import 'beak_query_controller.dart';

/// One named saved view, resolved through normal resource authorization.
final class BeakSavedView {
  /// Captures its identity, name and versioned query choices.
  const BeakSavedView({
    required this.id,
    required this.name,
    required this.state,
  });

  /// Storage identity, distinct from preset keys.
  final Object id;

  /// Human-readable name.
  final String name;

  /// Query choices; application scopes remain outside persisted state.
  final BeakQueryState state;
}

/// Model-backed shared views using ordinary queries and graph form saves.
/// Owner/team visibility and write permission belong to this model's policies.
final class BeakSavedViewStore {
  /// Binds existing generated columns without application HTTP or serialization.
  // --8<-- [start:BeakSavedViewStore]
  const BeakSavedViewStore.model({
    required this.model,
    required this.name,
    required this.resource,
    required this.state,
    this.filter,
  });
  // --8<-- [end:BeakSavedViewStore]

  /// Resource storing named views.
  final BeakModel model;

  /// View name.
  final BeakScalarField<String> name;

  /// Resource/table namespace.
  final BeakScalarField<String> resource;

  /// Versioned serialized state, stored as text.
  final BeakScalarField<String> state;

  /// Optional application scope in addition to authoritative server policy.
  final BeakFilter? filter;

  /// Reads a namespace through the panel's normal transport.
  Future<List<BeakSavedView>> list(BeakDataSource source, String table) async {
    final page = await source.query(
      BeakQuerySpec(
        table: model.table,
        filter: BeakFilter.allOf([resource.eq(table), ?filter]),
        pagination: const BeakPagination(perPage: 1000),
      ),
    );
    return [
      for (final row in page.items)
        if (model.primaryKeyOf(row) case final Object id)
          BeakSavedView(
            id: id,
            name: name.readFrom(row) ?? '',
            state: decode(state.readFrom(row) ?? ''),
          ),
    ];
  }

  /// Rejects malformed or incompatible persisted state at the repository boundary.
  BeakQueryState decode(String value) {
    try {
      final json = jsonDecode(value);
      if (json is! Map<String, Object?>) throw const FormatException();
      return BeakQueryState.fromJson(json);
    } on FormatException {
      throw const BeakConfigurationException(
        'The saved view contains invalid state.',
      );
    }
  }

  /// Creates a normal form; hidden derived metadata is submitted automatically.
  BeakFormLayout form(
    BeakQueryController controller, {
    BeakQueryState? snapshot,
  }) {
    final table = controller.model.table;
    final encoded = jsonEncode((snapshot ?? controller.state.value).toJson());
    return BeakFormLayout(
      children: [
        name.inputText(validate: const [BeakRequired()]),
        resource.inputText(
          visibleIf: (_) => false,
          submitWhenHidden: true,
          derive: (_) => table,
        ),
        state.inputText(
          visibleIf: (_) => false,
          submitWhenHidden: true,
          derive: (_) => encoded,
        ),
      ],
    );
  }
}

/// Saved-view selector and graph-backed Save view action for the list toolbar.
class BeakSavedViews extends HookWidget {
  /// Uses the same source and query state as the containing list.
  const BeakSavedViews({
    required this.store,
    required this.controller,
    required this.source,
    this.saveState,
    this.onSelected,
    this.showSelector = true,
    this.saveLabel = 'Save view',
    this.enabled = true,
    super.key,
  });

  /// Typed persistence mapping.
  final BeakSavedViewStore store;

  /// Current list query state.
  final BeakQueryController controller;

  /// Panel-resolved source.
  final BeakDataSource source;

  /// Staged choices to save without first applying them to the list.
  final BeakQueryState? saveState;

  /// Whether existing views are offered alongside the save action.
  final bool showSelector;

  /// Label for the save action in a containing toolbar or editor.
  final String saveLabel;

  /// Prevents saving while a containing editor has invalid input.
  final bool enabled;

  /// Closes a containing editor after selecting an existing view.
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final views = useState(const <BeakSavedView>[]);
    final error = useState<BeakException?>(null);
    final refresh = useState(0);
    final revision = useBeakDataRevision(source, table: store.model.table);
    useEffect(() {
      var active = true;
      BeakResourceRepository(
        source,
      ).run(() => store.list(source, controller.model.table)).then((result) {
        if (!active) return;
        switch (result) {
          case BeakOk(:final value):
            views.value = value;
            error.value = null;
          case BeakErr(error: final failure):
            error.value = failure;
        }
      });
      return () => active = false;
    }, [store, source, controller, revision, refresh.value]);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showSelector && views.value.isNotEmpty)
          SizedBox(
            width: 220,
            child: OiSelect<Object>(
              label: 'Saved views',
              options: [
                for (final view in views.value)
                  OiSelectOption(value: view.id, label: view.name),
              ],
              onChanged: (id) async {
                final view = views.value
                    .where((view) => view.id == id)
                    .firstOrNull;
                if (view == null) return;
                final result = await BeakResourceRepository(
                  source,
                ).run(() async => controller.restore(view.state));
                if (result is BeakOk<void> && context.mounted) {
                  onSelected?.call();
                }
                if (context.mounted) {
                  if (result case BeakErr(error: final failure)) {
                    error.value = failure;
                  }
                }
              },
            ),
          ),
        OiButton.secondary(
          label: saveLabel,
          icon: OiIcons.bookmark,
          onTap: !enabled
              ? null
              : () async {
                  await showOiDialog<void>(
                    context,
                    dismissible: false,
                    builder: (context, close) => _SaveViewDialog(
                      store: store,
                      controller: controller,
                      source: source,
                      snapshot: saveState,
                      close: () => close(null),
                    ),
                  );
                  if (context.mounted) refresh.value++;
                },
        ),
        if (error.value case final BeakException failure)
          OiLabel.caption(BeakLocalizations.of(context).errorMessage(failure)),
      ],
    );
  }
}

class _SaveViewDialog extends HookWidget {
  const _SaveViewDialog({
    required this.store,
    required this.controller,
    required this.source,
    required this.close,
    this.snapshot,
  });
  final BeakSavedViewStore store;
  final BeakQueryController controller;
  final BeakDataSource source;
  final VoidCallback close;
  final BeakQueryState? snapshot;
  @override
  Widget build(BuildContext context) {
    final session = useState<BeakFormSession?>(null);
    final layout = useMemoized(
      () => store.form(controller, snapshot: snapshot),
      [store, controller],
    );
    return Watch(
      (context) => OiDialog.standard(
        label: 'Save view',
        title: 'Save view',
        dismissible: false,
        onClose:
            session.value?.hasUnknown == true ||
                session.value?.submitting.value == true
            ? null
            : close,
        content: SizedBox(
          width: 420,
          height: 260,
          child: BeakConfiguredForm(
            model: store.model,
            dataSource: source,
            layout: layout,
            onSession: (value) => session.value = value,
            onSaved: (_) => close(),
          ),
        ),
      ),
    );
  }
}
