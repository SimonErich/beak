import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_superdashboard/models/models.dart';

/// The transaction show page: a headline strip of the reference, amount and
/// settlement state, then a two-column body splitting the payment mechanics
/// from the linked user, order and timing.
const BeakBlock transactionDetail = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'Transaction',
      child: BeakFieldGroupBlock([
        TransactionColumns.reference,
        TransactionColumns.amount,
        TransactionColumns.status,
        TransactionColumns.direction,
      ], columnCount: 4),
    ),
    BeakGridBlock(
      columns: 12,
      children: [
        BeakCardBlock(
          span: BeakSpan(columns: 7),
          title: 'Payment',
          child: BeakFieldGroupBlock([
            TransactionColumns.method,
            TransactionColumns.brand,
            TransactionColumns.amount,
            TransactionColumns.status,
          ], columnCount: 2),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 5),
          title: 'Context',
          child: BeakFieldGroupBlock([
            TransactionColumns.userId,
            TransactionColumns.orderId,
            TransactionColumns.occurredAt,
          ], columnCount: 2),
        ),
      ],
    ),
  ],
);
