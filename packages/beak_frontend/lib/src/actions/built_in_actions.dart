part of 'beak_action.dart';

/// Navigates to the record's show page.
final class BeakViewAction extends BeakRecordAction {
  /// Creates the built-in view action.
  const BeakViewAction()
    : super(key: 'view', label: 'View', icon: OiIcons.eye, onExecute: _run);

  static Future<void> _run(BeakRecord record, BeakActionContext context) async {
    final Object? id = context.model.primaryKeyOf(record);
    if (id != null) {
      context.router.go(BeakRoutes.show(context.model.table, id));
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
      context.router.go(BeakRoutes.edit(context.model.table, id));
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
    context.router.go(BeakRoutes.create(context.model.table));
  }
}

/// Deletes the record optimistically with an undo window, then returns to
/// the resource's list.
///
/// Renders destructively ([BeakColor.error]) and commits through
/// [BeakOptimistic.mutate]: the delete is offered with an undo toast and
/// only hits the data source once the undo window passes, after which the
/// list refreshes and the router navigates back. Included on every
/// resource's show page — you rarely construct it yourself.
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

  static Future<void> _run(BeakRecord record, BeakActionContext context) async {
    final Object? id = context.model.primaryKeyOf(record);
    if (id == null) {
      return;
    }
    await BeakOptimistic.mutate(
      context.buildContext,
      apply: () {},
      rollback: () {},
      commit: () async {
        await context.dataSource.delete(context.model.table, id);
        await context.refresh?.call();
        context.router.go(BeakRoutes.list(context.model.table));
      },
      message: 'Record deleted',
    );
  }
}
