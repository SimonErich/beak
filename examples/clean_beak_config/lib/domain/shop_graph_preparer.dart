import 'package:beak/server.dart';

import 'shop_totals.dart';
import '../resources/categories/models/category.dart';
import '../resources/categories/models/category_attribute.dart';
import '../resources/products/models/product.dart';
import '../resources/products/models/product_attribute.dart';
import '../resources/products/models/product_variant.dart';
import '../resources/products/models/variant_attribute.dart';
import '../resources/invoices/models/invoice.dart';
import '../resources/invoices/models/invoice_item.dart';
import '../resources/invoices/models/invoice_voucher.dart';
import '../resources/orders/models/order.dart';
import '../resources/orders/models/order_item.dart';
import '../resources/taxes/models/tax_rate.dart';
import '../resources/users/models/user.dart';
import '../resources/users/models/user_profile_connection.dart';
import '../resources/vouchers/models/voucher.dart';
import 'shop_attributes.dart';

/// Authoritative shop rules and invoice snapshots at the transactional boundary.
///
/// The form declares fields; this service owns business rules that require
/// multiple records. Original operation identities and references are preserved.
final class ShopGraphPreparer {
  /// Uses the same model registry as the generated server.
  const ShopGraphPreparer(this.registry);

  /// Metadata used to follow the submitted graph's owned relationships.
  final BeakModelRegistry registry;

  /// Validates the final graph and appends server-calculated invoice snapshots.
  Future<BeakSavePlan> prepare(
    BeakSavePlan plan,
    WormDataSource source,
    BeakPrincipal? principal,
  ) async {
    try {
      final graph = await BeakCandidateGraph.open(
        plan: plan,
        source: source,
        registry: registry,
        authorizeRead: source.authorizeRead,
      );
      _validateOwnership(plan, graph);
      for (final node in graph.nodes.toList()) {
        if (node.deleted || !node.changed) continue;
        switch (node.model) {
          case OrderModel():
            final profile = await graph.linked(node, OrderModel.profile);
            if (profile != null &&
                !_sameRef(
                  profile.reference(UserProfileConnectionModel.user),
                  node.reference(OrderModel.customer),
                )) {
              _invalid(
                OrderModel.profile,
                'Choose a delivery profile belonging to this customer.',
              );
            }
          case OrderItemModel():
            await _line(graph, node, _LineFields.order);
          case ProductVariantModel():
            ShopMoney.amount(
              node.read(ProductVariantModel.price) ?? ShopMoney.zero,
            );
          case ProductModel():
            ShopMoney.amount(node.read(ProductModel.price) ?? ShopMoney.zero);
          case TaxRateModel():
            ShopMoney.percentage(
              node.read(TaxRateModel.ratePercent) ?? ShopMoney.zero,
            );
          case VoucherModel():
            _voucher(node);
          case ProductAttributeModel():
            await _attribute(graph, node);
          case CategoryAttributeModel():
            if (node.read(CategoryAttributeModel.valueType) ==
                    AttributeValueType.choice &&
                shopAttributeChoices(
                  node.read(CategoryAttributeModel.choices),
                ).isEmpty) {
              _invalid(
                CategoryAttributeModel.choices,
                'A choice attribute needs at least one option.',
              );
            }
          default:
            break;
        }
      }
      final variantRefs = <BeakRecordRef>{};
      final productRefs = <BeakRecordRef>{};
      final invoiceRefs = <BeakRecordRef>{};
      for (final node in graph.nodes.toList()) {
        if (!node.changed) continue;
        switch (node.model) {
          case ProductVariantModel():
            variantRefs.add(node.ref);
          case VariantAttributeModel():
            final owner = node.reference(VariantAttributeModel.variant);
            if (owner != null) variantRefs.add(owner);
          case ProductModel():
            productRefs.add(node.ref);
          case ProductAttributeModel():
            final product = node.reference(ProductAttributeModel.product);
            if (product != null) productRefs.add(product);
            final previous = node.originalReference(
              ProductAttributeModel.product,
            );
            if (previous != null) productRefs.add(previous);
          case InvoiceModel():
            invoiceRefs.add(node.ref);
          case InvoiceItemModel():
            invoiceRefs.add(
              _owningInvoice(
                InvoiceItemModel.invoice,
                node.reference(InvoiceItemModel.invoice),
              ),
            );
          case InvoiceVoucherModel():
            invoiceRefs.add(
              _owningInvoice(
                InvoiceVoucherModel.invoice,
                node.reference(InvoiceVoucherModel.invoice),
              ),
            );
          default:
            break;
        }
      }
      // --8<-- [start:shopVariantCombinationCheck]
      for (final ref in variantRefs) {
        final variant = await graph.load(ref);
        if (variant.deleted) continue;
        final key = await _combination(graph, variant);
        if (key != null) {
          final product = await graph.linked(
            variant,
            ProductVariantModel.product,
          );
          if (product != null) {
            for (final sibling in await graph.children(
              product,
              ProductModel.variants,
            )) {
              if (sibling.ref != variant.ref &&
                  await _combination(graph, sibling) == key) {
                _invalid(
                  ProductVariantModel.attributes,
                  'This product already has a variant with these attributes.',
                );
              }
            }
          }
        }
        graph.write(variant, ProductVariantModel.combinationKey, key);
      }
      // --8<-- [end:shopVariantCombinationCheck]
      for (final ref in productRefs) {
        await _product(graph, await graph.load(ref));
      }
      for (final ref in invoiceRefs) {
        await _invoice(graph, await graph.load(ref));
      }
      return graph.build();
    } on FormatException catch (error) {
      throw BeakValidationException(error.message);
    }
  }

  BeakRecordRef _owningInvoice(BeakToOneField field, BeakRecordRef? owner) =>
      owner ??
      (throw field.invalid('An invoice row needs its owning invoice.'));

  // --8<-- [start:shopCombinationKey]
  Future<String?> _combination(
    BeakCandidateGraph graph,
    BeakCandidateNode variant,
  ) async {
    final values = <String, String>{};
    for (final attribute in await graph.children(
      variant,
      ProductVariantModel.attributes,
    )) {
      final name = (attribute.read(VariantAttributeModel.name) ?? '').trim();
      if (values.containsKey(name)) {
        _invalid(
          ProductVariantModel.attributes,
          'Each variant attribute must have a different name.',
        );
      }
      values[name] = (attribute.read(VariantAttributeModel.value) ?? '').trim();
    }
    return values.isEmpty ? null : BeakVariantCombination(values).key;
  }
  // --8<-- [end:shopCombinationKey]

  Future<void> _product(
    BeakCandidateGraph graph,
    BeakCandidateNode product,
  ) async {
    if (product.deleted) return;
    final attributes = await graph.children(
      product,
      ProductModel.attributes,
      includeDeleted: true,
    );
    final present = <BeakRecordRef>{};
    for (final attribute in attributes.where((node) => !node.deleted)) {
      await _attribute(graph, attribute);
      final definition = attribute.reference(ProductAttributeModel.definition);
      if (definition != null && !present.add(definition)) {
        _invalid(
          ProductModel.attributes,
          'A category attribute can only be provided once.',
        );
      }
    }
    final category = await graph.linked(product, ProductModel.category);
    if (category == null) return;
    final definitions = await graph.children(
      category,
      CategoryModel.attributes,
    );
    // --8<-- [start:shopAttributeReconcile]
    final result =
        BeakAttributeSet([
          for (final definition in definitions)
            shopAttributeDefinition(
              definition.record,
              identity: _key(definition.ref),
            ),
        ]).reconcile([
          for (final attribute in attributes.where((node) => !node.deleted))
            if (attribute.reference(ProductAttributeModel.definition)
                case final reference?)
              BeakAttributeEntry(
                definitionId: _key(reference),
                value: attribute.read(ProductAttributeModel.value),
                version: 1,
              ),
        ]);
    if (!result.valid) {
      final message = result.missing.isNotEmpty
          ? 'Provide the required attribute: ${result.missing.first.label}.'
          : result.obsolete.isNotEmpty
          ? 'Review attributes that no longer belong to this category.'
          : result.errors.values.first.first;
      _invalid(ProductModel.attributes, message);
    }
    // --8<-- [end:shopAttributeReconcile]
  }

  Future<void> _attribute(
    BeakCandidateGraph graph,
    BeakCandidateNode node,
  ) async {
    final definition = await graph.linked(
      node,
      ProductAttributeModel.definition,
    );
    if (definition == null) return;
    final product = await graph.linked(node, ProductAttributeModel.product);
    if (product == null ||
        !_sameRef(
          product.reference(ProductModel.category),
          definition.reference(CategoryAttributeModel.category),
        )) {
      _invalid(
        ProductAttributeModel.definition,
        'Choose an attribute from this product category.',
      );
    }
    final error = shopAttributeDefinition(
      definition.record,
      identity: _key(definition.ref),
    ).validate(node.read(ProductAttributeModel.value));
    if (error != null) _invalid(ProductAttributeModel.value, error);
  }

  ShopVoucherInput _voucher(BeakCandidateNode node) {
    final value = node.read(VoucherModel.value) ?? ShopMoney.zero;
    final minimum = ShopMoney.amount(
      node.read(VoucherModel.minimumSubtotal) ?? ShopMoney.zero,
    );
    final maximum = switch (node.read(VoucherModel.maximumDiscount)) {
      final BeakDecimal cap => ShopMoney.amount(cap),
      null => null,
    };
    final start = node.read(VoucherModel.startsAt);
    final end = node.read(VoucherModel.endsAt);
    if (start != null && end != null && !end.isAfter(start)) {
      _invalid(VoucherModel.endsAt, 'The end must be after the start.');
    }
    final code = node.read(VoucherModel.code) ?? '';
    return switch (node.read(VoucherModel.kind)) {
      VoucherKind.percentage => ShopVoucherInput.percentage(
        id: _key(node.ref),
        code: code,
        percent: ShopMoney.percentage(value),
        minimumSubtotal: minimum,
        maximumDiscount: maximum,
      ),
      VoucherKind.fixed || null => ShopVoucherInput.fixed(
        id: _key(node.ref),
        code: code,
        amount: ShopMoney.amount(value),
        minimumSubtotal: minimum,
        maximumDiscount: maximum,
      ),
    };
  }

  Future<ShopLineInput> _line(
    BeakCandidateGraph graph,
    BeakCandidateNode node,
    _LineFields fields,
  ) async {
    final product = await graph.linked(node, fields.product);
    final variant = await graph.linked(node, fields.variant);
    if (variant != null &&
        (product == null ||
            !_sameRef(
              variant.reference(ProductVariantModel.product),
              product.ref,
            ))) {
      _invalid(
        fields.variant,
        'The selected variant belongs to another product.',
      );
    }
    final newSelection =
        node.initial == null ||
        node.hasChanged(fields.product) ||
        node.hasChanged(fields.variant);
    if (newSelection &&
        (product?.read(ProductModel.active) == false ||
            variant?.read(ProductVariantModel.active) == false)) {
      _invalid(fields.product, 'Choose an active catalog item.');
    }
    var label = (node.read(fields.label) ?? '').trim();
    if (label.isEmpty && product != null) {
      label = product.read(ProductModel.name) ?? '';
      if (variant != null) {
        label = '$label — ${variant.read(ProductVariantModel.name) ?? ''}';
      }
    }
    if (label.isEmpty) {
      _invalid(fields.label, 'A custom line needs a description.');
    }
    final explicitPrice = node.read(fields.price);
    if (explicitPrice == null && variant == null && product == null) {
      _invalid(fields.price, 'A custom line needs a unit price.');
    }
    final unitPrice = ShopMoney.amount(
      explicitPrice ??
          (variant != null
              ? variant.read(ProductVariantModel.price)
              : product?.read(ProductModel.price)) ??
          ShopMoney.zero,
    );
    var tax = await graph.linked(node, fields.taxRate);
    tax ??= product == null
        ? null
        : await graph.linked(product, ProductModel.taxRate);
    final savedPercent = fields.savedTaxPercent;
    final retainTax =
        savedPercent != null &&
        node.original(savedPercent) != null &&
        !node.hasChanged(fields.taxRate) &&
        !newSelection;
    final percent = retainTax
        ? node.original(savedPercent) ?? ShopMoney.zero
        : tax?.read(TaxRateModel.ratePercent) ?? ShopMoney.zero;
    if (!retainTax && tax?.read(TaxRateModel.active) == false) {
      _invalid(fields.taxRate, 'Choose an active tax rate.');
    }
    final taxRate = ShopMoney.percentage(percent);
    final input = ShopLineInput(
      id: _key(node.ref),
      label: label,
      quantity: node.read(fields.quantity) ?? 0,
      unitPrice: unitPrice,
      lineDiscount: ShopMoney.amount(
        node.read(fields.discount) ?? ShopMoney.zero,
      ),
      taxRate: taxRate,
    );
    // The calculator also validates line discounts and whole-unit quantities.
    ShopTotals.calculate(lines: [input]);
    if (savedPercent != null) {
      graph.writeAll(node, [
        fields.label.to(label),
        fields.price.to(unitPrice),
        savedPercent.to(taxRate),
      ]);
    }
    return input;
  }

  Future<void> _invoice(
    BeakCandidateGraph graph,
    BeakCandidateNode invoice,
  ) async {
    if (invoice.deleted) {
      _invalid(
        InvoiceModel.status,
        'Cancel an invoice instead of deleting it.',
      );
    }
    final items = await graph.children(
      invoice,
      InvoiceModel.items,
      includeDeleted: true,
    );
    final applications = await graph.children(
      invoice,
      InvoiceModel.vouchers,
      includeDeleted: true,
    );
    final previousStatus = invoice.original(InvoiceModel.status);
    if (previousStatus != null && previousStatus != InvoiceStatus.draft) {
      if (items.any((node) => node.materiallyChanged(except: _itemDerived)) ||
          applications.any(
            (node) => node.materiallyChanged(except: _voucherDerived),
          ) ||
          invoice.materiallyChanged(
            except: [..._invoiceMutable, ..._invoiceDerived],
          )) {
        _invalid(
          InvoiceModel.status,
          'Issued invoice content is locked. Create a new document for corrections.',
        );
      }
      final status = invoice.read(InvoiceModel.status);
      if (status == InvoiceStatus.draft ||
          (previousStatus == InvoiceStatus.cancelled &&
              status != InvoiceStatus.cancelled)) {
        _invalid(
          InvoiceModel.status,
          'An issued or cancelled invoice cannot return to draft.',
        );
      }
      graph.restore(invoice, _invoiceDerived);
      for (final item in items.where((item) => item.changed)) {
        graph.restore(item, _itemDerived);
      }
      for (final application in applications.where((row) => row.changed)) {
        graph.restore(application, _voucherDerived);
      }
      return;
    }
    final issued = invoice.read(InvoiceModel.issuedAt);
    final due = invoice.read(InvoiceModel.dueAt);
    if (issued == null) {
      _invalid(InvoiceModel.issuedAt, 'Choose the invoice date.');
    }
    if (due != null && due.isBefore(issued)) {
      _invalid(
        InvoiceModel.dueAt,
        'The due date cannot precede the invoice date.',
      );
    }
    final customer = await graph.linked(invoice, InvoiceModel.customer);
    if (customer == null) {
      _invalid(InvoiceModel.customer, 'Choose a customer.');
    }
    final order = await graph.linked(invoice, InvoiceModel.order);
    if (order != null &&
        !_sameRef(order.reference(OrderModel.customer), customer.ref)) {
      _invalid(InvoiceModel.order, 'The order belongs to another customer.');
    }
    final lineInputs = <ShopLineInput>[];
    final retainedItems = items.where((node) => !node.deleted).toList();
    for (final item in retainedItems) {
      lineInputs.add(await _line(graph, item, _LineFields.invoice));
    }
    final retainedApplications =
        applications.where((node) => !node.deleted).toList()..sort((a, b) {
          final order = _position(a).compareTo(_position(b));
          return order == 0 ? _key(a.ref).compareTo(_key(b.ref)) : order;
        });
    final vouchers = <ShopVoucherInput>[];
    final positions = <int>{};
    for (final application in retainedApplications) {
      if (!positions.add(_position(application))) {
        _invalid(
          InvoiceVoucherModel.position,
          'Give each voucher a different position.',
        );
      }
      final voucher = await graph.linked(
        application,
        InvoiceVoucherModel.voucher,
      );
      if (voucher == null) {
        _invalid(InvoiceVoucherModel.voucher, 'Choose a voucher.');
      }
      final start = voucher.read(VoucherModel.startsAt);
      final end = voucher.read(VoucherModel.endsAt);
      if (voucher.read(VoucherModel.active) != true ||
          (start != null && issued.isBefore(start)) ||
          (end != null && !issued.isBefore(end))) {
        _invalid(
          InvoiceVoucherModel.voucher,
          'This voucher is not active on the invoice date.',
        );
      }
      vouchers.add(_voucher(voucher));
    }
    final totals = ShopTotals.calculate(lines: lineInputs, vouchers: vouchers);
    for (var index = 0; index < retainedItems.length; index++) {
      final total = totals.lines[index];
      graph.writeAll(retainedItems[index], [
        InvoiceItemModel.net.to(total.net),
        InvoiceItemModel.tax.to(total.tax),
        InvoiceItemModel.total.to(total.total),
      ]);
    }
    for (var index = 0; index < retainedApplications.length; index++) {
      final total = totals.vouchers[index];
      graph.writeAll(retainedApplications[index], [
        InvoiceVoucherModel.codeSnapshot.to(total.input.code),
        InvoiceVoucherModel.discount.to(total.discount),
      ]);
    }
    graph.writeAll(invoice, [
      InvoiceModel.customerName.to(
        '${customer.read(UserModel.firstName) ?? ''} '
                '${customer.read(UserModel.lastName) ?? ''}'
            .trim(),
      ),
      InvoiceModel.customerEmail.to(customer.read(UserModel.email) ?? ''),
      InvoiceModel.subtotal.to(totals.subtotal),
      InvoiceModel.discount.to(totals.discount),
      InvoiceModel.tax.to(totals.tax),
      InvoiceModel.total.to(totals.total),
    ]);
  }

  void _validateOwnership(BeakSavePlan plan, BeakCandidateGraph graph) {
    for (final op in plan.operations) {
      final movesRows =
          op.kind == BeakSaveOperationKind.attach ||
          op.kind == BeakSaveOperationKind.detach;
      final ownedCollection =
          op.target.isOf(const InvoiceModel()) ||
          (op.target.isOf(const ProductModel()) &&
              op.isVia(ProductModel.attributes));
      if (movesRows && ownedCollection) {
        const message =
            'Owned rows must be created or deleted rather than moved.';
        throw BeakValidationException(
          message,
          fieldErrors: {
            ?op.relationKey: [message],
          },
        );
      }
    }
    for (final node in graph.nodes) {
      final relation = switch (node.model) {
        InvoiceItemModel() => InvoiceItemModel.invoice,
        InvoiceVoucherModel() => InvoiceVoucherModel.invoice,
        _ => null,
      };
      if (relation != null &&
          node.initial != null &&
          node.hasChanged(relation)) {
        _invalid(relation, 'An invoice row cannot move to another invoice.');
      }
    }
  }
}

/// The fields a line item shares, whether it belongs to an order or an invoice.
///
/// Invoice lines also snapshot the tax percentage they were priced with, so
/// [savedTaxPercent] is null for order lines and their values stay untouched.
final class _LineFields {
  const _LineFields._({
    required this.label,
    required this.quantity,
    required this.price,
    required this.discount,
    required this.product,
    required this.variant,
    required this.taxRate,
    this.savedTaxPercent,
  });

  static final order = _LineFields._(
    label: OrderItemModel.label,
    quantity: OrderItemModel.quantity,
    price: OrderItemModel.overwritePrice,
    discount: OrderItemModel.discount,
    product: OrderItemModel.product,
    variant: OrderItemModel.variant,
    taxRate: OrderItemModel.taxRate,
  );

  static final invoice = _LineFields._(
    label: InvoiceItemModel.label,
    quantity: InvoiceItemModel.quantity,
    price: InvoiceItemModel.unitPrice,
    discount: InvoiceItemModel.discount,
    product: InvoiceItemModel.product,
    variant: InvoiceItemModel.variant,
    taxRate: InvoiceItemModel.taxRate,
    savedTaxPercent: InvoiceItemModel.taxPercent,
  );

  final BeakScalarField<String> label;
  final BeakScalarField<int> quantity;
  final BeakScalarField<BeakDecimal> price;
  final BeakScalarField<BeakDecimal> discount;
  final BeakToOneField product;
  final BeakToOneField variant;
  final BeakToOneField taxRate;
  final BeakScalarField<BeakDecimal>? savedTaxPercent;
}

/// Invoice columns that only status transitions may change on an issued document.
final List<BeakFieldRef<Object>> _invoiceMutable = [
  InvoiceModel.status,
  InvoiceModel.updatedAt,
];

/// Invoice columns the server derives; issued documents keep their saved values.
final List<BeakScalarField<Object>> _invoiceDerived = [
  InvoiceModel.subtotal,
  InvoiceModel.discount,
  InvoiceModel.tax,
  InvoiceModel.total,
  InvoiceModel.customerName,
  InvoiceModel.customerEmail,
];

/// Line columns the server derives from the catalog at issue time.
final List<BeakScalarField<Object>> _itemDerived = [
  InvoiceItemModel.taxPercent,
  InvoiceItemModel.net,
  InvoiceItemModel.tax,
  InvoiceItemModel.total,
];

/// Voucher application columns the server derives from the calculation.
final List<BeakScalarField<Object>> _voucherDerived = [
  InvoiceVoucherModel.codeSnapshot,
  InvoiceVoucherModel.discount,
];

Never _invalid(BeakFieldRef<Object> field, String message) =>
    throw field.invalid(message);

String _key(BeakRecordRef ref) =>
    '${ref.table}:${ref.draftId == null ? 'saved:${ref.id}' : 'draft:${ref.draftId}'}';

bool _sameRef(BeakRecordRef? a, BeakRecordRef? b) => a != null && a == b;

int _position(BeakCandidateNode application) =>
    application.read(InvoiceVoucherModel.position) ?? 0;
