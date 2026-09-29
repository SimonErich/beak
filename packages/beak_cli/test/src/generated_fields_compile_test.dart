import 'dart:io';

import '../support/beak_cli_internals.dart';
import 'package:test/test.dart';

void main() {
  // The language version decides which lints the generated code is held to:
  // `prefer_initializing_formals` began to fire on private named parameters
  // at 3.12, and 3.11 must still compile what 3.12 accepts.
  for (final languageVersion in const ['3.11', '3.12']) {
    test('resource-local generated helpers compile and read live typed drafts '
        'at Dart $languageVersion', () async {
      final repoRoot = Directory.current.parent.parent;
      final root = Directory.systemTemp.createTempSync('beak_fields_');
      addTearDown(() => root.deleteSync(recursive: true));
      void write(String path, String source) {
        final file = File('${root.path}/$path')
          ..parent.createSync(recursive: true);
        file.writeAsStringSync(source);
      }

      write('pubspec.yaml', '''
name: generated_fields_probe
environment:
  sdk: ^$languageVersion.0
dependencies:
  beak_core:
    path: ${repoRoot.path}/packages/beak_core
dev_dependencies:
  lints: ^6.0.0
''');
      write(
        'analysis_options.yaml',
        File('${repoRoot.path}/analysis_options.yaml').readAsStringSync(),
      );
      write('lib/resources/customer/customer.dart', '''
// ignore_for_file: public_member_api_docs
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';
part 'customer.beak.dart';
@Resource()
final class Customer extends BeakSchema {
  @Display()
  late final String email;
  late final String? table;
  late final String? fields;
  late final String? search;
  late final String? summary;
  late final String? sumDecimal;
}
''');
      write('lib/resources/order/order.dart', '''
// ignore_for_file: public_member_api_docs
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';
import '../customer/customer.dart';
part 'order.beak.dart';
@Resource()
final class Order extends BeakSchema {
  late final String label;
  late final int quantity;
  late final double amount;
  late final bool ready;
  late final DateTime? arrivesAt;
  late final BeakDate deliveryDay;
  late final BeakTime openingTime;
  late final Duration elapsed;
  @Column(semantic: BeakSemantic.money(scale: 3), currencyFrom: #currency,
      defaultValue: BeakDecimal(125, scale: 3))
  late final BeakDecimal total;
  @Column(defaultValue: 'EUR')
  late final String currency;
  @Column(defaultValue: <String>[])
  late final List<String> tags;
  @Column(semantic: BeakSemantic.percentage(scale: 1), defaultValue: 0.025)
  late final double insuranceRate;
  late final List<int>? scores;
  late final List<double>? weights;
  late final List<bool>? switches;
  late final BeakJsonObject? settings;
  late final BeakJson? document;
  late final bool? approved;
  static List<BeakRecordRule> get validationRules => [];
  static BeakPermissions get permissions => BeakPermissions({
    BeakOperation.read: () => true,
  });
  static Set<BeakOperation> get capabilities => const {
    BeakOperation.read,
    BeakOperation.create,
  };
  static BeakModelBehavior get behavior => BeakModelBehavior(values: [
    BeakValueBehavior<int>.suggested(field: OrderModel.quantity,
      resolve: (_) => 3),
  ]);
  @BelongsTo()
  late final Customer customer;
}
''');
      final (schemas, issues) = BeakSchemaReader(root).read();
      expect(issues, isEmpty);
      for (final schema in schemas) {
        write(
          BeakSchemaEmitter.partPathOf(schema),
          BeakSchemaEmitter.emit(schema, schemas),
        );
      }
      write('bin/probe.dart', '''
import 'package:beak_core/beak_core.dart';
import 'package:generated_fields_probe/resources/customer/customer.dart';
import 'package:generated_fields_probe/resources/order/order.dart';
final class Reader implements BeakDraftReader {
  BeakRecord record = BeakRecord.fromRow({'quantity': 2});
  final List<String> reads = [];
  @override
  T? read<T extends Object>(BeakFieldRef<T> field) {
    reads.add(field.qualifiedKey);
    return field.readFrom(record);
  }
}
void main() {
  final reader = Reader();
  final draft = reader.asOrder;
  final int? before = draft.quantity;
  reader.record = BeakRecord.fromRow({'quantity': 7});
  final int? after = draft.quantity;
  if (before != 2 || after != 7 || reader.reads.length != 2) throw StateError('draft is not live');
  final BeakScalarField<String> email = OrderModel.customer.email;
  if (email.model.table != 'orders' || email.qualifiedKey != 'customer.email') throw StateError('lost owner path');
  final BeakScalarField<String> reserved = CustomerModel.fields.table;
  final BeakScalarField<String> nestedReserved = OrderModel.customer.fields.fields;
  if (reserved.key != 'table' || nestedReserved.qualifiedKey != 'customer.fields') throw StateError('reserved fields unavailable');
  final BeakScalarField<String> summary = CustomerModel.fields.summary;
  if (summary.key != 'summary' || CustomerModel.fields.sumDecimal.key != 'sum_decimal') throw StateError('model member names unavailable');
  final BeakOptionQuery options = CustomerModel.search('ada', filter: CustomerModel.email.contains('@'));
  if (options.query.table != 'customers') throw StateError('wrong query owner');
  const validation = BeakValidation();
  final defaults = validation.applyDefaults(const OrderModel(), const BeakRecord(values: {}));
  for (final column in const OrderModel().columns.where((column) => column.defaultValue != null)) {
    if (validation.columnErrors(column, defaults[column.key]?.raw).isNotEmpty) throw StateError('invalid generated default');
  }
  BeakModelRegistry().register(const OrderModel());
  final suggested = const OrderModel().behavior.apply(const BeakRecord(values: {}));
  if (OrderModel.quantity.readFrom(suggested) != 3) throw StateError('generated behavior not forwarded');
  if (!const OrderModel().permissions.allows(BeakOperation.read) || const OrderModel().permissions.allows(BeakOperation.delete)) throw StateError('generated permissions not forwarded');
  if (const OrderModel().capabilities.contains(BeakOperation.delete)) throw StateError('generated capabilities not forwarded');
  final money = BeakDecimal.parse('1.250', scale: 3);
  var record = const BeakRecord(values: {});
  record = OrderModel.total.writeTo(record, money);
  record = OrderModel.deliveryDay.writeTo(record, const BeakDate(2026, 2, 28));
  record = OrderModel.openingTime.writeTo(record, const BeakTime(9, 30));
  record = OrderModel.elapsed.writeTo(record, const Duration(minutes: 5));
  record = OrderModel.tags.writeTo(record, ['one', 'two']);
  final document = BeakJson.decode('{"nested":[1,true]}');
  record = OrderModel.document.writeTo(record, document);
  final BeakJson? typedDocument = record.asOrder.document;
  if (typedDocument != document) throw StateError('JSON document lost type');
  final BeakDecimal typedAmount = record.asOrder.total;
  final BeakDate typedDate = record.asOrder.deliveryDay;
  final BeakTime typedTime = record.asOrder.openingTime;
  final Duration typedDuration = record.asOrder.elapsed;
  final List<String> typedTags = record.asOrder.tags;
  if (typedAmount != money || typedDate.day != 28 || typedTime.hour != 9 || typedDuration.inMinutes != 5 || typedTags.length != 2) throw StateError('semantic read/write lost type');
  final BeakFilter moneyFilter = OrderModel.total.gte(money);
  if (moneyFilter is! BeakFieldFilter || moneyFilter.value != const BeakIntValue(1250)) throw StateError('money filter not scaled');
  if (OrderColumns.total.semantic.currencyColumn != OrderColumns.currency) throw StateError('currency reference lost');
  if (!OrderColumns.approved.tristate) throw StateError('nullable bool not tristate');
  if (!OrderModel.customer.isRequired || !OrderModel.customerId.isRequired) throw StateError('lost nullability');
}
''');
      Future<ProcessResult> run(List<String> args) => Process.run(
        Platform.resolvedExecutable,
        args,
        workingDirectory: root.path,
      );
      final resolved = await run(['pub', 'get', '--offline']);
      expect(
        resolved.exitCode,
        0,
        reason: '${resolved.stdout}\n${resolved.stderr}',
      );
      final analyzed = await run(['analyze', '--fatal-infos', '.']);
      expect(
        analyzed.exitCode,
        0,
        reason: '${analyzed.stdout}\n${analyzed.stderr}',
      );
      final executed = await run(['run', 'bin/probe.dart']);
      expect(
        executed.exitCode,
        0,
        reason: '${executed.stdout}\n${executed.stderr}',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
