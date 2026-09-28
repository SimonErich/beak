import 'dart:async';
import 'dart:io';

import 'package:beak/migrations.dart';
import 'package:foodio_adminpanel/beak/server.g.dart';
import 'package:foodio_adminpanel/domain/foodio_effects.dart';

/// Serves the generated API and drains the persistent local demo providers.
Future<void> main() async {
  final server = await beakHost().serve();
  final worker = const FoodioEffects().worker(Worm.adapter());
  final timer = Timer.periodic(const Duration(seconds: 1), (_) {
    unawaited(
      worker.drain().catchError((Object error, StackTrace trace) {
        stderr.writeln('Demo effect worker: $error');
        return 0;
      }),
    );
  });
  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    signal.watch().listen((_) async {
      timer.cancel();
      await server.close(force: true);
      exit(0);
    });
  }
  stderr.writeln(
    'Gabel API listening on http://${server.address.host}:${server.port}',
  );
}
