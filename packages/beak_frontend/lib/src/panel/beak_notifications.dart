import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../data/beak_resource_repository.dart';
import '../data/beak_data_changes.dart';
import '../di/beak_locator.dart';

/// Binds a model's rows to the panel's notification center: which columns
/// carry the title, body, timestamp, read flag, and category. Set it on
/// [BeakPanelConfig.notifications] and a bell with an unread badge appears in
/// the shell — no per-app widget code.
final class BeakNotificationSource {
  /// Creates a notification source over [model].
  const BeakNotificationSource({
    required this.model,
    required this.titleField,
    this.bodyField,
    this.timeField,
    this.readField,
    this.categoryField,
  });

  /// The model whose rows are notifications.
  final BeakModel model;

  /// The column holding each notification's title.
  final BeakColumn titleField;

  /// The column holding the body, if any.
  final BeakColumn? bodyField;

  /// The timestamp column used to order newest-first, if any.
  final BeakColumn? timeField;

  /// The boolean "read" column, if any (enables the unread badge and
  /// mark-as-read).
  final BeakColumn? readField;

  /// The column grouping notifications into categories, if any.
  final BeakColumn? categoryField;
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
          BeakQuerySpec(
            table: source.model.table,
            sorts: [
              if (source.timeField case final BeakColumn time)
                BeakSort(time.key, descending: true),
            ],
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
    final BeakColumn? read = source.readField;
    if (read == null) {
      return records.length;
    }
    return records.where((r) => r[read.key]?.raw != true).length;
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
          BeakQuerySpec(
            table: source.model.table,
            sorts: [
              if (source.timeField case final BeakColumn time)
                BeakSort(time.key, descending: true),
            ],
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
      final BeakColumn? read = source.readField;
      if (read == null) {
        return;
      }
      for (final id in ids) {
        await dataSource.update(
          source.model.table,
          id,
          BeakRecord.fromRow({read.key: true}),
        );
      }
      records.value = [
        for (final record in records.value)
          _idOf(record) != null && ids.contains(_idOf(record))
              ? BeakRecord.fromRow({...record.toRow(), read.key: true})
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
          for (final record in records.value) _notificationOf(record),
        ],
        onMarkRead: (key) => markRead([key]),
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
    final BeakColumn? read = source.readField;
    return read == null || record[read.key]?.raw != true;
  }

  Object? _idOf(BeakRecord record) => source.model.primaryKeyOf(record);

  OiNotification _notificationOf(BeakRecord record) {
    final Object key =
        _idOf(record) ?? record[source.titleField.key]?.raw ?? '';
    return OiNotification(
      key: key,
      title: record[source.titleField.key]?.raw?.toString() ?? '',
      body: source.bodyField == null
          ? null
          : record[source.bodyField!.key]?.raw?.toString(),
      timestamp: _timeOf(record),
      read: !_isUnread(record),
      category: source.categoryField == null
          ? null
          : record[source.categoryField!.key]?.raw?.toString(),
    );
  }

  DateTime _timeOf(BeakRecord record) {
    final BeakColumn? time = source.timeField;
    if (time == null) {
      return DateTime.utc(2026);
    }
    return switch (record[time.key]?.raw) {
      final DateTime value => value,
      final String value => DateTime.tryParse(value) ?? DateTime.utc(2026),
      _ => DateTime.utc(2026),
    };
  }
}
