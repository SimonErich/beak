---
title: Split a long form into steps
description: Turn a wall of inputs into a sequence that validates as it goes.
---

# Split a long form into steps

A create form with nine inputs is a wall. Give the resource `formSteps` and each
step validates before the next one opens:

```dart title="examples/store/lib/resources/orders.dart"
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  formSteps: const [
    BeakFormStep(
      title: 'Customer',
      subtitle: 'Who is buying',
      icon: OiIcons.user,
      description:
          'Pick the customer this order belongs to. Their past orders appear '
          'on their own page once this one is saved.',
      columns: [OrderColumns.customerId],
    ),
    // ...'Order', 'Money' and 'Delivery', covering every remaining column.
  ],
);
```

Every form column must appear in exactly one step.

## Continue reading

- [Multi-step forms](../panel/multi-step-forms.md)
