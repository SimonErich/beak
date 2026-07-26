/// The umbrella exists to be one dependency line, so what it re-exports —
/// and what it deliberately does not — is the whole contract.
library;

import 'dart:io';

import 'package:beak/charts.dart';
import 'package:beak/migrations.dart' as migrations;
import 'package:beak/panel.dart';
import 'package:beak/schema.dart' as schema;
import 'package:beak/server.dart' as server;
import 'package:beak/testing.dart' as testing;
import 'package:beak/ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the panel library carries both halves of a panel', () {
    // A screen needs the core types and the widgets from one import, so
    // panel.dart re-exports beak.dart.
    expect(const BeakQuerySpec(table: 'products').table, 'products');
    expect(const BeakStringColumn(key: 'name', label: 'Name').key, 'name');
    expect(BeakPanel, isNotNull);
  });

  test('the shared library reaches neither Flutter nor a database', () {
    // bin/serve.dart reaches the registry, and the registry reaches the
    // models. If any of those pulled in dart:ui the server would stop
    // compiling ahead-of-time — which is exactly what happened once.
    final source = File(
      '${Directory.current.path}/lib/beak.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('beak_frontend')));
    expect(source, isNot(contains('beak_backend')));
    expect(source, isNot(contains('obers_ui')));
    expect(source, isNot(contains('worm')));
  });

  test('the schema library carries the authoring annotations', () {
    const resource = schema.Resource(softDeletes: true);

    expect(resource.softDeletes, isTrue);
    expect(const schema.Column(searchable: true).searchable, isTrue);
    expect(const schema.BeakText('hi'), 'hi');
  });

  test('the server library carries the host and the local disk driver', () {
    expect(server.BeakServeHost, isNotNull);
    expect(server.BeakLocalDiskStorageDriver, isNotNull);
  });

  test('the migrations library carries the ORM and the blueprint', () {
    expect(migrations.Migration, isNotNull);
    expect(migrations.BeakBlueprint, isNotNull);
    expect(migrations.OnDelete.cascade.name, 'cascade');
  });

  test('the testing library carries the in-memory source', () {
    expect(testing.InMemoryBeakDataSource, isNotNull);
  });

  test('the ui and charts libraries carry obers_ui', () {
    // Split deliberately: both packages declare an `OiAnnotationType`, so one
    // re-export would make the name ambiguous at every import site.
    expect(OiCard, isNotNull);
    expect(OiLineChart, isNotNull);
  });
}
