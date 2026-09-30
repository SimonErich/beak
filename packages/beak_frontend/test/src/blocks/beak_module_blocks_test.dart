import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;

  final DateTime day = DateTime(2026, 7, 6, 9);

  setUp(() {
    dataSource = FakeDataSource(
      models: const [
        MeetingModel(),
        TaskModel(),
        MessageModel(),
        MailModel(),
        AssetModel(),
        InvoiceModel(),
        InvoiceLineModel(),
        ProfileModel(),
        PlanModel(),
        FaqModel(),
      ],
      records: {
        'meetings': {
          'm1': BeakRecord.fromRow({
            'id': 'm1',
            'title': 'Standup',
            'starts_at': day,
            'ends_at': day.add(const Duration(minutes: 30)),
            'all_day': false,
            'status': 'doing',
          }),
          'm2': BeakRecord.fromRow({
            'id': 'm2',
            'title': 'Review',
            'starts_at': day.add(const Duration(hours: 2)),
            'ends_at': day.add(const Duration(hours: 3)),
            'all_day': true,
            'status': 'done',
          }),
        },
        'tasks': {
          't1': BeakRecord.fromRow(const {
            'id': 't1',
            'title': 'Write docs',
            'assignee': 'Ada',
            'status': 'todo',
          }),
          't2': BeakRecord.fromRow(const {
            'id': 't2',
            'title': 'Ship it',
            'assignee': 'Linus',
            'status': 'doing',
          }),
        },
        'messages': {
          'g1': BeakRecord.fromRow({
            'id': 'g1',
            'author': 'Ada',
            'body': 'Hello there',
            'sent_at': day.add(const Duration(minutes: 5)),
            'from_me': false,
          }),
          'g2': BeakRecord.fromRow({
            'id': 'g2',
            'author': 'Me',
            'body': 'General Kenobi',
            'sent_at': day,
            'from_me': true,
          }),
        },
        'mail': {
          'e1': BeakRecord.fromRow(const {
            'id': 'e1',
            'sender': 'billing@acme.test',
            'subject': 'Invoice due',
            'preview': 'Your invoice is ready',
            'received_at': '2026-07-06',
            'unread': true,
          }),
        },
        'assets': {
          'a1': BeakRecord.fromRow(const {
            'id': 'a1',
            'name': 'Reports',
            'is_folder': true,
          }),
          'a2': BeakRecord.fromRow({
            'id': 'a2',
            'name': 'q3.pdf',
            'is_folder': false,
            'size_in_bytes': 2048,
            'updated_at': day,
          }),
        },
        'invoices': {
          'inv1': BeakRecord.fromRow(const {
            'id': 'inv1',
            'from_name': 'Acme Inc',
            'to_name': 'Globex',
            'subtotal': '100.00',
            'tax': '19.00',
            'total': '119.00',
          }),
        },
        'invoice_lines': {
          'l1': BeakRecord.fromRow(const {
            'id': 'l1',
            'invoice_id': 'inv1',
            'description': 'Consulting',
            'amount': '100.00',
          }),
        },
        'profiles': {
          'p1': BeakRecord.fromRow(const {
            'id': 'p1',
            'name': 'Grace Hopper',
            'email': 'grace@navy.test',
            'role': 'Rear Admiral',
            'bio': 'Compiler pioneer.',
          }),
        },
        'plans': {
          'pl1': BeakRecord(
            values: {
              'id': const BeakStringValue('pl1'),
              'name': const BeakStringValue('Pro'),
              'monthly_price': const BeakDoubleValue(29),
              'recommended': const BeakBoolValue(true),
              'description': const BeakStringValue('For teams'),
            },
            relations: {
              'features': [
                BeakRecord.fromRow(const {
                  'id': 'f1',
                  'label': 'Unlimited seats',
                }),
                BeakRecord.fromRow(const {
                  'id': 'f2',
                  'label': 'Priority support',
                }),
              ],
            },
          ),
        },
        'faqs': {
          'q1': BeakRecord.fromRow(const {
            'id': 'q1',
            'question': 'How do I reset my password?',
            'answer': 'Use the reset link on the login page.',
            'category': 'Account',
          }),
        },
      },
    );
    registerBeakDependencies(
      config: const BeakPanelConfig(
        title: 'Modules',
        apiBaseUrl: 'http://localhost',
        resources: [
          BeakResource(
            model: MeetingModel(),
            icon: BeakIconToken(OiIcons.calendar),
          ),
          BeakResource(
            model: TaskModel(),
            icon: BeakIconToken(OiIcons.columns),
          ),
          BeakResource(
            model: MessageModel(),
            icon: BeakIconToken(OiIcons.messageSquare),
          ),
          BeakResource(model: MailModel(), icon: BeakIconToken(OiIcons.inbox)),
          BeakResource(
            model: AssetModel(),
            icon: BeakIconToken(OiIcons.folder),
          ),
          BeakResource(
            model: InvoiceModel(),
            icon: BeakIconToken(OiIcons.receipt),
          ),
          BeakResource(
            model: InvoiceLineModel(),
            icon: BeakIconToken(OiIcons.list),
          ),
          BeakResource(
            model: ProfileModel(),
            icon: BeakIconToken(OiIcons.user),
          ),
          BeakResource(
            model: PlanModel(),
            icon: BeakIconToken(OiIcons.dollarSign),
          ),
          BeakResource(
            model: FaqModel(),
            icon: BeakIconToken(OiIcons.helpCircle),
          ),
        ],
      ),
      dataSource: dataSource,
    );
  });

  Future<void> pump(WidgetTester tester, BeakBlock block) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakBlockHost(block: block),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('BeakCalendarBlock', () {
    testWidgets('maps records onto OiCalendar events', (tester) async {
      await pump(
        tester,
        const BeakCalendarBlock(
          model: MeetingModel(),
          titleField: MeetingColumns.title,
          startField: MeetingColumns.startsAt,
          endField: MeetingColumns.endsAt,
          allDayField: MeetingColumns.allDay,
          categoryField: MeetingColumns.status,
        ),
      );

      expect(find.byType(OiCalendar), findsOneWidget);
      final calendar = tester.widget<OiCalendar>(find.byType(OiCalendar));
      expect(calendar.events, hasLength(2));
      final byTitle = {for (final e in calendar.events) e.title: e};
      expect(byTitle.keys, containsAll(<String>['Standup', 'Review']));
      expect(byTitle['Review']!.allDay, isTrue);
      expect(byTitle['Standup']!.color, isNotNull);
    });

    testWidgets('a row without a start is left out, not given today', (
      tester,
    ) async {
      dataSource = FakeDataSource(
        models: const [MeetingModel()],
        records: {
          'meetings': {
            'm1': BeakRecord.fromRow({
              'id': 'm1',
              'title': 'Standup',
              'starts_at': day,
            }),
            'm2': BeakRecord.fromRow(const {
              'id': 'm2',
              'title': 'Someday',
              'starts_at': null,
            }),
          },
        },
      );
      registerBeakDependencies(
        config: const BeakPanelConfig(
          title: 'Modules',
          apiBaseUrl: 'http://localhost',
          resources: [
            BeakResource(
              model: MeetingModel(),
              icon: BeakIconToken(OiIcons.calendar),
            ),
          ],
        ),
        dataSource: dataSource,
      );
      await pump(
        tester,
        const BeakCalendarBlock(
          model: MeetingModel(),
          titleField: MeetingColumns.title,
          startField: MeetingColumns.startsAt,
        ),
      );

      final calendar = tester.widget<OiCalendar>(find.byType(OiCalendar));
      expect(calendar.events.map((event) => event.title), ['Standup']);
    });

    testWidgets('a tap resolves back to the record; a drag persists', (
      tester,
    ) async {
      BeakRecord? tapped;
      await pump(
        tester,
        BeakCalendarBlock(
          model: const MeetingModel(),
          titleField: MeetingColumns.title,
          startField: MeetingColumns.startsAt,
          endField: MeetingColumns.endsAt,
          onEventTap: (record) => tapped = record,
        ),
      );

      final calendar = tester.widget<OiCalendar>(find.byType(OiCalendar));
      final event = calendar.events.firstWhere((e) => e.title == 'Standup');
      calendar.onEventTap!(event);
      expect(tapped, isNotNull);
      expect(tapped![MeetingColumns.title.key]?.raw, 'Standup');

      final DateTime moved = day.add(const Duration(days: 1));
      calendar.onEventMove!(event, moved, moved.add(const Duration(hours: 1)));
      await tester.pumpAndSettle();
      expect(dataSource.updateCalls, hasLength(1));
      final (table, id, data) = dataSource.updateCalls.single;
      expect(table, 'meetings');
      expect(id, 'm1');
      expect(switch (data[MeetingColumns.startsAt.key]?.raw) {
        final DateTime stored => stored.isAtSameMomentAs(moved),
        _ => false,
      }, isTrue);
    });
  });

  group('BeakCalendarBlock time zone', () {
    // A panel pinned to UTC+2: the wall clock on screen is two hours ahead of
    // the stored instant, whatever zone the machine running the test is in.
    const formatting = BeakFormatting(timeZoneOffsetMinutes: 120);

    testWidgets('shows an event at the panel zone and moves it by wall clock', (
      tester,
    ) async {
      final source = FakeDataSource(
        models: const [MeetingModel()],
        records: {
          'meetings': {
            'm1': BeakRecord.fromRow({
              'id': 'm1',
              'title': 'Standup',
              'starts_at': DateTime.utc(2026, 7, 6, 7),
              'ends_at': DateTime.utc(2026, 7, 6, 7, 30),
              'all_day': false,
              'status': 'doing',
            }),
          },
        },
      );
      registerBeakDependencies(
        config: const BeakPanelConfig(
          title: 'Modules',
          apiBaseUrl: 'http://localhost',
          resources: [
            BeakResource(
              model: MeetingModel(),
              icon: BeakIconToken(OiIcons.calendar),
            ),
          ],
        ),
        dataSource: source,
      );
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        BeakFormattingScope(
          formatting: formatting,
          child: OiApp(
            theme: OiThemeData.light(),
            home: const BeakBlockHost(
              block: BeakCalendarBlock(
                model: MeetingModel(),
                titleField: MeetingColumns.title,
                startField: MeetingColumns.startsAt,
                endField: MeetingColumns.endsAt,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final calendar = tester.widget<OiCalendar>(find.byType(OiCalendar));
      final event = calendar.events.single;
      expect(event.start.hour, 9, reason: '07:00Z is 09:00 in UTC+2');
      expect(event.end.minute, 30);

      // The calendar reports the new wall clock as a local DateTime.
      calendar.onEventMove!(
        event,
        DateTime(2026, 7, 8, 9),
        DateTime(2026, 7, 8, 9, 30),
      );
      await tester.pumpAndSettle();

      final (_, _, data) = source.updateCalls.single;
      final start = switch (data[MeetingColumns.startsAt.key]?.raw) {
        final DateTime value => value,
        _ => null,
      };
      final end = switch (data[MeetingColumns.endsAt.key]?.raw) {
        final DateTime value => value,
        _ => null,
      };
      expect(
        start?.isAtSameMomentAs(DateTime.utc(2026, 7, 8, 7)),
        isTrue,
        reason: 'the stored instant keeps the 09:00 wall clock of UTC+2',
      );
      expect(end?.isAtSameMomentAs(DateTime.utc(2026, 7, 8, 7, 30)), isTrue);
    });
  });

  group('read-only time blocks use the panel zone', () {
    const formatting = BeakFormatting(timeZoneOffsetMinutes: 120);

    Future<void> pumpZoned(WidgetTester tester, BeakBlock block) async {
      registerBeakDependencies(
        config: const BeakPanelConfig(
          title: 'Modules',
          apiBaseUrl: 'http://localhost',
          resources: [
            BeakResource(
              model: MessageModel(),
              icon: BeakIconToken(OiIcons.messageSquare),
            ),
          ],
        ),
        dataSource: FakeDataSource(
          models: const [MessageModel()],
          records: {
            'messages': {
              'g1': BeakRecord.fromRow({
                'id': 'g1',
                'author': 'Ada',
                'body': 'Hello there',
                'sent_at': DateTime.utc(2026, 7, 6, 7),
                'from_me': false,
              }),
            },
          },
        ),
      );
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        BeakFormattingScope(
          formatting: formatting,
          child: OiApp(
            theme: OiThemeData.light(),
            home: BeakBlockHost(block: block),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a chat message is stamped in the panel zone', (tester) async {
      await pumpZoned(
        tester,
        const BeakChatBlock(
          model: MessageModel(),
          authorField: MessageColumns.author,
          bodyField: MessageColumns.body,
          timeField: MessageColumns.sentAt,
          isMineField: MessageColumns.fromMe,
        ),
      );

      final chat = tester.widget<OiChat>(find.byType(OiChat));
      expect(chat.messages.single.timestamp.hour, 9);
    });

    testWidgets('a timeline event sits at the panel zone', (tester) async {
      await pumpZoned(
        tester,
        const BeakTimelineBlock(
          query: BeakQuerySpec(table: 'messages'),
          titleField: MessageColumns.body,
          timeField: MessageColumns.sentAt,
        ),
      );

      final timeline = tester.widget<OiTimeline>(find.byType(OiTimeline));
      expect(timeline.events.single.timestamp.hour, 9);
    });
  });

  group('BeakKanbanBlock', () {
    testWidgets('one column per enum value, records grouped', (tester) async {
      await pump(
        tester,
        const BeakKanbanBlock(
          model: TaskModel(),
          groupField: TaskModel.status,
          titleField: TaskColumns.title,
          subtitleField: TaskColumns.assignee,
        ),
      );

      expect(find.byType(OiKanban<BeakRecord>), findsOneWidget);
      final board = tester.widget<OiKanban<BeakRecord>>(
        find.byType(OiKanban<BeakRecord>),
      );
      expect(board.columns, hasLength(TaskStatus.values.length));
      final todo = board.columns.firstWhere((c) => c.key == 'todo');
      final doing = board.columns.firstWhere((c) => c.key == 'doing');
      expect(todo.items, hasLength(1));
      expect(doing.items, hasLength(1));
      expect(todo.items.single[TaskColumns.title.key]?.raw, 'Write docs');
      expect(find.text('Write docs'), findsWidgets);
    });

    test('the group field must be an enum field of the block model', () {
      BeakKanbanBlock boardGroupedBy(BeakScalarField<Enum> field) =>
          BeakKanbanBlock(
            model: const TaskModel(),
            groupField: field,
            titleField: TaskColumns.title,
          );
      expect(
        boardGroupedBy(TaskModel.status).groupColumn,
        same(TaskColumns.status),
      );
      const notAnEnum = BeakScalarField<Enum>(
        model: TaskModel(),
        column: TaskColumns.title,
      );
      const elsewhere = BeakScalarField<Enum>(
        model: MeetingModel(),
        column: TaskColumns.status,
      );
      const related = BeakScalarField<Enum>(
        model: TaskModel(),
        column: TaskColumns.status,
        path: [MailRelations.folder],
      );
      for (final field in [notAnEnum, elsewhere, related]) {
        expect(
          () => boardGroupedBy(field).groupColumn,
          throwsA(isA<BeakConfigurationException>()),
        );
      }
    });

    testWidgets('dropping a card persists its new group', (tester) async {
      BeakRecord? moved;
      await pump(
        tester,
        BeakKanbanBlock(
          model: const TaskModel(),
          groupField: TaskModel.status,
          titleField: TaskColumns.title,
          onCardMove: (record) => moved = record,
        ),
      );

      final board = tester.widget<OiKanban<BeakRecord>>(
        find.byType(OiKanban<BeakRecord>),
      );
      final BeakRecord card = board.columns
          .firstWhere((c) => c.key == 'todo')
          .items
          .single;
      board.onCardMove!(card, 'todo', 'done', 0);
      await tester.pumpAndSettle();

      expect(moved, isNotNull);
      expect(dataSource.updateCalls, hasLength(1));
      final (table, id, data) = dataSource.updateCalls.single;
      expect(table, 'tasks');
      expect(id, 't1');
      expect(data[TaskColumns.status.key]?.raw, 'done');
    });
  });

  group('BeakChatBlock', () {
    testWidgets('orders by time and marks own messages', (tester) async {
      await pump(
        tester,
        const BeakChatBlock(
          model: MessageModel(),
          authorField: MessageColumns.author,
          bodyField: MessageColumns.body,
          timeField: MessageColumns.sentAt,
          isMineField: MessageColumns.fromMe,
        ),
      );

      expect(find.byType(OiChat), findsOneWidget);
      final chat = tester.widget<OiChat>(find.byType(OiChat));
      expect(chat.messages, hasLength(2));
      // g2 (09:00) precedes g1 (09:05).
      expect(chat.messages.first.content, 'General Kenobi');
      expect(chat.messages.first.senderId, chat.currentUserId);
      expect(chat.messages.last.senderId, isNot(chat.currentUserId));
    });
  });

  group('BeakInboxBlock', () {
    testWidgets('lists rows and binds the detail pane on selection', (
      tester,
    ) async {
      await pump(
        tester,
        const BeakInboxBlock(
          model: MailModel(),
          senderField: MailColumns.sender,
          subjectField: MailColumns.subject,
          previewField: MailColumns.preview,
          timeField: MailColumns.receivedAt,
          folders: ['Inbox', 'Archive'],
        ),
      );

      expect(find.byType(OiThreeColumnLayout), findsOneWidget);
      expect(find.byType(OiListView<BeakRecord>), findsOneWidget);
      expect(find.text('Invoice due'), findsWidgets);
      expect(find.text('Select a message'), findsOneWidget);

      await tester.tap(find.text('Invoice due').first);
      await tester.pumpAndSettle();

      expect(find.text('Select a message'), findsNothing);
      expect(find.byType(OiKeyValue), findsWidgets);
    });
  });

  group('BeakFileManagerBlock', () {
    testWidgets('maps folder and file records onto OiFileManager', (
      tester,
    ) async {
      await pump(
        tester,
        const BeakFileManagerBlock(
          model: AssetModel(),
          nameField: AssetColumns.name,
          isFolderField: AssetColumns.isFolder,
          sizeField: AssetColumns.sizeInBytes,
          modifiedField: AssetColumns.updatedAt,
        ),
      );

      expect(find.byType(OiFileManager), findsOneWidget);
      final manager = tester.widget<OiFileManager>(find.byType(OiFileManager));
      expect(manager.items, hasLength(2));
      final folder = manager.items.firstWhere((n) => n.folder);
      final file = manager.items.firstWhere((n) => !n.folder);
      expect(folder.name, 'Reports');
      expect(file.name, 'q3.pdf');
      expect(file.size, 2048);
    });
  });

  group('BeakInvoiceBlock', () {
    testWidgets('composes header, line items, and totals', (tester) async {
      await pump(
        tester,
        const BeakInvoiceBlock(
          model: InvoiceModel(),
          recordId: 'inv1',
          fromFields: [InvoiceColumns.fromName],
          toFields: [InvoiceColumns.toName],
          lineItemsModel: InvoiceLineModel(),
          lineItemsForeignKey: InvoiceLineColumns.invoiceId,
          subtotalField: InvoiceColumns.subtotal,
          taxField: InvoiceColumns.tax,
          totalField: InvoiceColumns.total,
        ),
      );

      expect(find.text('Invoice'), findsWidgets);
      expect(find.text('Acme Inc'), findsWidgets);
      expect(find.text('Globex'), findsWidgets);
      expect(find.byType(BeakDataTable), findsOneWidget);
      expect(find.text('119.00'), findsWidgets);
    });
  });

  group('BeakInvoiceBlock line items', () {
    testWidgets('offer no delete on a document line', (tester) async {
      await pump(
        tester,
        const BeakInvoiceBlock(
          model: InvoiceModel(),
          recordId: 'inv1',
          fromFields: [InvoiceColumns.fromName],
          toFields: [InvoiceColumns.toName],
          lineItemsModel: InvoiceLineModel(),
          lineItemsForeignKey: InvoiceLineColumns.invoiceId,
          totalField: InvoiceColumns.total,
        ),
      );

      final table = tester.widget<BeakDataTable>(find.byType(BeakDataTable));
      expect(table.enableDelete, isFalse);
    });
  });

  group('BeakFileManagerBlock', () {
    testWidgets('reads a full page, not the default of 25', (tester) async {
      await pump(
        tester,
        const BeakFileManagerBlock(
          model: AssetModel(),
          nameField: AssetColumns.name,
          isFolderField: AssetColumns.isFolder,
        ),
      );

      final spec = dataSource.queryCalls.single;
      expect(spec.pagination.perPage, BeakPagination.maxPerPage);
    });
  });

  group('BeakProfileBlock', () {
    testWidgets('renders one record on OiProfilePage', (tester) async {
      await pump(
        tester,
        const BeakProfileBlock(
          model: ProfileModel(),
          recordId: 'p1',
          nameField: ProfileColumns.name,
          emailField: ProfileColumns.email,
          roleField: ProfileColumns.role,
          bioField: ProfileColumns.bio,
        ),
      );

      expect(find.byType(OiProfilePage), findsOneWidget);
      final page = tester.widget<OiProfilePage>(find.byType(OiProfilePage));
      expect(page.profile.name, 'Grace Hopper');
      expect(page.profile.email, 'grace@navy.test');
      expect(page.profile.role, 'Rear Admiral');
      expect(page.profile.bio, 'Compiler pioneer.');
    });
  });

  group('BeakPricingBlock', () {
    testWidgets('maps plans and their feature relation', (tester) async {
      await pump(
        tester,
        const BeakPricingBlock(
          model: PlanModel(),
          nameField: PlanColumns.name,
          priceField: PlanColumns.monthlyPrice,
          featuredField: PlanColumns.recommended,
          descriptionField: PlanColumns.description,
          featuresRelation: PlanRelations.features,
          featureLabelField: FeatureColumns.label,
        ),
      );

      expect(find.byType(OiPricingTable), findsOneWidget);
      final table = tester.widget<OiPricingTable>(find.byType(OiPricingTable));
      expect(table.plans, hasLength(1));
      final plan = table.plans.single;
      expect(plan.name, 'Pro');
      expect(plan.monthlyPrice, 29);
      expect(plan.recommended, isTrue);
      expect(plan.features, ['Unlimited seats', 'Priority support']);
    });
  });

  group('BeakFaqBlock', () {
    testWidgets('maps records onto OiHelpCenter FAQ items', (tester) async {
      await pump(
        tester,
        const BeakFaqBlock(
          model: FaqModel(),
          questionField: FaqColumns.question,
          answerField: FaqColumns.answer,
          categoryField: FaqColumns.category,
        ),
      );

      expect(find.byType(OiHelpCenter), findsOneWidget);
      final center = tester.widget<OiHelpCenter>(find.byType(OiHelpCenter));
      expect(center.faq, hasLength(1));
      expect(center.faq.single.question, 'How do I reset my password?');
      expect(center.faq.single.category, 'Account');
      expect(center.showContact, isFalse);
    });
  });

  group('module hardening (audit regressions)', () {
    testWidgets('kanban fetches one full sorted page', (tester) async {
      await pump(
        tester,
        const BeakKanbanBlock(
          model: TaskModel(),
          groupField: TaskModel.status,
          titleField: TaskColumns.title,
          sortField: TaskColumns.title,
        ),
      );

      final spec = dataSource.queryCalls.single;
      expect(spec.pagination.perPage, BeakPagination.maxPerPage);
      expect(spec.sorts.single.columnKey, TaskColumns.title.key);
    });

    testWidgets('a dropped kanban card stays in its new column', (
      tester,
    ) async {
      await pump(
        tester,
        const BeakKanbanBlock(
          model: TaskModel(),
          groupField: TaskModel.status,
          titleField: TaskColumns.title,
        ),
      );

      final board = tester.widget<OiKanban<BeakRecord>>(
        find.byType(OiKanban<BeakRecord>),
      );
      final BeakRecord card = board.columns
          .firstWhere((c) => c.key == 'todo')
          .items
          .single;
      board.onCardMove!(card, 'todo', 'done', 0);
      await tester.pumpAndSettle();

      // The rendered board mirrors the persisted move instead of snapping
      // the card back to its old column.
      final rebuilt = tester.widget<OiKanban<BeakRecord>>(
        find.byType(OiKanban<BeakRecord>),
      );
      expect(rebuilt.columns.firstWhere((c) => c.key == 'todo').items, isEmpty);
      expect(
        rebuilt.columns.firstWhere((c) => c.key == 'done').items,
        hasLength(1),
      );
    });

    testWidgets('pricing requests the feature relation and sort', (
      tester,
    ) async {
      await pump(
        tester,
        const BeakPricingBlock(
          model: PlanModel(),
          nameField: PlanColumns.name,
          priceField: PlanColumns.monthlyPrice,
          featuresRelation: PlanRelations.features,
          featureLabelField: FeatureColumns.label,
          sortField: PlanColumns.monthlyPrice,
        ),
      );

      final spec = dataSource.queryCalls.single;
      expect(spec.relationLoads.single.relationKey, PlanRelations.features.key);
      expect(spec.sorts.single.columnKey, PlanColumns.monthlyPrice.key);
      expect(spec.pagination.perPage, BeakPagination.maxPerPage);
    });

    testWidgets('chat is a read-only transcript without composeRecord', (
      tester,
    ) async {
      await pump(
        tester,
        const BeakChatBlock(
          model: MessageModel(),
          authorField: MessageColumns.author,
          bodyField: MessageColumns.body,
          timeField: MessageColumns.sentAt,
        ),
      );

      // No composer: typed text could never be persisted.
      expect(find.byType(EditableText), findsNothing);
      // The fetch page is newest-first so overflow drops old messages.
      final spec = dataSource.queryCalls.single;
      expect(spec.sorts.single.columnKey, MessageColumns.sentAt.key);
      expect(spec.sorts.single.descending, isTrue);
    });

    testWidgets('a sent chat message persists and appears', (tester) async {
      await pump(
        tester,
        BeakChatBlock(
          model: const MessageModel(),
          authorField: MessageColumns.author,
          bodyField: MessageColumns.body,
          timeField: MessageColumns.sentAt,
          composeRecord: (body) => BeakRecord.fromRow({
            'author': 'Me',
            'body': body,
            'sent_at': DateTime(2026, 7, 6, 10),
            'from_me': true,
          }),
        ),
      );

      await tester.enterText(find.byType(EditableText), 'Hello there, again');
      await tester.tap(find.bySemanticsLabel('Send message'));
      await tester.pumpAndSettle();

      final (table, data) = dataSource.createCalls.single;
      expect(table, 'messages');
      expect(data[MessageColumns.body.key]?.raw, 'Hello there, again');
      expect(find.text('Hello there, again'), findsWidgets);
    });

    testWidgets('inbox filters by the selected data-driven folder', (
      tester,
    ) async {
      const folderLabel = BeakStringColumn(key: 'label', label: 'Folder');
      BeakRecord mail(
        String id,
        String subject,
        String folder, {
        required bool unread,
      }) => BeakRecord(
        values: {
          'id': BeakStringValue(id),
          'sender': const BeakStringValue('a@b.test'),
          'subject': BeakStringValue(subject),
          'unread': BeakBoolValue(unread),
        },
        relations: {
          'folder': [
            BeakRecord.fromRow({'id': 'f-$folder', 'label': folder}),
          ],
        },
      );
      final inboxSource = FakeDataSource(
        models: const [MailModel()],
        records: {
          'mail': {
            'e1': mail('e1', 'Invoice due', 'Inbox', unread: true),
            'e2': mail('e2', 'Old newsletter', 'Archive', unread: false),
          },
        },
      );
      registerBeakDependencies(
        config: const BeakPanelConfig(
          title: 'Modules',
          apiBaseUrl: 'http://localhost',
          resources: [
            BeakResource(
              model: MailModel(),
              icon: BeakIconToken(OiIcons.inbox),
            ),
          ],
        ),
        dataSource: inboxSource,
      );

      await pump(
        tester,
        const BeakInboxBlock(
          model: MailModel(),
          senderField: MailColumns.sender,
          subjectField: MailColumns.subject,
          unreadField: MailColumns.unread,
          folderRelation: MailModel.folder,
          folderLabelField: folderLabel,
        ),
      );

      // The relation is requested and both folders' mail is listed.
      expect(
        inboxSource.queryCalls.single.relationLoads.single.relationKey,
        'folder',
      );
      expect(find.text('Invoice due'), findsOneWidget);
      expect(find.text('Old newsletter'), findsOneWidget);
      // Exactly the unread row carries the dot marker.
      expect(
        find.byWidgetPredicate(
          (widget) => widget is OiIcon && widget.icon == OiIcons.circleSmall,
        ),
        findsOneWidget,
      );

      // Selecting a data-driven folder narrows the list to it.
      await tester.tap(find.text('Archive').first);
      await tester.pumpAndSettle();
      expect(find.text('Old newsletter'), findsOneWidget);
      expect(find.text('Invoice due'), findsNothing);
    });

    testWidgets('profile field edits persist through the data source', (
      tester,
    ) async {
      await pump(
        tester,
        const BeakProfileBlock(
          model: ProfileModel(),
          recordId: 'p1',
          nameField: ProfileColumns.name,
          emailField: ProfileColumns.email,
        ),
      );

      final page = tester.widget<OiProfilePage>(find.byType(OiProfilePage));
      final bool saved = await page.onFieldSave!('name', 'Amazing Grace');
      expect(saved, isTrue);
      final (table, id, data) = dataSource.updateCalls.single;
      expect(table, 'profiles');
      expect(id, 'p1');
      expect(data[ProfileColumns.name.key]?.raw, 'Amazing Grace');
      // A field without a bound column reports failure, not a silent drop.
      expect(await page.onFieldSave!('phone', '555-1234'), isFalse);
    });

    testWidgets('invoice renders details, related bill-to, and formatted '
        'totals', (tester) async {
      const money = BeakDecimalColumn(
        key: 'total',
        label: 'Total',
        prefix: r'$',
      );
      const billedParty = InvoiceRelations.user;
      final invoiceSource = FakeDataSource(
        models: const [InvoiceModel(), InvoiceLineModel(), ProfileModel()],
        records: {
          'invoices': {
            'inv1': BeakRecord(
              values: const {
                'id': BeakStringValue('inv1'),
                'from_name': BeakStringValue('Acme Inc'),
                'subtotal': BeakStringValue('100.00'),
                'tax': BeakStringValue('19.00'),
                'total': BeakStringValue('119.0'),
              },
              relations: {
                'user': [
                  BeakRecord.fromRow(const {
                    'id': 'p1',
                    'name': 'Grace Hopper',
                    'email': 'grace@navy.test',
                  }),
                ],
              },
            ),
          },
          'invoice_lines': const {},
        },
      );
      registerBeakDependencies(
        config: const BeakPanelConfig(
          title: 'Modules',
          apiBaseUrl: 'http://localhost',
          resources: [
            BeakResource(
              model: InvoiceModel(),
              icon: BeakIconToken(OiIcons.receipt),
            ),
            BeakResource(
              model: InvoiceLineModel(),
              icon: BeakIconToken(OiIcons.list),
            ),
          ],
        ),
        dataSource: invoiceSource,
      );

      await pump(
        tester,
        const BeakInvoiceBlock(
          model: InvoiceModel(),
          recordId: 'inv1',
          metaFields: [InvoiceColumns.fromName],
          toRelation: billedParty,
          toPartyFields: [ProfileColumns.name, ProfileColumns.email],
          lineItemsModel: InvoiceLineModel(),
          lineItemsForeignKey: InvoiceLineColumns.invoiceId,
          totalField: money,
        ),
      );

      // Invoice meta sits under "Details", the billed party under "To".
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('To'), findsOneWidget);
      expect(find.text('Grace Hopper'), findsWidgets);
      // Postgres string numerics format with the currency prefix/precision.
      expect(find.text(r'$119.00'), findsOneWidget);
      // The relation arrived through an eager-loading primary-key query.
      final spec = invoiceSource.queryCalls.first;
      expect(spec.relationLoads.single.relationKey, 'user');
    });

    testWidgets('faq fetch carries the configured sort', (tester) async {
      await pump(
        tester,
        const BeakFaqBlock(
          model: FaqModel(),
          questionField: FaqColumns.question,
          answerField: FaqColumns.answer,
          sortField: FaqColumns.question,
        ),
      );

      final spec = dataSource.queryCalls.single;
      expect(spec.sorts.single.columnKey, FaqColumns.question.key);
      expect(spec.pagination.perPage, BeakPagination.maxPerPage);
    });
  });

  group('writes from module blocks', () {
    /// Registers a panel over [source] and mounts [block] on it.
    Future<void> pumpOver(
      WidgetTester tester,
      FakeDataSource source,
      BeakBlock block,
    ) async {
      registerBeakDependencies(
        config: const BeakPanelConfig(
          title: 'Modules',
          apiBaseUrl: 'http://localhost',
          resources: [
            BeakResource(
              model: MeetingModel(),
              icon: BeakIconToken(OiIcons.calendar),
            ),
            BeakResource(
              model: TaskModel(),
              icon: BeakIconToken(OiIcons.columns),
            ),
            BeakResource(
              model: MessageModel(),
              icon: BeakIconToken(OiIcons.messageSquare),
            ),
          ],
        ),
        dataSource: source,
      );
      dataSource = source;
      await pump(tester, block);
    }

    FakeDataSource refusing() => _RefusingSource(
      models: const [MeetingModel(), TaskModel(), MessageModel()],
      records: {
        'tasks': {
          't1': BeakRecord.fromRow(const {
            'id': 't1',
            'title': 'Write docs',
            'status': 'todo',
          }),
        },
        'meetings': {
          'm1': BeakRecord.fromRow({
            'id': 'm1',
            'title': 'Standup',
            'starts_at': day,
            'ends_at': day.add(const Duration(minutes: 30)),
            'all_day': false,
            'status': 'doing',
          }),
        },
      },
    );

    testWidgets('a refused card move says so and does not report a move', (
      tester,
    ) async {
      BeakRecord? moved;
      await pumpOver(
        tester,
        refusing(),
        BeakKanbanBlock(
          model: const TaskModel(),
          groupField: TaskModel.status,
          titleField: TaskColumns.title,
          onCardMove: (record) => moved = record,
        ),
      );

      final board = tester.widget<OiKanban<BeakRecord>>(
        find.byType(OiKanban<BeakRecord>),
      );
      final card = board.columns
          .firstWhere((c) => c.key == 'todo')
          .items
          .single;
      board.onCardMove!(card, 'todo', 'done', 0);
      await tester.pumpAndSettle();

      expect(find.text('Read only.', findRichText: true), findsOneWidget);
      expect(moved, isNull);
      final rebuilt = tester.widget<OiKanban<BeakRecord>>(
        find.byType(OiKanban<BeakRecord>),
      );
      expect(
        rebuilt.columns.firstWhere((c) => c.key == 'todo').items,
        hasLength(1),
      );
      await _letToastExpire(tester);
    });

    testWidgets('a confirmed card move reports the move once', (tester) async {
      var moves = 0;
      await pumpOver(
        tester,
        FakeDataSource(
          models: const [TaskModel()],
          records: {
            'tasks': {
              't1': BeakRecord.fromRow(const {
                'id': 't1',
                'title': 'Write docs',
                'status': 'todo',
              }),
            },
          },
        ),
        BeakKanbanBlock(
          model: const TaskModel(),
          groupField: TaskModel.status,
          titleField: TaskColumns.title,
          onCardMove: (_) => moves++,
        ),
      );

      final board = tester.widget<OiKanban<BeakRecord>>(
        find.byType(OiKanban<BeakRecord>),
      );
      board.onCardMove!(
        board.columns.firstWhere((c) => c.key == 'todo').items.single,
        'todo',
        'done',
        0,
      );
      await tester.pumpAndSettle();

      expect(moves, 1);
    });

    testWidgets('a card dropped in its own column writes and reports nothing', (
      tester,
    ) async {
      var moves = 0;
      final source = FakeDataSource(
        models: const [TaskModel()],
        records: {
          'tasks': {
            't1': BeakRecord.fromRow(const {
              'id': 't1',
              'title': 'Write docs',
              'status': 'todo',
            }),
          },
        },
      );
      await pumpOver(
        tester,
        source,
        BeakKanbanBlock(
          model: const TaskModel(),
          groupField: TaskModel.status,
          titleField: TaskColumns.title,
          onCardMove: (_) => moves++,
        ),
      );

      final board = tester.widget<OiKanban<BeakRecord>>(
        find.byType(OiKanban<BeakRecord>),
      );
      board.onCardMove!(
        board.columns.firstWhere((c) => c.key == 'todo').items.single,
        'todo',
        'todo',
        0,
      );
      await tester.pumpAndSettle();

      expect(moves, 0);
      expect(source.updateCalls, isEmpty);
    });

    testWidgets('a refused event move says so and does not report a move', (
      tester,
    ) async {
      var moves = 0;
      await pumpOver(
        tester,
        refusing(),
        BeakCalendarBlock(
          model: const MeetingModel(),
          titleField: MeetingColumns.title,
          startField: MeetingColumns.startsAt,
          endField: MeetingColumns.endsAt,
          onEventMove: (_, _, _) => moves++,
        ),
      );

      final calendar = tester.widget<OiCalendar>(find.byType(OiCalendar));
      final event = calendar.events.single;
      final later = day.add(const Duration(days: 1));
      calendar.onEventMove!(event, later, later.add(const Duration(hours: 1)));
      await tester.pumpAndSettle();

      expect(find.text('Read only.', findRichText: true), findsOneWidget);
      expect(moves, 0);
      await _letToastExpire(tester);
    });

    testWidgets('a refused message says so and is not appended', (
      tester,
    ) async {
      await pumpOver(
        tester,
        refusing(),
        BeakChatBlock(
          model: const MessageModel(),
          authorField: MessageColumns.author,
          bodyField: MessageColumns.body,
          timeField: MessageColumns.sentAt,
          composeRecord: (body) => BeakRecord.fromRow({
            'author': 'Me',
            'body': body,
            'sent_at': day,
            'from_me': true,
          }),
        ),
      );

      final chat = tester.widget<OiChat>(find.byType(OiChat));
      chat.onSend!('Hello');
      await tester.pumpAndSettle();

      expect(find.text('Read only.', findRichText: true), findsOneWidget);
      expect(tester.widget<OiChat>(find.byType(OiChat)).messages, isEmpty);
      await _letToastExpire(tester);
    });
  });

  group('module blocks read a filtered, bounded page', () {
    testWidgets('kanban, calendar and chat send their filter', (tester) async {
      const status = TaskModel.status;
      final filter = status.eq(TaskStatus.todo);
      await pump(
        tester,
        BeakKanbanBlock(
          model: const TaskModel(),
          groupField: TaskModel.status,
          titleField: TaskColumns.title,
          filter: filter,
        ),
      );
      expect(dataSource.queryCalls.last.filter, filter);

      dataSource.clearRecordedCalls();
      const title = BeakScalarField<String>(
        model: MeetingModel(),
        column: MeetingColumns.title,
      );
      final meetings = title.contains('Stand');
      await pump(
        tester,
        BeakCalendarBlock(
          model: const MeetingModel(),
          titleField: MeetingColumns.title,
          startField: MeetingColumns.startsAt,
          filter: meetings,
        ),
      );
      expect(dataSource.queryCalls.last.filter, meetings);

      dataSource.clearRecordedCalls();
      const author = BeakScalarField<String>(
        model: MessageModel(),
        column: MessageColumns.author,
      );
      final mine = author.eq('Me');
      await pump(
        tester,
        BeakChatBlock(
          model: const MessageModel(),
          authorField: MessageColumns.author,
          bodyField: MessageColumns.body,
          timeField: MessageColumns.sentAt,
          filter: mine,
        ),
      );
      expect(dataSource.queryCalls.last.filter, mine);
    });

    testWidgets('a result larger than the page says how much is shown', (
      tester,
    ) async {
      final wide = _TruncatedSource(
        models: const [TaskModel()],
        records: {
          'tasks': {
            't1': BeakRecord.fromRow(const {
              'id': 't1',
              'title': 'Write docs',
              'status': 'todo',
            }),
          },
        },
        total: 340,
      );
      registerBeakDependencies(
        config: const BeakPanelConfig(
          title: 'Modules',
          apiBaseUrl: 'http://localhost',
          resources: [
            BeakResource(
              model: TaskModel(),
              icon: BeakIconToken(OiIcons.columns),
            ),
          ],
        ),
        dataSource: wide,
      );
      await pump(
        tester,
        const BeakKanbanBlock(
          model: TaskModel(),
          groupField: TaskModel.status,
          titleField: TaskColumns.title,
        ),
      );

      expect(find.text('Showing the first 1 of 340.'), findsOneWidget);
    });
  });

  group('a module block whose read fails', () {
    testWidgets('says so, keeps nothing invented, and a retry reads again', (
      tester,
    ) async {
      final flaky = _UnreadableSource(
        models: const [TaskModel()],
        records: {
          'tasks': {
            't1': BeakRecord.fromRow(const {
              'id': 't1',
              'title': 'Write docs',
              'status': 'todo',
            }),
          },
        },
      );
      registerBeakDependencies(
        config: const BeakPanelConfig(
          title: 'Modules',
          apiBaseUrl: 'http://localhost',
          resources: [
            BeakResource(
              model: TaskModel(),
              icon: BeakIconToken(OiIcons.columns),
            ),
          ],
        ),
        dataSource: flaky,
      );
      await pump(
        tester,
        const BeakKanbanBlock(
          model: TaskModel(),
          groupField: TaskModel.status,
          titleField: TaskColumns.title,
        ),
      );

      expect(
        find.text('The operation could not be completed.'),
        findsOneWidget,
      );
      expect(find.textContaining('disk detail'), findsNothing);
      expect(find.text('Write docs'), findsNothing);

      flaky.failing = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsNothing);
      expect(find.text('Write docs'), findsOneWidget);
    });
  });

  group('a record block whose read fails', () {
    Future<_UnreadableSource> mount(
      WidgetTester tester,
      BeakBlock block,
    ) async {
      final flaky = _UnreadableSource(
        models: const [ProfileModel(), InvoiceModel(), InvoiceLineModel()],
        records: {
          'profiles': {
            'p1': BeakRecord.fromRow(const {
              'id': 'p1',
              'name': 'Grace Hopper',
              'email': 'grace@navy.test',
            }),
          },
          'invoices': {
            'inv1': BeakRecord.fromRow(const {
              'id': 'inv1',
              'from_name': 'Acme Inc',
              'total': '119.00',
            }),
          },
        },
      );
      registerBeakDependencies(
        config: const BeakPanelConfig(
          title: 'Modules',
          apiBaseUrl: 'http://localhost',
          resources: [
            BeakResource(
              model: ProfileModel(),
              icon: BeakIconToken(OiIcons.user),
            ),
            BeakResource(
              model: InvoiceModel(),
              icon: BeakIconToken(OiIcons.file),
            ),
          ],
        ),
        dataSource: flaky,
      );
      await pump(tester, block);
      return flaky;
    }

    testWidgets('a profile says so instead of loading for ever', (
      tester,
    ) async {
      final flaky = await mount(
        tester,
        const BeakProfileBlock(
          model: ProfileModel(),
          recordId: 'p1',
          nameField: ProfileColumns.name,
          emailField: ProfileColumns.email,
        ),
      );

      expect(find.text('Loading…'), findsNothing);
      expect(
        find.text('The operation could not be completed.'),
        findsOneWidget,
      );

      flaky.failing = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(OiProfilePage), findsOneWidget);
    });

    testWidgets('an invoice says so instead of loading for ever', (
      tester,
    ) async {
      await mount(
        tester,
        const BeakInvoiceBlock(
          model: InvoiceModel(),
          recordId: 'inv1',
          fromFields: [InvoiceColumns.fromName],
          lineItemsModel: InvoiceLineModel(),
          totalField: InvoiceColumns.total,
        ),
      );

      expect(find.text('Loading…'), findsNothing);
      expect(
        find.text('The operation could not be completed.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('data blocks refetch after a confirmed write', () {
    testWidgets('a chart, a board and a calendar query again', (tester) async {
      final source = FakeDataSource(
        models: const [MeetingModel(), TaskModel()],
        records: {
          'tasks': {
            't1': BeakRecord.fromRow(const {
              'id': 't1',
              'title': 'Write docs',
              'status': 'todo',
            }),
          },
          'meetings': {
            'm1': BeakRecord.fromRow({
              'id': 'm1',
              'title': 'Standup',
              'starts_at': day,
              'ends_at': day.add(const Duration(minutes: 30)),
              'status': 'doing',
            }),
          },
        },
      );
      registerBeakDependencies(
        config: const BeakPanelConfig(
          title: 'Modules',
          apiBaseUrl: 'http://localhost',
          resources: [
            BeakResource(
              model: MeetingModel(),
              icon: BeakIconToken(OiIcons.calendar),
            ),
            BeakResource(
              model: TaskModel(),
              icon: BeakIconToken(OiIcons.columns),
            ),
          ],
        ),
        dataSource: source,
      );
      dataSource = source;
      final blocks = <BeakBlock>[
        BeakChartBlock(
          title: 'Tasks',
          type: BeakChartType.bar,
          query: const TaskModel().query(),
          map: (records) => [
            for (final record in records)
              BeakChartPoint(label: '${record['title']?.raw}', value: 1),
          ],
        ),
        const BeakKanbanBlock(
          model: TaskModel(),
          groupField: TaskModel.status,
          titleField: TaskColumns.title,
        ),
        const BeakCalendarBlock(
          model: MeetingModel(),
          titleField: MeetingColumns.title,
          startField: MeetingColumns.startsAt,
        ),
      ];
      final tables = ['tasks', 'tasks', 'meetings'];
      for (final (index, block) in blocks.indexed) {
        source.clearRecordedCalls();
        await pump(tester, block);
        final before = source.queryCalls.length;
        expect(before, 1, reason: '${block.runtimeType} loads once');

        await beakLocator<BeakDataSource>().update(
          tables[index],
          index < 2 ? 't1' : 'm1',
          BeakRecord.fromRow({'title': 'Renamed $index'}),
        );
        await tester.pumpAndSettle();

        expect(
          source.queryCalls.length,
          before + 1,
          reason: '${block.runtimeType} refetches after a write',
        );
      }
    });
  });
}

/// Lets a shown toast run out, so the next test starts without one.
Future<void> _letToastExpire(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 10));
  await tester.pumpAndSettle();
}

/// A source whose writes are refused, as a read-only account's would be.
final class _RefusingSource extends FakeDataSource {
  _RefusingSource({super.records, super.models});

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) =>
      Future.error(const BeakAuthorizationException('Read only.'));

  @override
  Future<BeakRecord> create(String table, BeakRecord data) =>
      Future.error(const BeakAuthorizationException('Read only.'));
}

/// A source whose reads fail until [failing] is cleared.
final class _UnreadableSource extends FakeDataSource {
  _UnreadableSource({super.records, super.models});

  bool failing = true;

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    if (failing) throw const BeakStorageException('disk detail');
    return super.query(spec);
  }

  @override
  Future<BeakRecord?> getOne(String table, Object id) async {
    if (failing) throw const BeakStorageException('disk detail');
    return super.getOne(table, id);
  }
}

/// A source that reports more matching rows than it returns.
final class _TruncatedSource extends FakeDataSource {
  _TruncatedSource({super.records, super.models, required this.total});

  final int total;

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    final page = await super.query(spec);
    return BeakPage(
      items: page.items,
      total: total,
      page: page.page,
      perPage: page.perPage,
    );
  }
}

/// Board / meeting status with badge colors, exercising the enum-driven
/// Kanban columns and calendar tinting.
enum TaskStatus {
  /// Not started.
  todo,

  /// In progress.
  doing,

  /// Finished.
  done,
}

/// Typed columns of the [MeetingModel] fixture.
abstract final class MeetingColumns {
  /// Primary key.
  static const id = BeakStringColumn(key: 'id', label: 'Id');

  /// Event title.
  static const title = BeakStringColumn(key: 'title', label: 'Title');

  /// Start instant.
  static const startsAt = BeakDateTimeColumn(key: 'starts_at', label: 'Starts');

  /// End instant.
  static const endsAt = BeakDateTimeColumn(key: 'ends_at', label: 'Ends');

  /// All-day flag.
  static const allDay = BeakBoolColumn(key: 'all_day', label: 'All day');

  /// Status with badge colors.
  static const status = BeakEnumColumn<TaskStatus>(
    key: 'status',
    label: 'Status',
    values: TaskStatus.values,
    badgeColors: {
      TaskStatus.todo: BeakColor.muted,
      TaskStatus.doing: BeakColor.info,
      TaskStatus.done: BeakColor.success,
    },
  );

  /// All columns.
  static const List<BeakColumn> values = [
    id,
    title,
    startsAt,
    endsAt,
    allDay,
    status,
  ];
}

/// A meetings fixture model.
final class MeetingModel extends BeakModel {
  /// Creates the model.
  const MeetingModel();

  @override
  String get table => 'meetings';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => MeetingColumns.values;
}

/// Typed columns of the [TaskModel] fixture.
abstract final class TaskColumns {
  /// Primary key.
  static const id = BeakStringColumn(key: 'id', label: 'Id');

  /// Card title.
  static const title = BeakStringColumn(key: 'title', label: 'Title');

  /// Card subtitle.
  static const assignee = BeakStringColumn(key: 'assignee', label: 'Assignee');

  /// Grouping status.
  static const status = BeakEnumColumn<TaskStatus>(
    key: 'status',
    label: 'Status',
    values: TaskStatus.values,
  );

  /// All columns.
  static const List<BeakColumn> values = [id, title, assignee, status];
}

/// A tasks fixture model.
final class TaskModel extends BeakModel {
  /// Creates the model.
  const TaskModel();

  /// Typed reference to the grouping status.
  static const status = BeakScalarField<TaskStatus>(
    model: TaskModel(),
    column: TaskColumns.status,
  );

  @override
  String get table => 'tasks';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => TaskColumns.values;
}

/// Typed columns of the [MessageModel] fixture.
abstract final class MessageColumns {
  /// Primary key.
  static const id = BeakStringColumn(key: 'id', label: 'Id');

  /// Message author.
  static const author = BeakStringColumn(key: 'author', label: 'Author');

  /// Message body.
  static const body = BeakStringColumn(key: 'body', label: 'Body');

  /// Sent timestamp.
  static const sentAt = BeakDateTimeColumn(key: 'sent_at', label: 'Sent');

  /// Outgoing flag.
  static const fromMe = BeakBoolColumn(key: 'from_me', label: 'From me');

  /// All columns.
  static const List<BeakColumn> values = [id, author, body, sentAt, fromMe];
}

/// A messages fixture model.
final class MessageModel extends BeakModel {
  /// Creates the model.
  const MessageModel();

  @override
  String get table => 'messages';

  @override
  String get displayColumnKey => 'body';

  @override
  List<BeakColumn> get columns => MessageColumns.values;
}

/// Typed columns of the [MailModel] fixture.
abstract final class MailColumns {
  /// Primary key.
  static const id = BeakStringColumn(key: 'id', label: 'Id');

  /// Sender address.
  static const sender = BeakStringColumn(key: 'sender', label: 'Sender');

  /// Subject line.
  static const subject = BeakStringColumn(key: 'subject', label: 'Subject');

  /// Body preview.
  static const preview = BeakStringColumn(key: 'preview', label: 'Preview');

  /// Received timestamp.
  static const receivedAt = BeakStringColumn(
    key: 'received_at',
    label: 'Received',
  );

  /// Unread flag.
  static const unread = BeakBoolColumn(key: 'unread', label: 'Unread');

  /// All columns.
  static const List<BeakColumn> values = [
    id,
    sender,
    subject,
    preview,
    receivedAt,
    unread,
  ];
}

/// A mail fixture model.
final class MailModel extends BeakModel {
  /// Creates the model.
  const MailModel();

  /// Typed reference to the folder a message sits in.
  static const folder = BeakToOneField(
    model: MailModel(),
    relation: MailRelations.folder,
    target: MailFolderModel(),
  );

  @override
  String get table => 'mail';

  @override
  String get displayColumnKey => 'subject';

  @override
  List<BeakColumn> get columns => MailColumns.values;

  @override
  List<BeakRelationship> get relationships => const [MailRelations.folder];
}

/// The folders a [MailModel] message can sit in.
final class MailFolderModel extends BeakModel {
  /// Creates the model.
  const MailFolderModel();

  @override
  String get table => 'mail_folders';

  @override
  String get displayColumnKey => 'label';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'label', label: 'Folder'),
  ];
}

/// Typed relations of the [MailModel] fixture.
abstract final class MailRelations {
  /// The folder the message sits in.
  static const folder = BeakBelongsTo(
    key: 'folder',
    label: 'Folder',
    relatedTable: 'mail_folders',
    displayColumnKey: 'label',
    foreignKey: 'folder_id',
  );
}

/// Typed columns of the [AssetModel] fixture.
abstract final class AssetColumns {
  /// Primary key.
  static const id = BeakStringColumn(key: 'id', label: 'Id');

  /// Entry name.
  static const name = BeakStringColumn(key: 'name', label: 'Name');

  /// Folder flag.
  static const isFolder = BeakBoolColumn(key: 'is_folder', label: 'Folder');

  /// File size.
  static const sizeInBytes = BeakIntColumn(key: 'size_in_bytes', label: 'Size');

  /// Modified timestamp.
  static const updatedAt = BeakDateTimeColumn(
    key: 'updated_at',
    label: 'Updated',
  );

  /// All columns.
  static const List<BeakColumn> values = [
    id,
    name,
    isFolder,
    sizeInBytes,
    updatedAt,
  ];
}

/// An assets fixture model.
final class AssetModel extends BeakModel {
  /// Creates the model.
  const AssetModel();

  @override
  String get table => 'assets';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => AssetColumns.values;
}

/// Typed columns of the [InvoiceModel] fixture.
abstract final class InvoiceColumns {
  /// Primary key.
  static const id = BeakStringColumn(key: 'id', label: 'Id');

  /// Issuer name.
  static const fromName = BeakStringColumn(key: 'from_name', label: 'From');

  /// Recipient name.
  static const toName = BeakStringColumn(key: 'to_name', label: 'To');

  /// Subtotal.
  static const subtotal = BeakStringColumn(key: 'subtotal', label: 'Subtotal');

  /// Tax total.
  static const tax = BeakStringColumn(key: 'tax', label: 'Tax');

  /// Grand total.
  static const total = BeakStringColumn(key: 'total', label: 'Total');

  /// All columns.
  static const List<BeakColumn> values = [
    id,
    fromName,
    toName,
    subtotal,
    tax,
    total,
  ];
}

/// An invoices fixture model.
final class InvoiceModel extends BeakModel {
  /// Creates the model.
  const InvoiceModel();

  @override
  String get table => 'invoices';

  @override
  String get displayColumnKey => 'id';

  @override
  List<BeakColumn> get columns => InvoiceColumns.values;

  @override
  List<BeakRelationship> get relationships => const [InvoiceRelations.user];
}

/// Typed relations of the [InvoiceModel] fixture.
abstract final class InvoiceRelations {
  /// The billed party.
  static const user = BeakBelongsTo(
    key: 'user',
    label: 'Bill to',
    relatedTable: 'profiles',
    displayColumnKey: 'name',
    foreignKey: 'user_id',
  );
}

/// Typed columns of the [InvoiceLineModel] fixture.
abstract final class InvoiceLineColumns {
  /// Primary key.
  static const id = BeakStringColumn(key: 'id', label: 'Id');

  /// Parent invoice foreign key.
  static const invoiceId = BeakStringColumn(
    key: 'invoice_id',
    label: 'Invoice',
  );

  /// Line description.
  static const description = BeakStringColumn(
    key: 'description',
    label: 'Item',
  );

  /// Line amount.
  static const amount = BeakStringColumn(key: 'amount', label: 'Amount');

  /// All columns.
  static const List<BeakColumn> values = [id, invoiceId, description, amount];
}

/// An invoice-lines fixture model.
final class InvoiceLineModel extends BeakModel {
  /// Creates the model.
  const InvoiceLineModel();

  @override
  String get table => 'invoice_lines';

  @override
  String get displayColumnKey => 'description';

  @override
  List<BeakColumn> get columns => InvoiceLineColumns.values;
}

/// Typed columns of the [ProfileModel] fixture.
abstract final class ProfileColumns {
  /// Primary key.
  static const id = BeakStringColumn(key: 'id', label: 'Id');

  /// Display name.
  static const name = BeakStringColumn(key: 'name', label: 'Name');

  /// Email.
  static const email = BeakStringColumn(key: 'email', label: 'Email');

  /// Role.
  static const role = BeakStringColumn(key: 'role', label: 'Role');

  /// Bio.
  static const bio = BeakTextColumn(key: 'bio', label: 'Bio');

  /// All columns.
  static const List<BeakColumn> values = [id, name, email, role, bio];
}

/// A profiles fixture model.
final class ProfileModel extends BeakModel {
  /// Creates the model.
  const ProfileModel();

  @override
  String get table => 'profiles';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => ProfileColumns.values;
}

/// Typed columns read from a plan's feature relation records.
abstract final class FeatureColumns {
  /// Feature bullet label.
  static const label = BeakStringColumn(key: 'label', label: 'Feature');
}

/// Typed relations of the [PlanModel] fixture.
abstract final class PlanRelations {
  /// The plan's features.
  static const features = BeakHasMany(
    key: 'features',
    label: 'Features',
    relatedTable: 'features',
    displayColumnKey: 'label',
    foreignKey: 'plan_id',
  );
}

/// Typed columns of the [PlanModel] fixture.
abstract final class PlanColumns {
  /// Primary key.
  static const id = BeakStringColumn(key: 'id', label: 'Id');

  /// Plan name.
  static const name = BeakStringColumn(key: 'name', label: 'Name');

  /// Monthly price.
  static const monthlyPrice = BeakDecimalColumn(
    key: 'monthly_price',
    label: 'Price',
  );

  /// Recommended flag.
  static const recommended = BeakBoolColumn(
    key: 'recommended',
    label: 'Recommended',
  );

  /// Description.
  static const description = BeakStringColumn(
    key: 'description',
    label: 'Description',
  );

  /// All columns.
  static const List<BeakColumn> values = [
    id,
    name,
    monthlyPrice,
    recommended,
    description,
  ];
}

/// A plans fixture model.
final class PlanModel extends BeakModel {
  /// Creates the model.
  const PlanModel();

  @override
  String get table => 'plans';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => PlanColumns.values;

  @override
  List<BeakRelationship> get relationships => const [PlanRelations.features];
}

/// Typed columns of the [FaqModel] fixture.
abstract final class FaqColumns {
  /// Primary key.
  static const id = BeakStringColumn(key: 'id', label: 'Id');

  /// Question text.
  static const question = BeakStringColumn(key: 'question', label: 'Question');

  /// Answer text.
  static const answer = BeakTextColumn(key: 'answer', label: 'Answer');

  /// Category.
  static const category = BeakStringColumn(key: 'category', label: 'Category');

  /// All columns.
  static const List<BeakColumn> values = [id, question, answer, category];
}

/// A FAQ fixture model.
final class FaqModel extends BeakModel {
  /// Creates the model.
  const FaqModel();

  @override
  String get table => 'faqs';

  @override
  String get displayColumnKey => 'question';

  @override
  List<BeakColumn> get columns => FaqColumns.values;
}
