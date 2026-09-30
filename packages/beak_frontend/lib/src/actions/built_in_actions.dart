part of 'beak_action.dart';

/// Navigates to the record's show page.
final class BeakViewAction extends BeakRecordAction {
  /// Creates the built-in view action.
  const BeakViewAction()
    : super(key: 'view', label: 'View', icon: OiIcons.eye, onExecute: _run);

  static Future<void> _run(BeakRecord record, BeakActionContext context) async {
    final Object? id = context.model.primaryKeyOf(record);
    if (id != null) {
      context.router.go(
        BeakBackButton.carry(
          context.router.routeInformationProvider.value.uri,
          BeakRoutes.show(context.model.table, id),
        ),
      );
    }
  }
}

/// Navigates to the record's edit page.
final class BeakEditAction extends BeakRecordAction {
  /// Creates the built-in edit action.
  const BeakEditAction()
    : super(key: 'edit', label: 'Edit', icon: OiIcons.pencil, onExecute: _run);

  static Future<void> _run(BeakRecord record, BeakActionContext context) async {
    final Object? id = context.model.primaryKeyOf(record);
    if (id != null) {
      context.router.go(
        BeakBackButton.carry(
          context.router.routeInformationProvider.value.uri,
          BeakRoutes.edit(context.model.table, id),
        ),
      );
    }
  }
}

/// Navigates to the resource's create page.
final class BeakCreateAction extends BeakGlobalAction {
  /// Creates the built-in create action.
  const BeakCreateAction()
    : super(
        key: 'create',
        label: 'Create',
        icon: OiIcons.plus,
        color: BeakColor.primary,
        onExecute: _run,
      );

  static Future<void> _run(BeakActionContext context) async {
    context.router.go(
      BeakBackButton.carry(
        context.router.routeInformationProvider.value.uri,
        BeakRoutes.create(context.model.table),
      ),
    );
  }
}

/// Deletes the record optimistically with an undo window, then returns to
/// the resource's list.
///
/// Renders destructively ([BeakColor.error]) and commits through
/// [BeakOptimistic.mutate]: the delete is offered with an undo toast and
/// only hits the data source once the undo window passes, after which the
/// list refreshes and the router navigates back. The generated list and show
/// pages offer it while the account may delete — you rarely construct it
/// yourself.
final class BeakDeleteAction extends BeakRecordAction {
  /// Creates the built-in delete action.
  const BeakDeleteAction()
    : super(
        key: 'delete',
        label: 'Delete',
        icon: OiIcons.trash2,
        color: BeakColor.error,
        onExecute: _run,
      );

  /// Confirms and waits for deletion before refreshing and leaving the record.
  ///
  /// Use this when the server owns irreversible cleanup or validation. It
  /// offers no optimistic undo and never attempts to restore the record.
  const BeakDeleteAction.confirmed()
    : super(
        key: 'delete',
        label: 'Delete',
        icon: OiIcons.trash2,
        color: BeakColor.error,
        requiresConfirmation: true,
        onExecute: _runConfirmed,
      );

  static Future<void> _runConfirmed(
    BeakRecord record,
    BeakActionContext context,
  ) async {
    final Object? id = context.model.primaryKeyOf(record);
    if (id == null) return;
    await context.dataSource.delete(context.model.table, id);
    if (!context.buildContext.mounted) return;
    if (context.dataSource is! BeakMutationSource) {
      await context.refresh?.call();
    }
    if (context.buildContext.mounted) _leaveDeleted(context);
  }

  /// Sends the person away from a record that no longer exists.
  ///
  /// From a record page that is the list the page was opened from, with the
  /// search, filters, sort and page it had (the `returnTo` the list added). A
  /// list stays where it is: going to its bare route would drop the view the
  /// person chose.
  static void _leaveDeleted(BeakActionContext context) {
    final list = BeakRoutes.list(context.model.table);
    final current = context.router.routeInformationProvider.value.uri;
    if (current.path == list) return;
    context.router.go(BeakBackButton.destination(current, list));
  }

  static Future<void> _run(BeakRecord record, BeakActionContext context) async {
    final Object? id = context.model.primaryKeyOf(record);
    if (id == null) {
      return;
    }
    VoidCallback? restore;
    await BeakOptimistic.mutate(
      context.buildContext,
      apply: () => restore = context.stageRemoval?.call(id),
      rollback: () => restore?.call(),
      commit: () async {
        try {
          await context.dataSource.delete(context.model.table, id);
        } on BeakException catch (error) {
          // The server refused, or could not confirm, the deletion: the row
          // comes back and the person is told why, instead of the generic
          // "Action failed" the undo window would show.
          restore?.call();
          if (context.buildContext.mounted) context.reportError(error);
          return;
        }
        if (!context.buildContext.mounted) return;
        if (context.dataSource is! BeakMutationSource) {
          await context.refresh?.call();
        }
        if (context.buildContext.mounted) _leaveDeleted(context);
      },
      message: BeakLocalizations.of(context.buildContext).recordDeleted,
    );
  }
}

/// Archives through the data source's configured deletion operation.
///
/// The backend owns archive semantics and cleanup. This action asks for
/// confirmation, waits for success, then refreshes and returns to the list.
/// A refusal stays on the record and uses the resource's action-error boundary.
/// No restore operation or optimistic undo is implied by an archive.
final class BeakArchiveAction extends BeakRecordAction {
  /// Creates a localized archive action using the resource's delete binding.
  const BeakArchiveAction()
    : super(
        key: 'archive',
        label: 'Archive',
        icon: OiIcons.archive,
        color: BeakColor.error,
        requiresConfirmation: true,
        onExecute: BeakDeleteAction._runConfirmed,
      );
}
