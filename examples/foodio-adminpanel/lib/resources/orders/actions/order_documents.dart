import 'package:beak/panel.dart';

import '../../../models/models.dart';

// --8<-- [start:deliveryNoteAction]
/// A print-ready snapshot of the persisted order, with no app fetch/print code.
BeakRecordAction deliveryNoteAction() => BeakRecordAction.document(
  key: 'delivery-note',
  label: 'Print delivery note',
  roles: const {BeakScreenRole.list, BeakScreenRole.read},
  document: BeakRecordDocument(
    title: BeakValueBinding.field(OrderModel.reference),
    subtitle: [
      BeakValueBinding.field(OrderModel.customer.name),
      BeakValueBinding.field(OrderModel.profile.name),
    ],
    fileName: 'delivery-note.html',
    sections: [
      BeakDocumentSection(
        title: 'Delivery',
        fields: [
          BeakValueBinding.field(OrderModel.deliveryDate, label: 'Date'),
          BeakValueBinding.field(OrderModel.slot.name, label: 'Time'),
          BeakValueBinding.field(OrderModel.location.name, label: 'Location'),
          BeakValueBinding.field(OrderModel.street, label: 'Street'),
          BeakValueBinding.field(OrderModel.postalCode, label: 'Postal code'),
          BeakValueBinding.field(OrderModel.city, label: 'City'),
          BeakValueBinding.field(OrderModel.handover, label: 'Handover'),
          BeakValueBinding.field(
            OrderModel.contactPhone,
            label: 'Contact phone',
          ),
          BeakValueBinding.field(
            OrderModel.deliveryNote,
            label: 'Instructions',
          ),
          BeakValueBinding.field(OrderModel.routeCode, label: 'Route'),
        ],
      ),
      BeakDocumentCollection(
        title: 'Dishes',
        field: OrderModel.items,
        columns: [
          OrderItemModel.label,
          OrderItemModel.variantName,
          OrderItemModel.quantity,
          OrderItemModel.allergens,
          OrderItemModel.note,
          OrderItemModel.grossCents.currency(minorUnits: true, label: 'Total'),
        ],
      ),
      BeakDocumentSection(
        title: 'Kitchen notes',
        fields: [
          BeakValueBinding.field(OrderModel.allergenNote, label: 'Allergens'),
          BeakValueBinding.field(
            OrderModel.customerNote,
            label: 'Customer note',
          ),
          BeakValueBinding.field(
            OrderModel.grossCents.currency(minorUnits: true),
            label: 'Order total, including VAT',
          ),
        ],
      ),
    ],
  ),
);
// --8<-- [end:deliveryNoteAction]
