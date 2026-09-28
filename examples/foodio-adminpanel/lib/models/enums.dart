/// Fulfillment is independent of payment and approval.
enum OrderStatus {
  /// Unsaved business intent; reserves no capacity or budget.
  draft,

  /// Placed and waiting for preparation.
  confirmed,

  /// Preparation started; customer and date are locked.
  inKitchen,

  /// Dispatched and no longer editable.
  outForDelivery,

  /// Fulfilled; budget reservation becomes spending.
  delivered,

  /// Closed without further preparation.
  cancelled,

  /// A failed delivery awaits an explicit redelivery slot.
  onHold,
}

/// Financial collection state; invoice billing can remain open after delivery.
enum PaymentStatus {
  /// No collection requested yet.
  unpaid,

  /// A durable payment request awaits its demo provider.
  pending,

  /// A provider receipt confirms collection.
  paid,

  /// The demo provider declined; a retry is available.
  failed,

  /// Billed through the company’s invoice agreement.
  invoiced,

  /// A persistent refund receipt confirms return of funds.
  refunded,
}

/// Company approval never permits exceeding the monthly budget.
enum ApprovalStatus {
  /// The order is below the profile’s approval threshold.
  notRequired,

  /// Reserved funds await the approver’s decision.
  pending,

  /// The approver accepted this order.
  approved,

  /// The approver rejected and cancelled this order.
  rejected,
}

/// Billing documents retain their issue snapshots.
enum InvoiceStatus {
  /// Totals follow associated eligible orders.
  draft,

  /// Recipient and money snapshots are frozen.
  issued,

  /// Collection has been acknowledged.
  paid,

  /// The issued document has been voided.
  cancelled,
}
