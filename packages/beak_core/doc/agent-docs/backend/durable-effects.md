# Durable effects

> Commit application effects with a graph save and deliver them through a retryable outbox.

A graph save may need to request a payment, send a confirmation, or notify another system. Use a transaction finalizer to enqueue that effect alongside the successful graph. Do not perform remote calls inside the database transaction or from a form callback.

`BeakSavePlanFinalizer` receives the finalized plan, its result, the transaction-bound `WormDataSource`, and the principal. It runs after graph validation and before the durable save receipt is written. An exception rolls back both the records and queued effects. A replay of an already completed save returns its receipt without running the finalizer again. Finalizers require transactional graph support.

Configure `finalizePlan` on the server/defaults/API router. Generated hosts include `BeakOutboxMigration`; existing deployments apply the new migration through the normal migration runner.

```dart
await BeakOutbox.enqueue(
  transaction.adapter,
  key: 'order-confirmation:$saveKey',
  kind: 'order.confirmation',
  payload: BeakRecord.fromRow({'order_id': orderId}),
);
```

Use stable effect keys derived from the save/command identity. Re-enqueueing the same key and payload is a no-op; reusing a key for different content is a conflict. Keep payloads small and persist the facts needed by the provider.

## Worker lifecycle

Construct a `BeakOutboxWorker` with the database adapter and a map of handlers, then call `drain()` from the host's worker loop. The worker claims pending entries with a compare-and-set lease. Expired leases can be reclaimed after a crash. Concurrent drains on one worker coalesce; separate workers use the database claim.

Handlers receive a `BeakOutboxEffect` with its stable key, kind, payload and attempt count. Success marks the effect delivered. Failure stores a safe error code, schedules a retry, and eventually marks the entry failed after `maxAttempts`. Defaults are a two-minute lease, ten-second base retry delay and eight attempts; configure these for the provider's expected latency.

Delivery is **at least once**. The provider must use the effect key as an idempotency key, because a process can fail after the provider succeeds but before the delivered marker commits. A lease alone cannot guarantee exactly-once external side effects. The worker does not hold a database transaction open during a remote call.

When a handler updates an existing timestamped record directly inside its own database transaction, use `beakRevisionTimestamp(now, previous: storedUpdatedAt)` for the new revision. It preserves JavaScript millisecond precision and always advances beyond the stored value, including under a frozen or corrected clock. Read, validate and write the record in the same transaction; a provider result must invalidate browser drafts loaded before that result.

Foodio uses persistent local payment/message adapters. Their receipts are stored in `payment_attempts` and `message_deliveries`, making retries observable without charging a real card or sending email. Its `bin/serve.dart` runs the worker and shuts it down with the server. A real integration replaces these handlers while retaining the same graph, receipt and outbox contracts.

## Continue reading

- [Transactional business rules](graph-business-rules.md)
- [Composed lists and remote refresh](../panel/composed-lists.md)
