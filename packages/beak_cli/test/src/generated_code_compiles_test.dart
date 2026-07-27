import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:beak_cli/beak_cli.dart';
import 'package:test/test.dart';

/// The zero-config proof, end to end: `beak make:resource Widget` in a fresh
/// project must compile, pass the repo's strict analysis, create its own
/// table, and serve a working API — with no database, no `.env` and no
/// configuration of any kind.
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

      Future<ProcessResult> run(List<String> command) => Process.run(
        command.first,
        command.skip(1).toList(),
        workingDirectory: temp.path,
      );

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
      final Process server = await Process.start(
        'dart',
        ['run', 'bin/serve.dart'],
        workingDirectory: temp.path,
        environment: {'PORT': '$port', 'HOST': '127.0.0.1'},
      );
      addTearDown(() => server.kill(ProcessSignal.sigkill));
      await _listening(server);

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
Future<void> _listening(Process server) async {
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
}
