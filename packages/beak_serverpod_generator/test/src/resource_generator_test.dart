import 'dart:io';
import 'package:beak_serverpod_generator/beak_serverpod_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'wide commands receive generated enum slots beyond the default pool',
    () async {
      final source = File('test/fixtures/wide_resources.dart');
      final generated = File('test/fixtures/wide_resources.beak.g.dart');
      final runner = File('test/fixtures/verify_wide_resources.dart');
      addTearDown(() {
        for (final file in [source, generated, runner]) {
          if (file.existsSync()) file.deleteSync();
        }
      });
      final fields = List.generate(40, (index) => 'field$index');
      source.writeAsStringSync('''
class Wide { Wide({required this.id}); final int id; }
class Input { Input({${fields.map((name) => 'required this.$name').join(', ')}}); ${fields.map((name) => 'final String $name;').join(' ')} }
class Query { Query({this.page=1,this.pageSize=25}); final int page; final int pageSize; }
class Page { Page({required this.items,required this.totalCount}); final List<Wide> items; final int totalCount; }
class Client { Client(this.wide); final Endpoint wide; }
class Endpoint {
 Future<Page> list(Query query) async => Page(items:[],totalCount:0);
 Future<Wide> get(int id) async => Wide(id:id);
 Future<Wide> create(Input input) async => Wide(id:1);
 Future<Wide> update(int id,Input input) async => Wide(id:id);
}
''');
      generated.writeAsStringSync(
        await generateServerpodCompanions(
          packageRoot: Directory.current.path,
          library: Uri.file(source.absolute.path).toString(),
          types: const [],
          models: ['Wide'],
        ),
      );
      runner.writeAsStringSync('''
import 'package:beak_core/beak_core.dart';
import 'wide_resources.dart';
import 'wide_resources.beak.g.dart';
Future<void> main() async {
 final model = WideResource(client:Client(Endpoint()),resource:'wide',primaryKey:WideFields.id,columns:[WideFields.id.column('ID')]);
 for(final form in [model.createModel!,model.editModel!]) {
  if(form.columns.length!=40||form.formSlots?.length!=40||form.formSlots?.toSet().length!=40) throw StateError('wide command slots');
 }
 if(model.formSlots?.length!=1)throw StateError('read model slots');
 try { await model.dataSource.query(model.query().orderBy(BeakScalarField<Object>(model: model, column: model.primaryKey))); throw StateError('unsupported sort silently ignored'); } on BeakConfigurationException { }

}
''');
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        runner.path,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('unsupported endpoint contracts fail with specific diagnostics', () async {
    final fixture = File('test/fixtures/resources.dart').readAsStringSync();
    final source = File('test/fixtures/invalid_resources.dart');
    addTearDown(() {
      if (source.existsSync()) source.deleteSync();
    });
    final variants = <(String, String)>[
      (
        fixture.replaceFirst(
          'final EntryEndpoint entry;',
          'final EntryEndpoint entry; EntryEndpoint get duplicate => entry;',
        ),
        'one unambiguous',
      ),
      (
        fixture.replaceFirst('getById(UuidValue id)', 'fetch(UuidValue id)'),
        'get/getById',
      ),
      (
        fixture.replaceFirst('getById(UuidValue id)', 'getById(UuidValue? id)'),
        'non-null scalar',
      ),
      (
        fixture.replaceFirst('this.page = 0,', 'required this.page,'),
        'page/pageSize defaults',
      ),
      (
        fixture.replaceFirst(
          'Future<EntryView> getById',
          'Future<EntryView> get(UuidValue id) async => value; Future<EntryView> getById',
        ),
        'ambiguous operations',
      ),
      (
        fixture.replaceFirst(
          'create(EntryInput input)',
          'create(EntryInput input, EntryInput other)',
        ),
        'one typed input',
      ),
      (fixture.replaceAll('locale', 'tenant'), 'unsupported parameter tenant'),
    ];
    for (final (contents, diagnostic) in variants) {
      source.writeAsStringSync(contents);
      await expectLater(
        generateServerpodCompanions(
          packageRoot: Directory.current.path,
          library: Uri.file(source.absolute.path).toString(),
          types: const [],
          models: ['EntryView'],
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'diagnostic',
            contains(diagnostic),
          ),
        ),
      );
    }
    await expectLater(
      generateServerpodCompanions(
        packageRoot: Directory.current.path,
        library: Uri.file(
          p.absolute('test/fixtures/resources.dart'),
        ).toString(),
        types: const [],
        models: ['EntryView'],
        client: 'Absent',
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'diagnostic',
          contains('does not export client'),
        ),
      ),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'domain command results do not enable generic form capabilities',
    () async {
      final output = await generateServerpodCompanions(
        packageRoot: Directory.current.path,
        library: Uri.file(
          p.absolute('test/fixtures/read_resources.dart'),
        ).toString(),
        types: const [],
        models: ['EntryView'],
        client: 'ReadClient',
      );
      final generated = File('test/fixtures/read_resources.beak.g.dart');
      final runner = File('test/fixtures/verify_read_resources.dart');
      addTearDown(() {
        if (generated.existsSync()) generated.deleteSync();
        if (runner.existsSync()) runner.deleteSync();
      });
      generated.writeAsStringSync(output);
      runner.writeAsStringSync('''
import 'package:beak_core/beak_core.dart';
import 'read_resources.dart';
import 'read_resources.beak.g.dart';
Future<void> main() async {
  final model = EntryViewResource(client: ReadClient(ReadEndpoint()), resource: 'entries', primaryKey: EntryViewFields.entryId, columns: [EntryViewFields.entryTitle.column('Title')]);
  if (model.capabilities.length != 1 || !model.capabilities.contains(BeakOperation.read)) throw StateError('unsupported write capability');
  if (model.createModel != null || model.editModel != null) throw StateError('unsupported form');
  final source = model.dataSource;
  if ((await source.query(model.query())).total != 0) throw StateError('typed positional query');
  if (await source.getOne('entries', 'c4263bc1-cad9-453f-b4fa-e49891f8f824') != null) throw StateError('nullable read');
  try { await source.create('entries', const BeakRecord(values: {})); throw StateError('unsupported create accepted'); } on BeakValidationException { }
}
''');
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        runner.path,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'generates executable model-owned CRUD from resolved endpoints',
    () async {
      final output = await generateServerpodCompanions(
        packageRoot: Directory.current.path,
        library: Uri.file(
          p.absolute('test/fixtures/resources.dart'),
        ).toString(),
        types: const [],
        models: ['EntryView'],
      );
      expect(output, contains('class EntryViewResource'));
      final generated = File('test/fixtures/resources.beak.g.dart');
      final runner = File('test/fixtures/verify_resources.dart');
      addTearDown(() {
        if (generated.existsSync()) generated.deleteSync();
        if (runner.existsSync()) runner.deleteSync();
      });
      generated.writeAsStringSync(output);
      runner.writeAsStringSync('''
import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/beak_serverpod.dart';
import 'package:uuid/uuid_value.dart';
import 'resources.dart';
import 'resources.beak.g.dart';
Future<void> main() async {
 final id=UuidValue.fromString('c4263bc1-cad9-453f-b4fa-e49891f8f824');
 final endpoint=EntryEndpoint(EntryView(entry:Entry(id:id,title:'A',status:ResourceStatus.active)));
 var locale='en';var changed=0;
 final model=EntryViewResource(client:Client(endpoint),resource:'entries',primaryKey:EntryViewFields.entryId,createLabels:{EntryInputFields.roleIds:'Roles'},editLabels:{EntryInputFields.email:'Email override'},editValues:(value)=>EntryViewResource.editInput(value,email:value.entry.email??'fallback',roleIds:[]),locale:()=>locale,onChanged:()async{changed++;},columns:[
  EntryViewFields.entryTitle.column('Localized title',options:const ServerpodColumnOptions(sortable:true,searchable:true)),
  EntryViewFields.entryStatus.column('Status',options:const ServerpodColumnOptions(sortable:true,filterable:true,enumLabels:{ResourceStatus.active:'Aktiv',ResourceStatus.paused:'Pausiert'})),
 ]);
 final source=model.dataSource;
 final page=await source.query(const BeakQuerySpec(table:'entries').paginate(page:2,perPage:7));
 if(endpoint.lastQuery?.page!=1||page.page!=2||page.total!=42)throw StateError('page origin');
 if((await source.getOne('entries',id.uuid))?['id']?.raw!=id.uuid)throw StateError('routed UUID');
 locale='de';await source.query(const BeakQuerySpec(table:'entries'));
 if(endpoint.lastLocale!='de')throw StateError('live context');
 final input=BeakRecord(values:{'title':const BeakStringValue('B'),'status':const BeakStringValue('paused'),'email':const BeakStringValue('test@example.com'),'roleIds':const BeakListValue([])});
 await source.create('entries',input);await source.update('entries',id.uuid,input);await source.delete('entries',id.uuid);
 if(changed!=3||endpoint.writes!=3)throw StateError('mutations');
 if(model.createModel==null||model.editModel==null)throw StateError('command metadata');
 if(model.createModel!.columns.first.label!='Localized title')throw StateError('inherited label');
 if(model.createModel!.columns.last.label!='Roles'||model.editModel!.columns[2].label!='Email override')throw StateError('typed label overrides');
 final status=model.editModel!.columns[1];
 if(status is! BeakEnumColumn<ResourceStatus>||status.labelFor(ResourceStatus.paused)!='Pausiert')throw StateError('inherited enum labels');
 if(EntryViewResource.editInput(endpoint.value,email:'projected@example.com',roleIds:[]).title!='B')throw StateError('typed command projection');
 final prefill=await source.loadEditValues('entries',id);
 if(prefill['title']?.raw!='B')throw StateError('generated command projection');
 if(await source.aggregate(model.count())!=42)throw StateError('count');
 if((await source.batchGet('entries',[id.uuid])).length!=1)throw StateError('batch');
}
''');
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        runner.path,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
