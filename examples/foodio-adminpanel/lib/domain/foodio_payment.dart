/// Canonical payment identifiers shared by forms, previews and the server.
const foodioPaymentLabels = {
  'monthlyInvoice': 'Company invoice',
  'weeklyInvoice': 'Weekly company invoice',
  'perOrderInvoice': 'Invoice per order',
  'sepa': 'SEPA direct debit',
  'subsidyCard': 'Subsidy + card',
  'card': 'Card',
  'paypal': 'PayPal',
  'paymentLink': 'Payment link',
};

/// Company invoice agreements do not request a card charge.
const foodioInvoicePaymentModes = {
  'monthlyInvoice',
  'weeklyInvoice',
  'perOrderInvoice',
  'sepa',
};

/// These modes reserve the order amount against its company profile budget.
const foodioCompanyPaymentModes = {...foodioInvoicePaymentModes, 'subsidyCard'};

/// These modes require an active saved payment method for the customer.
const foodioSavedPaymentModes = {'card', 'paypal', 'subsidyCard'};
