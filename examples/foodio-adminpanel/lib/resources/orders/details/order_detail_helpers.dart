import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import '../../../domain/foodio_clock.dart';
import '../../../models/models.dart';

/// Uses an explicit timestamp when available and falls back to the slot offset.
BeakValueBinding<Object> orderScheduledTime(
  BeakScalarField<DateTime> actual,
  int offset,
) => BeakValueBinding<Object>.computed(
  dependencies: [actual, OrderModel.slot.startMinute],
  compute: (row) {
    final stored = row.read(actual);
    if (stored != null) return stored;
    final start = row.read(OrderModel.slot.startMinute);
    if (start == null) return null;
    final minute = (start + offset).clamp(0, 1439);
    return BeakTime(minute ~/ 60, minute % 60);
  },
  display: (value, format) => value == null
      ? format.emptyValue
      : '${value is BeakTime ? 'Expected ' : ''}${format.format(value, BeakValueFormat.time)}',
);

/// Communicates kitchen cut-off and the immediate effect of order changes.
BeakFormNotice orderChangeNotice({required bool editing}) => BeakFormNotice(
  tone: BeakColor.muted,
  visibleIf: (state) => !{
    OrderStatus.delivered,
    OrderStatus.cancelled,
    OrderStatus.outForDelivery,
  }.contains(state.asOrder.status),
  inline: true,
  caption: editing
      ? (_) =>
            '${630 - (const FoodioClock().local.hour * 60 + const FoodioClock().local.minute)} minutes left'
      : null,
  icon: editing ? OiIcons.info : OiIcons.clock,
  title: editing
      ? 'The kitchen and the driver see changes immediately.'
      : 'Open for changes until 10:30',
  message: (_) => editing
      ? 'Items can change until 10:30.'
      : '${630 - (const FoodioClock().local.hour * 60 + const FoodioClock().local.minute)} minutes left. The kitchen and the driver see every change immediately.',
);
