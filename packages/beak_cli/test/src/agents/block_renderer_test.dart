import 'dart:convert';
import 'dart:io';

import 'package:beak_cli/src/agents/beak_block_renderer.dart';
import 'package:test/test.dart';

void main() {
  BeakBlockValues values({bool mainIsGenerated = false, String? serverPkg}) =>
      BeakBlockValues(
        version: '0.9.0',
        docsIndex: '.dart_tool/beak/docs/ai-index.md',
        schemaGlob: 'lib/resources/*/models/*.dart',
        panelEntry: 'lib/main.dart',
        skills: 'run `beak agents` to install them',
        adminDir: 'admin',
        serverPkg: serverPkg,
        clientPkg: serverPkg == null ? null : 'shop_client',
        schemaPkg: serverPkg == null ? null : 'shop_beak',
        mainIsGenerated: mainIsGenerated,
      );

  const String begin = '<!-- BEGIN:beak-agent-rules -->';
  const String end = '<!-- END:beak-agent-rules -->';

  String template(String body) => '$begin\n$body$end\n';

  group('renderBlock', () {
    test('fills placeholders and ends at the END marker', () {
      final String block = renderBlock(
        template('Beak {{version}} at `{{docsIndex}}`.\n'),
        values(),
      );

      expect(
        block,
        '$begin\nBeak 0.9.0 at `.dart_tool/beak/docs/ai-index.md`.\n$end',
      );
    });

    test('fills a placeholder used more than once', () {
      expect(
        renderBlock(template('{{version}} {{version}}\n'), values()),
        contains('0.9.0 0.9.0'),
      );
    });

    test('keeps the lines of a section that holds, and drops its tags', () {
      const String source =
          '{{#mainIsGenerated}}\nyes\n{{/mainIsGenerated}}\n'
          '{{^mainIsGenerated}}\nno\n{{/mainIsGenerated}}\n';

      expect(
        renderBlock(template(source), values(mainIsGenerated: true)),
        '$begin\nyes\n$end',
      );
      expect(renderBlock(template(source), values()), '$begin\nno\n$end');
    });

    test('the serverpod section holds when there is a server package', () {
      const String source =
          '{{#serverpod}}\nS {{serverPkg}}\n{{/serverpod}}\n'
          '{{^serverpod}}\nplain\n{{/serverpod}}\n';

      expect(
        renderBlock(template(source), values(serverPkg: 'shop_server')),
        '$begin\nS shop_server\n$end',
      );
      expect(renderBlock(template(source), values()), '$begin\nplain\n$end');
    });

    test('sections nest', () {
      const String source =
          '{{#serverpod}}\nA\n{{#mainIsGenerated}}\nB\n'
          '{{/mainIsGenerated}}\nC\n{{/serverpod}}\n';

      expect(
        renderBlock(
          template(source),
          values(serverPkg: 's', mainIsGenerated: false),
        ),
        '$begin\nA\nC\n$end',
      );
    });

    test('a placeholder inside a dropped section is not evaluated', () {
      expect(
        renderBlock(
          template('{{#serverpod}}\n{{serverPkg}}\n{{/serverpod}}\nok\n'),
          values(),
        ),
        '$begin\nok\n$end',
      );
    });

    test('an unknown placeholder is an error naming it', () {
      expect(
        () => renderBlock(template('{{nope}}\n'), values()),
        throwsA(
          isA<BeakTemplateException>().having(
            (e) => e.message,
            'message',
            contains('{{nope}}'),
          ),
        ),
      );
    });

    test('a placeholder without a value is an error naming it', () {
      expect(
        () => renderBlock(template('{{serverPkg}}\n'), values()),
        throwsA(
          isA<BeakTemplateException>().having(
            (e) => e.message,
            'message',
            contains('{{serverPkg}}'),
          ),
        ),
      );
    });

    test('an unknown section is an error', () {
      expect(
        () =>
            renderBlock(template('{{#mystery}}\nx\n{{/mystery}}\n'), values()),
        throwsA(isA<BeakTemplateException>()),
      );
    });

    test('an unbalanced section is an error', () {
      expect(
        () => renderBlock(template('{{#serverpod}}\nx\n'), values()),
        throwsA(isA<BeakTemplateException>()),
      );
      expect(
        () => renderBlock(template('x\n{{/serverpod}}\n'), values()),
        throwsA(isA<BeakTemplateException>()),
      );
    });

    test('a template without the markers is an error', () {
      expect(
        () => renderBlock('text\n', values()),
        throwsA(isA<BeakTemplateException>()),
      );
    });
  });

  group('the fallback templates', () {
    Map<BeakBlockKind, String> onDisk() => {
      for (final kind in BeakBlockKind.values)
        kind: File(
          '../../docs/_agents/blocks/${kind.templateName}.md',
        ).readAsStringSync(),
    };

    test('are byte-equal to docs/_agents/blocks', () {
      final Map<BeakBlockKind, String> files = onDisk();
      for (final kind in BeakBlockKind.values) {
        expect(kind.fallbackTemplate, files[kind], reason: kind.templateName);
      }
    });

    test('name the four kinds by their file', () {
      expect(BeakBlockKind.values.map((kind) => kind.templateName), [
        'standalone',
        'embedded',
        'serverpod-admin',
        'workspace-root',
      ]);
    });

    test('render with every value they use, each under 2048 bytes', () {
      // The longest values a project can realistically produce.
      const longest = BeakBlockValues(
        version: '0.10.100',
        docsIndex: '../../../.dart_tool/beak/docs/ai-index.md',
        schemaGlob: 'lib/resources/*/models/*.dart`, `lib/models/*.dart',
        panelEntry: 'lib/admin_panel_main.dart',
        skills:
            '`beak-add-resource`, `beak-add-business-rule`, '
            '`beak-adopt-database`, `beak-evolve-schema`, '
            '`beak-secure-api`, `beak-upgrade`, '
            '`beak-frontend-build-screens`',
        adminDir: 'apps/mobile/acme_shop_admin',
        serverPkg: 'acme_shop_server',
        clientPkg: 'acme_shop_client',
        schemaPkg: 'acme_shop_beak',
      );
      for (final kind in BeakBlockKind.values) {
        for (final generated in [true, false]) {
          final String block = renderBlock(
            kind.fallbackTemplate,
            BeakBlockValues(
              version: longest.version,
              docsIndex: longest.docsIndex,
              schemaGlob: longest.schemaGlob,
              panelEntry: longest.panelEntry,
              skills: longest.skills,
              adminDir: longest.adminDir,
              serverPkg: longest.serverPkg,
              clientPkg: longest.clientPkg,
              schemaPkg: longest.schemaPkg,
              mainIsGenerated: generated,
            ),
          );

          expect(
            utf8.encode(block).length,
            lessThan(2048),
            reason: '${kind.templateName} generated=$generated',
          );
          expect(block, isNot(contains('—')));
          expect(block, isNot(contains('{{')));
          expect(block, startsWith(begin));
          expect(block, endsWith(end));
        }
      }
    });

    test('render without a server package for the kinds that need none', () {
      for (final kind in [
        BeakBlockKind.standalone,
        BeakBlockKind.embedded,
        BeakBlockKind.workspaceRoot,
      ]) {
        expect(
          () => renderBlock(kind.fallbackTemplate, values()),
          returnsNormally,
          reason: kind.templateName,
        );
      }
    });
  });
}
