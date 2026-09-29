import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../support/beak_cli_internals.dart';
import '../support/run_tool.dart';
import 'package:test/test.dart';

/// The zero-config proof, end to end: `beak make:resource Widget` in a fresh
/// project must compile, pass the repo's strict analysis (before and after
/// `beak eject main`), create its own table, and serve a working API, with
/// no database, no `.env` and no configuration of any kind.
///
/// The project depends on Beak the way a user's does: the umbrella, and
/// nothing else. Anything narrower would let a
/// `depend_on_referenced_packages` info through, which is a failure the
/// monorepo can never reproduce.
///
/// This exists because a scaffolded project once started a server whose every
/// endpoint failed on a missing table, and `beak doctor` reported all clear.
/// Compiling was never the claim; running is.
void main() {
  test(
    'a generated resource compiles, migrates and serves, with no setup',
    () async {
      final Directory repoRoot = Directory.current.parent.parent;
      final Directory temp = Directory.systemTemp.createTempSync(
        'beak_generated',
      );
      addTearDown(() => temp.deleteSync(recursive: true));

      final environment = BeakCliEnvironment(
        out: StringBuffer(),
        rootDirectory: temp,
        now: () => DateTime.utc(2026, 7, 3, 12),
        probe: (host, port) async => false,
      );
      File('${temp.path}/pubspec.yaml').writeAsStringSync('''
name: generated_probe
publish_to: none
environment:
  sdk: ^3.11.0
  flutter: '>=3.41.0'
dependencies:
  beak:
    path: ${repoRoot.path}/packages/beak
  flutter:
    sdk: flutter
dev_dependencies:
  lints: ^6.0.0
''');
      // Scaffold after the pubspec exists: `make:resource` now runs
      // `prepare`, which reads the package name from it to write the
      // entrypoint imports.
      final int? code = await createBeakRunner(environment).run([
        'make:resource',
        'Widget',
        '--fields',
        'name:string,notes:text,stock:int,price:decimal,'
            'active:bool,released_at:datetime',
      ]);
      expect(code, 0);

      File('${temp.path}/analysis_options.yaml').writeAsStringSync(
        File('${repoRoot.path}/analysis_options.yaml').readAsStringSync(),
      );

      Future<ProcessResult> run(List<String> command) =>
          runTool(command, workingDirectory: temp.path);

      final ProcessResult pubGet = await run(['flutter', 'pub', 'get']);
      expect(pubGet.exitCode, 0, reason: '${pubGet.stdout}\n${pubGet.stderr}');

      final ProcessResult format = await run(['dart', 'format', '.']);
      expect(format.exitCode, 0, reason: '${format.stdout}\n${format.stderr}');

      final ProcessResult analyze = await run([
        'dart',
        'analyze',
        '--fatal-infos',
        '--fatal-warnings',
        '.',
      ]);
      expect(
        analyze.exitCode,
        0,
        reason: '${analyze.stdout}\n${analyze.stderr}',
      );

      // The authored entrypoint `beak eject main` hands over is a file the
      // project now owns and lints, so it has to pass the same analysis.
      // A panel override and sidebar settings make it the config form,
      // the one `BeakPanel(resources:)` cannot express; `beak create
      // --authored` below proves the plain form.
      expect(await createBeakRunner(environment).run(['eject', 'panel']), 0);
      File(
        '${temp.path}/beak.yaml',
      ).writeAsStringSync('theme:\n  sidebar:\n    startCollapsed: true\n');
      expect(await createBeakRunner(environment).run(['eject', 'main']), 0);
      final String ejected = File(
        '${temp.path}/lib/main.dart',
      ).readAsStringSync();
      expect(ejected, contains('config: panel.beakPanel('));
      // Constant throughout, so `const` once, on the config.
      expect(ejected, contains('const BeakPanelConfig('));
      expect(ejected, contains('resources: [WidgetResource()]'));
      expect(ejected, contains('sidebarDefaultCollapsed: true'));
      final ProcessResult authored = await run([
        'dart',
        'analyze',
        '--fatal-infos',
        '--fatal-warnings',
        '.',
      ]);
      expect(
        authored.exitCode,
        0,
        reason: '${authored.stdout}\n${authored.stderr}',
      );

      // A theme override is a call, so the config is no longer constant and
      // must lose its `const` while the resources keep theirs. Deleting the
      // entrypoint hands it back to `beak prepare` for a second eject.
      File('${temp.path}/lib/main.dart').deleteSync();
      expect(await createBeakRunner(environment).run(['eject', 'theme']), 0);
      expect(await createBeakRunner(environment).run(['eject', 'main']), 0);
      final String themed = File(
        '${temp.path}/lib/main.dart',
      ).readAsStringSync();
      expect(themed, contains('theme: theme.beakLightTheme()'));
      expect(themed, isNot(contains('const BeakPanelConfig(')));
      expect(themed, contains('const WidgetResource()'));
      final ProcessResult themedAnalyze = await run([
        'dart',
        'analyze',
        '--fatal-infos',
        '--fatal-warnings',
        '.',
      ]);
      expect(
        themedAnalyze.exitCode,
        0,
        reason: '${themedAnalyze.stdout}\n${themedAnalyze.stderr}',
      );

      // The ejected server is the file a project edits to add a policy,
      // middleware or an outbox, so it has to compile against the host that
      // `beak prepare` then wires it into.
      expect(await createBeakRunner(environment).run(['eject', 'server']), 0);
      expect(await createBeakRunner(environment).run(['prepare']), 0);
      expect(
        File('${temp.path}/lib/beak/server.g.dart').readAsStringSync(),
        contains('configure: server.beakServer'),
      );
      final ProcessResult serverAnalyze = await run([
        'dart',
        'analyze',
        '--fatal-infos',
        '--fatal-warnings',
        '.',
      ]);
      expect(
        serverAnalyze.exitCode,
        0,
        reason: '${serverAnalyze.stdout}\n${serverAnalyze.stderr}',
      );

      // The generated migration, on the default SQLite file. No DATABASE_URL,
      // no services, nothing to install.
      final ProcessResult migrate = await run([
        'dart',
        'run',
        'bin/migrate.dart',
        'migrate',
      ]);
      expect(
        migrate.exitCode,
        0,
        reason: '${migrate.stdout}\n${migrate.stderr}',
      );
      expect(migrate.stdout, contains('create_widgets_table'));

      final int port = await _freePort();
      // The SDK's own binary, not the `dart` on PATH: the Flutter wrapper
      // script is a parent process that would take the SIGTERM below.
      final Process server = await Process.start(
        Platform.resolvedExecutable,
        ['run', 'bin/serve.dart'],
        workingDirectory: temp.path,
        environment: {'PORT': '$port', 'HOST': '127.0.0.1'},
      );
      addTearDown(() => server.kill(ProcessSignal.sigkill));
      final StringBuffer serverOutput = await _listening(server);

      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:$port/api/widgets/query'),
      );
      request.headers.contentType = ContentType.json;
      request.write('{"table":"widgets"}');
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();

      expect(response.statusCode, 200, reason: body);
      expect(
        jsonDecode(body),
        containsPair('total', 0),
        reason: 'the table exists and is empty, which is the whole claim',
      );

      // A deploy stops a server with SIGTERM; the generated entrypoint closes
      // the host's server, which stops the outbox loop, and exits cleanly.
      server.kill(ProcessSignal.sigterm);
      expect(
        await server.exitCode.timeout(const Duration(seconds: 30)),
        0,
        reason: '$serverOutput',
      );
      expect(serverOutput.toString(), contains('shutting down'));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  _authoredScaffoldAnalyzes();
}

/// `beak create --authored`, as a whole project: the owned entrypoint, its
/// resource class, the generated wiring and the smoke test that pumps it.
///
/// Each piece is asserted on as text elsewhere; only analyzing the project
/// as a whole shows they still agree on the panel's API, so renaming
/// `buildPanel` or `InMemoryBeakDataSource` cannot pass unnoticed.
void _authoredScaffoldAnalyzes() {
  test(
    'an authored scaffold is formatted and passes strict analysis',
    () async {
      final Directory repoRoot = Directory.current.parent.parent;
      final Directory temp = Directory.systemTemp.createTempSync(
        'beak_authored',
      );
      addTearDown(() => temp.deleteSync(recursive: true));

      final out = StringBuffer();
      final int? code =
          await createBeakRunner(
            BeakCliEnvironment(
              out: out,
              rootDirectory: temp,
              now: () => DateTime.utc(2026, 7, 3, 12),
              probe: (host, port) async => false,
              // Only `flutter create --platforms=web` is spawned, for web/
              // assets that analysis and the widget test do not need.
              runProcess: (executable, arguments, {workingDirectory}) async =>
                  0,
            ),
          ).run([
            'create',
            'authored_probe',
            '--authored',
            '--beak-path',
            repoRoot.path,
          ]);
      expect(code, 0, reason: '$out');

      final String project = '${temp.path}/authored_probe';
      Future<ProcessResult> run(List<String> command) =>
          runTool(command, workingDirectory: project);
      void expectSuccess(ProcessResult result) => expect(
        result.exitCode,
        0,
        reason: '${result.stdout}\n${result.stderr}',
      );

      expectSuccess(await run(['flutter', 'pub', 'get']));
      // As scaffolded, so the first `dart format` in a new project is a
      // no-op.
      expectSuccess(
        await run(['dart', 'format', '--set-exit-if-changed', 'lib', 'test']),
      );
      // The scaffold's own analysis options, which include the generated
      // files, and then the repo's stricter ones over what the project owns.
      expectSuccess(
        await run(['dart', 'analyze', '--fatal-infos', '--fatal-warnings']),
      );
      File('$project/analysis_options.yaml').writeAsStringSync(
        File('${repoRoot.path}/analysis_options.yaml').readAsStringSync(),
      );
      expectSuccess(
        await run(['dart', 'analyze', '--fatal-infos', '--fatal-warnings']),
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// A port nothing is listening on, released before it is handed over.
Future<int> _freePort() async {
  final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final int port = probe.port;
  await probe.close();
  return port;
}

/// Waits for [server] to say it is listening, or to die trying.
///
/// Returns everything the server writes from then on as well, for a test that
/// asserts on how it stops.
Future<StringBuffer> _listening(Process server) async {
  final ready = Completer<void>();
  final output = StringBuffer();
  void watch(Stream<List<int>> stream) {
    stream.transform(utf8.decoder).listen((chunk) {
      output.write(chunk);
      if (!ready.isCompleted && chunk.contains('listening on')) {
        ready.complete();
      }
    });
  }

  watch(server.stdout);
  watch(server.stderr);
  unawaited(
    server.exitCode.then((code) {
      if (!ready.isCompleted) {
        ready.completeError(StateError('the server exited $code:\n$output'));
      }
    }),
  );
  await ready.future.timeout(
    const Duration(seconds: 90),
    onTimeout: () => throw StateError('the server never listened:\n$output'),
  );
  return output;
}
