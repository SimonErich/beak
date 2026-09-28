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
import '../resources/users/models/user_profile_connection.dart';
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
      );
      _validateOwnership(plan, graph);
      for (final node in graph.nodes.toList()) {
        if (node.deleted || !node.changed) continue;
        switch (node.ref.table) {
          case 'orders':
            final profile = await graph.linked(node, OrderModel.profile);
            if (profile != null &&
                !_sameRef(
                  profile.reference(UserProfileConnectionModel.user),
                  node.reference(OrderModel.customer),
                )) {
              _invalid(
                'profile_id',
                'Choose a delivery profile belonging to this customer.',
              );
            }
          case 'order_items':
            await _line(
              graph,
              node,
              priceKey: 'overwrite_price',
              freeze: false,
            );
          case 'product_variants':
            ShopMoney.cents(_number(node, 'price'));
          case 'products':
            ShopMoney.cents(_number(node, 'price'));
          case 'tax_rates':
            ShopMoney.basisPoints(_number(node, 'rate_percent'));
          case 'vouchers':
            _voucher(node);
          case 'product_attributes':
            await _attribute(graph, node);
          case 'category_attributes':
            if (_text(node, 'value_type') == 'choice' &&
                _text(
                  node,
                  'choices',
                ).split(',').every((choice) => choice.trim().isEmpty)) {
              _invalid(
                'choices',
                'A choice attribute needs at least one option.',
              );
            }
          default:
            break;
        }
      }
      final variantRefs = <String, BeakRecordRef>{};
      final productRefs = <String, BeakRecordRef>{};
      final invoiceRefs = <String, BeakRecordRef>{};
      for (final node in graph.nodes.toList()) {
        if (node.ref.table == const ProductVariantModel().table &&
            node.changed) {
          variantRefs[_key(node.ref)] = node.ref;
        }
        if (node.ref.table == const VariantAttributeModel().table &&
            node.changed) {
          final owner = node.reference(VariantAttributeModel.variant);
          if (owner != null) variantRefs[_key(owner)] = owner;
        }
        if (node.ref.table == 'products' && node.changed) {
          productRefs[_key(node.ref)] = node.ref;
        }
        if (node.ref.table == 'product_attributes' && node.changed) {
          final product = node.reference(ProductAttributeModel.product);
          if (product != null) productRefs[_key(product)] = product;
          final previous = node.initial?['product_id']?.raw;
          if (previous != null) {
            final original = BeakRecordRef.existing('products', previous);
            productRefs[_key(original)] = original;
          }
        }
        if (node.ref.table == 'invoices' && node.changed) {
          invoiceRefs[_key(node.ref)] = node.ref;
        }
        if ((node.ref.table == 'invoice_items' ||
                node.ref.table == 'invoice_vouchers') &&
            node.changed) {
          final owner = node.reference(
            node.ref.table == const InvoiceItemModel().table
                ? InvoiceItemModel.invoice
                : InvoiceVoucherModel.invoice,
          );
          if (owner == null) {
            _invalid('invoice_id', 'An invoice row needs its owning invoice.');
          }
          invoiceRefs[_key(owner)] = owner;
        }
      }
      for (final ref in variantRefs.values) {
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
                  ProductVariantModel.attributes.key,
                  'This product already has a variant with these attributes.',
                );
              }
            }
          }
        }
        graph.write(variant, ProductVariantModel.combinationKey, key);
      }
      for (final ref in productRefs.values) {
        await _product(graph, await graph.load(ref));
      }
      for (final ref in invoiceRefs.values) {
        await _invoice(graph, await graph.load(ref));
      }
      return graph.build();
    } on FormatException catch (error) {
      throw BeakValidationException(error.message);
    }
  }

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
          ProductVariantModel.attributes.key,
          'Each variant attribute must have a different name.',
        );
      }
      values[name] = (attribute.read(VariantAttributeModel.value) ?? '').trim();
    }
    return values.isEmpty ? null : BeakVariantCombination(values).key;
  }

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
    final present = <String>{};
    for (final attribute in attributes.where((node) => !node.deleted)) {
      await _attribute(graph, attribute);
      final definition = attribute.reference(ProductAttributeModel.definition);
      if (definition != null) {
        if (!present.add(_key(definition))) {
          _invalid(
            'attributes',
            'A category attribute can only be provided once.',
          );
        }
      }
    }
    final category = await graph.linked(product, ProductModel.category);
    if (category == null) return;
    final definitions = await graph.children(
      category,
      CategoryModel.attributes,
    );
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
      _invalid(ProductModel.attributes.key, message);
    }
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
    final product = await graph.linked(
      node,
      node.ref.table == const ProductAttributeModel().table
          ? ProductAttributeModel.product
          : node.ref.table == const OrderItemModel().table
          ? OrderItemModel.product
          : InvoiceItemModel.product,
    );
    if (product == null ||
        !_sameRef(
          product.reference(ProductModel.category),
          definition.reference(CategoryAttributeModel.category),
        )) {
      _invalid(
        'definition_id',
        'Choose an attribute from this product category.',
      );
    }
    final error = shopAttributeDefinition(
      definition.record,
      identity: _key(definition.ref),
    ).validate(node.read(ProductAttributeModel.value));
    if (error != null) _invalid(ProductAttributeModel.value.key, error);
  }

  ShopVoucherInput _voucher(BeakCandidateNode node) {
    final value = _number(node, 'value');
    final minimum = ShopMoney.cents(_number(node, 'minimum_subtotal'));
    final maximum = node.values['maximum_discount']?.raw == null
        ? null
        : ShopMoney.cents(_number(node, 'maximum_discount'));
    final start = _date(node, 'starts_at');
    final end = _date(node, 'ends_at');
    if (start != null && end != null && !end.isAfter(start)) {
      _invalid('ends_at', 'The end must be after the start.');
    }
    return switch (_text(node, 'kind')) {
      'percentage' => ShopVoucherInput.percentage(
        id: _key(node.ref),
        code: _text(node, 'code'),
        basisPoints: ShopMoney.basisPoints(value),
        minimumSubtotalCents: minimum,
        maximumDiscountCents: maximum,
      ),
      'fixed' || '' => ShopVoucherInput.fixed(
        id: _key(node.ref),
        code: _text(node, 'code'),
        amountCents: ShopMoney.cents(value),
        minimumSubtotalCents: minimum,
        maximumDiscountCents: maximum,
      ),
      _ => throw const BeakValidationException(
        'Choose a supported voucher kind.',
      ),
    };
  }

  Future<ShopLineInput> _line(
    BeakCandidateGraph graph,
    BeakCandidateNode node, {
    required String priceKey,
    required bool freeze,
  }) async {
    final product = await graph.linked(
      node,
      node.ref.table == const ProductAttributeModel().table
          ? ProductAttributeModel.product
          : node.ref.table == const OrderItemModel().table
          ? OrderItemModel.product
          : InvoiceItemModel.product,
    );
    final variant = await graph.linked(
      node,
      node.ref.table == const OrderItemModel().table
          ? OrderItemModel.variant
          : InvoiceItemModel.variant,
    );
    if (variant != null &&
        (product == null ||
            !_sameRef(
              variant.reference(ProductVariantModel.product),
              product.ref,
            ))) {
      _invalid(
        'variant_id',
        'The selected variant belongs to another product.',
      );
    }
    final newSelection =
        node.initial == null ||
        node.hasChanged(
          node.ref.table == const OrderItemModel().table
              ? OrderItemModel.product
              : InvoiceItemModel.product,
        ) ||
        node.hasChanged(
          node.ref.table == const OrderItemModel().table
              ? OrderItemModel.variant
              : InvoiceItemModel.variant,
        );
    if (newSelection &&
        (product?.values['active']?.raw == false ||
            variant?.values['active']?.raw == false)) {
      _invalid('product_id', 'Choose an active catalog item.');
    }
    var label = _text(node, 'label').trim();
    if (label.isEmpty && product != null) {
      label = _text(product, 'name');
      if (variant != null) label = '$label — ${_text(variant, 'name')}';
    }
    if (label.isEmpty) _invalid('label', 'A custom line needs a description.');
    final rawPrice = node.values[priceKey]?.raw;
    final price = rawPrice == null ? (variant ?? product) : node;
    if (price == null) _invalid(priceKey, 'A custom line needs a unit price.');
    final cents = ShopMoney.cents(
      _number(price, rawPrice == null ? 'price' : priceKey),
    );
    var tax = await graph.linked(
      node,
      node.ref.table == const OrderItemModel().table
          ? OrderItemModel.taxRate
          : InvoiceItemModel.taxRate,
    );
    tax ??= product == null
        ? null
        : await graph.linked(product, ProductModel.taxRate);
    final retainTax =
        freeze &&
        node.initial?['tax_percent']?.raw != null &&
        !node.hasChanged(InvoiceItemModel.taxRate) &&
        !newSelection;
    final percent = retainTax
        ? switch (node.initial?['tax_percent']?.raw) {
            final num value => value.toDouble(),
            _ => 0.0,
          }
        : tax == null
        ? 0.0
        : _number(tax, 'rate_percent');
    if (!retainTax && tax?.values['active']?.raw == false) {
      _invalid('tax_rate_id', 'Choose an active tax rate.');
    }
    final basisPoints = ShopMoney.basisPoints(percent);
    final input = ShopLineInput(
      id: _key(node.ref),
      label: label,
      quantity: _integer(node, 'quantity'),
      unitPriceCents: cents,
      lineDiscountCents: ShopMoney.cents(_number(node, 'discount')),
      taxBasisPoints: basisPoints,
    );
    // The calculator also validates line discounts and whole-unit quantities.
    ShopTotals.calculate(lines: [input]);
    if (freeze) {
      _patch(graph, node, {
        'label': label,
        priceKey: cents / 100,
        'tax_percent': basisPoints / 100,
      });
    }
    return input;
  }

  Future<void> _invoice(
    BeakCandidateGraph graph,
    BeakCandidateNode invoice,
  ) async {
    if (invoice.deleted) {
      _invalid('status', 'Cancel an invoice instead of deleting it.');
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
    final previousStatus = invoice.initial?['status']?.raw;
    if (previousStatus != null && previousStatus != 'draft') {
      final mutable = {'status', 'updated_at'};
      final derived = {
        'subtotal_cents',
        'discount_cents',
        'tax_cents',
        'total_cents',
        'customer_name',
        'customer_email',
      };
      const itemDerived = {
        'tax_percent',
        'net_cents',
        'tax_cents',
        'total_cents',
      };
      const voucherDerived = {'code_snapshot', 'discount_cents'};
      if (items.any((node) => _materiallyChanged(node, itemDerived)) ||
          applications.any(
            (node) => _materiallyChanged(node, voucherDerived),
          ) ||
          _materiallyChanged(invoice, {...mutable, ...derived})) {
        _invalid(
          'status',
          'Issued invoice content is locked. Create a new document for corrections.',
        );
      }
      final status = _text(invoice, 'status');
      if (status == 'draft' ||
          (previousStatus == 'cancelled' && status != 'cancelled')) {
        _invalid(
          'status',
          'An issued or cancelled invoice cannot return to draft.',
        );
      }
      _patch(graph, invoice, {
        for (final key in derived) key: invoice.initial?[key]?.raw,
      });
      for (final item in items.where((item) => item.changed)) {
        _patch(graph, item, {
          for (final key in itemDerived) key: item.initial?[key]?.raw,
        });
      }
      for (final application in applications.where((row) => row.changed)) {
        _patch(graph, application, {
          for (final key in voucherDerived) key: application.initial?[key]?.raw,
        });
      }
      return;
    }
    final issued = _date(invoice, 'issued_at');
    final due = _date(invoice, 'due_at');
    if (issued == null) _invalid('issued_at', 'Choose the invoice date.');
    if (due != null && due.isBefore(issued)) {
      _invalid('due_at', 'The due date cannot precede the invoice date.');
    }
    final customer = await graph.linked(invoice, InvoiceModel.customer);
    if (customer == null) _invalid('customer_id', 'Choose a customer.');
    final order = await graph.linked(invoice, InvoiceModel.order);
    if (order != null &&
        !_sameRef(order.reference(OrderModel.customer), customer.ref)) {
      _invalid('order_id', 'The order belongs to another customer.');
    }
    final lineInputs = <ShopLineInput>[];
    final retainedItems = items.where((node) => !node.deleted).toList();
    for (final item in retainedItems) {
      lineInputs.add(
        await _line(graph, item, priceKey: 'unit_price', freeze: true),
      );
    }
    final retainedApplications =
        applications.where((node) => !node.deleted).toList()..sort((a, b) {
          final order = _integer(
            a,
            'position',
          ).compareTo(_integer(b, 'position'));
          return order == 0 ? _key(a.ref).compareTo(_key(b.ref)) : order;
        });
    final vouchers = <ShopVoucherInput>[];
    final positions = <int>{};
    for (final application in retainedApplications) {
      if (!positions.add(_integer(application, 'position'))) {
        _invalid('position', 'Give each voucher a different position.');
      }
      final voucher = await graph.linked(
        application,
        InvoiceVoucherModel.voucher,
      );
      if (voucher == null) _invalid('voucher_id', 'Choose a voucher.');
      final start = _date(voucher, 'starts_at');
      final end = _date(voucher, 'ends_at');
      if (voucher.values['active']?.raw != true ||
          (start != null && issued.isBefore(start)) ||
          (end != null && !issued.isBefore(end))) {
        _invalid(
          'voucher_id',
          'This voucher is not active on the invoice date.',
        );
      }
      vouchers.add(_voucher(voucher));
    }
    final totals = ShopTotals.calculate(lines: lineInputs, vouchers: vouchers);
    for (var index = 0; index < retainedItems.length; index++) {
      final total = totals.lines[index];
      _patch(graph, retainedItems[index], {
        'net_cents': total.netCents,
        'tax_cents': total.taxCents,
        'total_cents': total.totalCents,
      });
    }
    for (var index = 0; index < retainedApplications.length; index++) {
      final total = totals.vouchers[index];
      _patch(graph, retainedApplications[index], {
        'code_snapshot': total.input.code,
        'discount_cents': total.discountCents,
      });
    }
    _patch(graph, invoice, {
      'customer_name':
          '${_text(customer, 'first_name')} ${_text(customer, 'last_name')}'
              .trim(),
      'customer_email': _text(customer, 'email'),
      'subtotal_cents': totals.subtotalCents,
      'discount_cents': totals.discountCents,
      'tax_cents': totals.taxCents,
      'total_cents': totals.totalCents,
    });
  }
}

Never _invalid(String field, String message) => throw BeakValidationException(
  message,
  fieldErrors: {
    field: [message],
  },
);
String _key(BeakRecordRef ref) =>
    '${ref.table}:${ref.draftId == null ? 'saved:${ref.id}' : 'draft:${ref.draftId}'}';
bool _sameRef(BeakRecordRef? a, BeakRecordRef? b) =>
    a != null && b != null && _key(a) == _key(b);
bool _materiallyChanged(BeakCandidateNode node, Set<String> ignored) =>
    node.materiallyChanged(
      except: [
        for (final key in ignored)
          if (node.model.columnByKey(key) case final column?)
            BeakScalarField<Object>(model: node.model, column: column),
      ],
    );
void _patch(
  BeakCandidateGraph graph,
  BeakCandidateNode node,
  Map<String, Object?> values,
) => graph.patch(node, BeakRecord.fromRow(values));

void _validateOwnership(BeakSavePlan plan, BeakCandidateGraph graph) {
  for (final op in plan.operations) {
    if ((op.target.table == const InvoiceModel().table ||
            (op.target.table == const ProductModel().table &&
                op.relationKey == ProductModel.attributes.key)) &&
        (op.kind == BeakSaveOperationKind.attach ||
            op.kind == BeakSaveOperationKind.detach)) {
      _invalid(
        op.relationKey!,
        'Owned rows must be created or deleted rather than moved.',
      );
    }
  }
  for (final node in graph.nodes) {
    final relation = node.ref.table == const InvoiceItemModel().table
        ? InvoiceItemModel.invoice
        : node.ref.table == const InvoiceVoucherModel().table
        ? InvoiceVoucherModel.invoice
        : null;
    if (relation != null && node.initial != null && node.hasChanged(relation)) {
      _invalid(relation.key, 'An invoice row cannot move to another invoice.');
    }
  }
}

String _text(BeakCandidateNode node, String key) =>
    switch (node.values[key]?.raw) {
      final String value => value,
      _ => '',
    };
double _number(BeakCandidateNode node, String key) =>
    switch (node.values[key]?.raw) {
      final num value => value.toDouble(),
      null => 0,
      _ => throw BeakValidationException(
        'Invalid numeric value.',
        fieldErrors: {
          key: ['Enter a number.'],
        },
      ),
    };
int _integer(BeakCandidateNode node, String key) =>
    switch (node.values[key]?.raw) {
      final int value => value,
      _ => 0,
    };
DateTime? _date(BeakCandidateNode node, String key) =>
    switch (node.values[key]?.raw) {
      final DateTime value => value,
      final String value => DateTime.tryParse(value),
      _ => null,
    };
