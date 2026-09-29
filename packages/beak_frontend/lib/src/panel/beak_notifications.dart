import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../data/beak_resource_repository.dart';
import '../data/beak_data_changes.dart';
import '../di/beak_locator.dart';

/// Binds a model's rows to the panel's notification center: which fields
/// carry the title, body, timestamp, read flag, and category. Set it on
/// [BeakPanelConfig.notifications] and a bell with an unread badge appears in
/// the shell — no per-app widget code.
///
/// The model is taken from the fields, so it is never named separately:
///
/// ```dart
/// BeakNotificationSource(
///   titleField: NotificationModel.title,
///   bodyField: NotificationModel.body,
///   timeField: NotificationModel.occurredAt,
///   readField: NotificationModel.isRead,
/// );
/// ```
final class BeakNotificationSource {
  /// Creates a notification source over the model that owns [titleField].
  ///
  /// Throws a [BeakConfigurationException] when another field belongs to a
  /// different model, or is reached through a relationship.
  BeakNotificationSource({
    required this.titleField,
    this.bodyField,
    this.timeField,
    this.readField,
    this.categoryField,
  }) {
    for (final field in [
      titleField,
      ?bodyField,
      ?timeField,
      ?readField,
      ?categoryField,
    ]) {
      if (field.path.isNotEmpty || field.model.table != model.table) {
        throw BeakConfigurationException(
          'Notification field "${field.qualifiedKey}" must be a field of '
          '${model.table} itself.',
        );
      }
    }
  }

  /// The field holding each notification's title.
  final BeakScalarField<String> titleField;

  /// The field holding the body, if any.
  final BeakScalarField<String>? bodyField;

  /// The timestamp field used to order newest-first and to date each entry.
  ///
  /// Without one the list keeps the data source's order and every entry is
  /// dated with the moment it was read. A row whose value is empty is not
  /// listed.
  final BeakScalarField<DateTime>? timeField;

  /// The boolean "read" field, if any (enables the unread badge and
  /// mark-as-read).
  final BeakScalarField<bool>? readField;

  /// The field grouping notifications into categories, if any.
  final BeakScalarField<Object>? categoryField;

  /// The model whose rows are notifications, read from [titleField].
  BeakModel get model => titleField.model;
}

/// The shell's notification bell: a badge showing the unread count that opens
/// a side sheet listing the [source]'s rows on `OiNotificationCenter`, with
/// mark-as-read writing back through the data source.
class BeakNotificationBell extends HookWidget {
  /// Creates the bell for [source].
  const BeakNotificationBell({required this.source, super.key});

  /// The notification binding.
  final BeakNotificationSource source;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final records = useState(const <BeakRecord>[]);
    final reloadTick = useState(0);
    final revision = useBeakDataRevision(dataSource, table: source.model.table);

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final result = await BeakResourceRepository(dataSource).query(
          source.model.query(
            sorts: [?source.timeField?.descending()],
            pagination: const BeakPagination(perPage: 30),
          ),
        );
        if (cancelled) {
          return;
        }
        if (result case BeakOk(:final value)) {
          records.value = value.items;
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource, source, reloadTick.value, revision]);

    final int unread = _unreadOf(records.value);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        OiButton.icon(
          icon: OiIcons.bell,
          label: 'Notifications',
          onTap: () => _open(context, dataSource, () => reloadTick.value++),
        ),
        if (unread > 0)
          Positioned(
            right: 0,
            top: 2,
            child: IgnorePointer(child: OiBadge.counter(label: '$unread')),
          ),
      ],
    );
  }

  int _unreadOf(List<BeakRecord> records) {
    final BeakScalarField<bool>? read = source.readField;
    if (read == null) {
      return records.length;
    }
    return records.where((r) => read.readFrom(r) != true).length;
  }

  void _open(
    BuildContext context,
    BeakDataSource dataSource,
    VoidCallback onChanged,
  ) {
    OiSheet.showAsync<void>(
      context,
      label: 'Notifications',
      side: OiPanelSide.right,
      builder: (close) =>
          _BeakNotificationPanel(source: source, onChanged: onChanged),
    );
  }
}

/// The sheet body: fetches the notifications, renders them, and writes
/// mark-as-read back through the data source (optimistically updating its own
/// list and notifying the bell to refresh its badge).
class _BeakNotificationPanel extends HookWidget {
  const _BeakNotificationPanel({required this.source, required this.onChanged});

  final BeakNotificationSource source;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final records = useState(const <BeakRecord>[]);

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final result = await BeakResourceRepository(dataSource).query(
          source.model.query(
            sorts: [?source.timeField?.descending()],
            pagination: const BeakPagination(perPage: 30),
          ),
        );
        if (cancelled) {
          return;
        }
        if (result case BeakOk(:final value)) {
          records.value = value.items;
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource]);

    Future<void> markRead(Iterable<Object> ids) async {
      final BeakScalarField<bool>? read = source.readField;
      if (read == null) {
        return;
      }
      for (final id in ids) {
        await dataSource.update(
          source.model.table,
          id,
          read.writeTo(const BeakRecord(values: {}), true),
        );
      }
      records.value = [
        for (final record in records.value)
          _idOf(record) != null && ids.contains(_idOf(record))
              ? read.writeTo(record, true)
              : record,
      ];
      onChanged();
    }

    return SizedBox(
      width: 380,
      child: OiNotificationCenter(
        label: 'Notifications',
        unreadCount: _unread(records.value),
        notifications: [
          for (final record in records.value)
            if (_notificationOf(record) case final OiNotification entry) entry,
        ],
        onMarkRead: (notification) => markRead([notification.key]),
        onMarkAllRead: () => markRead(
          [
            for (final record in records.value)
              if (_isUnread(record)) _idOf(record),
          ].whereType<Object>(),
        ),
      ),
    );
  }

  int _unread(List<BeakRecord> records) => records.where(_isUnread).length;

  bool _isUnread(BeakRecord record) {
    final BeakScalarField<bool>? read = source.readField;
    return read == null || read.readFrom(record) != true;
  }

  Object? _idOf(BeakRecord record) => source.model.primaryKeyOf(record);

  /// The centre's entry for [record], or `null` for a row whose time field is
  /// bound but empty: the centre dates every entry, and an invented date
  /// would be worse than leaving the row out. A source with no time field at
  /// all dates its entries with the moment they were read.
  OiNotification? _notificationOf(BeakRecord record) {
    final String? title = source.titleField.readFrom(record);
    final Object key = _idOf(record) ?? title ?? '';
    final DateTime? timestamp = switch (source.timeField) {
      final BeakScalarField<DateTime> field => field.readFrom(record),
      null => DateTime.now(),
    };
    if (timestamp == null) {
      return null;
    }
    return OiNotification(
      key: key,
      title: title ?? '',
      body: source.bodyField?.readFrom(record),
      timestamp: timestamp,
      read: !_isUnread(record),
      category: source.categoryField?.readFrom(record)?.toString(),
    );
  }
}
