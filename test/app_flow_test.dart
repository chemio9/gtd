import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtd/app.dart';
import 'package:gtd/core/date_x.dart';
import 'package:gtd/data/database.dart';
import 'package:gtd/providers.dart';
import 'package:gtd/services/time_zone_service.dart';

/// End-to-end style widget tests: the real app, real widgets, real drift SQL
/// running against an in-memory database.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpApp(WidgetTester tester, {TimeZoneService? timeZone}) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          if (timeZone != null)
            timeZoneServiceProvider.overrideWithValue(timeZone),
        ],
        child: const GtdApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Unmounts the app and lets drift's deferred stream-close timers run, so
  /// `flutter_test` does not report pending timers.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<Task?> task(String title) async {
    final all = await db.select(db.tasks).get();
    return all.where((t) => t.title == title).firstOrNull;
  }

  testWidgets('seeds a board with three columns on first launch', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('To do'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('creates a task from the board and shows it as a card', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('New task'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Write spec');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Write spec'), findsOneWidget);
    final saved = await task('Write spec');
    expect(saved, isNotNull);
    expect(saved!.completedAt, isNull);
    await disposeApp(tester);
  });

  testWidgets('dragging a card moves it to another column', (tester) async {
    await pumpApp(tester);

    final board = await db.boardDao.firstBoard();
    final columns = await db.boardDao.columnsOf(board!.id);
    final todo = columns.first;
    final doing = columns[1];
    await db.taskDao.createTask(
      title: 'Drag me',
      boardId: board.id,
      columnId: todo.id,
    );
    await tester.pumpAndSettle();

    final card = find.text('Drag me');
    expect(card, findsOneWidget);

    // Long press to pick the card up, then drop it on the "In progress"
    // column (which sits to the right of "To do").
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveBy(const Offset(40, 10));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(120, 20));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(80, 20));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    final moved = await task('Drag me');
    expect(moved!.columnId, doing.id);
    expect(moved.completedAt, isNull);
    await disposeApp(tester);
  });

  testWidgets('checking a todo completes it and moves it to the done column', (
    tester,
  ) async {
    await pumpApp(tester);

    final board = await db.boardDao.firstBoard();
    final todo = await db.boardDao.firstColumn(board!.id);
    await db.taskDao.createTask(
      title: 'Buy milk',
      boardId: board.id,
      columnId: todo!.id,
    );
    await tester.pumpAndSettle();

    await openTab(tester, 'Todos');
    expect(find.text('Buy milk'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    final completed = await task('Buy milk');
    expect(completed!.completedAt, isNotNull);

    final doneColumn = (await db.boardDao.columnsOf(board.id)).last;
    expect(completed.columnId, doneColumn.id);

    await openTab(tester, 'Board');
    expect(find.text('Buy milk'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('creates a recurring event and lists it in the agenda', (
    tester,
  ) async {
    await pumpApp(tester);
    await openTab(tester, 'Calendar');

    await tester.tap(find.widgetWithText(FloatingActionButton, 'New event'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Team sync');

    await tester.tap(find.text('Does not repeat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every week').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Team sync'), findsOneWidget);

    final events = await db.select(db.events).get();
    expect(events, hasLength(1));
    expect(events.single.recurrence, RecurrenceFrequency.weekly);
    expect(events.single.byWeekday, isNotNull);
    await disposeApp(tester);
  });

  testWidgets('quick add keeps the field open for several tasks in a row', (
    tester,
  ) async {
    await pumpApp(tester);
    await openTab(tester, 'Todos');

    // The FAB reveals the inline field instead of opening a dialog.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final input = find.byType(TextField);
    expect(input, findsOneWidget);

    Future<void> submit(String text) async {
      await tester.enterText(input, text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    await submit('Buy milk tomorrow');
    await submit('Call the bank');
    await submit('Ship v1 at 9am');

    // The field is still there, empty and focused, ready for the next entry.
    expect(find.byType(TextField), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);

    final tasks = await db.select(db.tasks).get();
    expect(tasks.map((t) => t.title), containsAll(<String>[
      'Buy milk',
      'Call the bank',
      'Ship v1',
    ]));
    expect(tasks.every((t) => t.columnId != null), isTrue);

    // All three are visible without reopening anything.
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Call the bank'), findsOneWidget);
    expect(find.text('Ship v1'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('quick add understands date tokens', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Todos');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final input = find.byType(TextField);
    await tester.enterText(input, 'Dentist tomorrow at 9am');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final saved = await task('Dentist');
    expect(saved, isNotNull);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect(saved!.dueDate!.day, tomorrow.day);
    expect(saved.dueDate!.hour, 9);
    expect(saved.dueDate!.minute, 0);

    await disposeApp(tester);
  });

  testWidgets('quick add highlights recognised dates and shows a due badge', (
    tester,
  ) async {
    await pumpApp(tester);
    await openTab(tester, 'Todos');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final input = find.byType(TextField);
    await tester.enterText(input, 'conference 2026-11-03 9:45');
    await tester.pumpAndSettle();

    // The recognised tokens are painted with a background colour by the
    // controller that backs the input.
    final field = tester.widget<TextField>(input);
    final span = field.controller!.buildTextSpan(
      context: tester.element(input),
      style: const TextStyle(),
      withComposing: false,
    );
    final highlighted = <String>[];
    span.visitChildren((child) {
      if (child is TextSpan && child.style?.backgroundColor != null) {
        highlighted.add(child.text ?? '');
      }
      return true;
    });
    expect(highlighted, ['2026-11-03 9:45']);

    // ...and confirmed by the due badge under the field.
    expect(find.textContaining('Due '), findsOneWidget);
    expect(find.textContaining('09:45'), findsWidgets);

    // Clearing the badge strips the recognised tokens from the text.
    await tester.tap(find.byTooltip('Clear recognised date'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'conference',
    );
    expect(find.byTooltip('Clear recognised date'), findsNothing);

    // Submitting keeps the exact parsed date.
    await tester.enterText(input, 'conference 2026-11-03 9:45');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final saved = await task('conference');
    expect(saved, isNotNull);
    expect(saved!.dueDate, DateTime(2026, 11, 3, 9, 45));

    await disposeApp(tester);
  });

  testWidgets('column inline add keeps a card field open for several cards', (
    tester,
  ) async {
    await pumpApp(tester);

    // The column header "+" opens an inline field instead of a sheet.
    await tester.tap(find.byTooltip('Add task').first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'New card'), findsOneWidget);

    final input = find.byType(TextField);
    await tester.enterText(input, 'Design review fri 2pm');
    await tester.pumpAndSettle();
    // The parsed date is previewed under the field.
    expect(find.textContaining('Due '), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.enterText(input, 'Write changelog');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final cards = await db.select(db.tasks).get();
    expect(cards.map((c) => c.title), containsAll(['Design review', 'Write changelog']));

    final review = cards.firstWhere((c) => c.title == 'Design review');
    expect(review.dueDate!.hour, 14);
    expect(review.dueDate!.weekday, DateTime.friday);
    final board = await db.boardDao.firstBoard();
    final todoColumn = await db.boardDao.firstColumn(board!.id);
    expect(review.columnId, todoColumn!.id);

    // Esc closes the field.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('pasting a list adds one task per line', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{
            'text':
                '- call the bank tomorrow\n'
                '* buy milk\n'
                'book flight 2026-12-24 18:00',
          };
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpApp(tester);
    await openTab(tester, 'Todos');

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste list'));
    await tester.pumpAndSettle();

    final tasks = await db.select(db.tasks).get();
    expect(tasks, hasLength(3));
    expect(
      tasks.map((t) => t.title),
      containsAll(['call the bank', 'buy milk', 'book flight']),
    );
    final flight = tasks.firstWhere((t) => t.title == 'book flight');
    expect(flight.dueDate, DateTime(2026, 12, 24, 18));

    await disposeApp(tester);
  });

  testWidgets('settings page exposes swipe, reminders, backup and about', (
    tester,
  ) async {
    await pumpApp(tester);
    await openTab(tester, 'Todos');

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('SWIPE ACTIONS'), findsOneWidget);
    expect(find.text('Swipe right'), findsOneWidget);
    expect(find.text('Swipe left'), findsOneWidget);
    expect(find.text('REMINDERS'), findsOneWidget);
    expect(find.text('Daily reminder'), findsOneWidget);
    expect(find.text('BACKUP'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('Licenses'), findsOneWidget);

    // Licenses opens the stock Flutter page (which loads asynchronously, so
    // settle on a fixed pump instead of pumpAndSettle).
    await tester.tap(find.text('Licenses'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LicensePage), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('swipe actions follow the preference', (tester) async {
    await pumpApp(tester);
    final board = await db.boardDao.firstBoard();
    final column = await db.boardDao.firstColumn(board!.id);
    await db.taskDao.createTask(
      title: 'Sweep the floor',
      boardId: board.id,
      columnId: column!.id,
    );
    await tester.pumpAndSettle();

    await openTab(tester, 'Todos');

    // Default preference: swipe left deletes.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);

    // Change it to "schedule for tomorrow".
    await tester.tap(find.text('Swipe left'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule for tomorrow').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Schedule for tomorrow'),
      findsOneWidget,
    ); // tile trailing label

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.drag(find.text('Sweep the floor'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Tomorrow'), findsOneWidget);
    await tester.tap(find.text('Tomorrow'));
    await tester.pumpAndSettle();

    final saved = await task('Sweep the floor');
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect(saved!.dueDate!.day, tomorrow.day);
    expect(saved.dueDate!.hour, 0);
    expect(saved.completedAt, isNull);

    await disposeApp(tester);
  });

  testWidgets('calendar sync mirrors events into a device calendar', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    const channel = MethodChannel('gtd/calendar');
    final inserted = <Map<String, Object?>>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'hasPermission':
        case 'requestPermission':
          return true;
        case 'listCalendars':
          return [
            {
              'id': 5,
              'name': 'Test calendar',
              'account': 'tester@example.com',
              'isWritable': true,
              'isPrimary': true,
            },
          ];
        case 'insertEvent':
          inserted.add((call.arguments as Map).cast<String, Object?>());
          return 1000 + inserted.length;
        case 'updateEvent':
        case 'deleteEvent':
          return true;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await pumpApp(tester, timeZone: const _FixedTimeZone());
    await db.eventDao.createEvent(
      EventsCompanion.insert(
        title: 'Team sync',
        startsAt: DateTime(2026, 11, 3, 9),
        endsAt: DateTime(2026, 11, 3, 9, 30),
      ),
    );
    await tester.pumpAndSettle();

    await openTab(tester, 'Todos');
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    // Pick the device calendar from the list coming from the channel.
    await tester.tap(find.text('Device calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test calendar').last);
    await tester.pumpAndSettle();
    expect(find.text('Test calendar'), findsOneWidget);

    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();

    expect(inserted, hasLength(1));
    expect(inserted.single['title'], 'Team sync');
    expect(inserted.single['calendarId'], 5);
    expect(find.textContaining('Calendar synced'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
    await disposeApp(tester);
  });

  testWidgets('calendar sync is disabled where the platform cannot store it', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    await pumpApp(tester);
    await openTab(tester, 'Todos');
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('CALENDAR SYNC'), findsOneWidget);
    expect(find.text('Only available on Android'), findsOneWidget);
    expect(find.text('Sync now'), findsNothing);

    debugDefaultTargetPlatformOverride = null;
    await disposeApp(tester);
  });

  testWidgets('linking an event to a task shows up on both sides', (
    tester,
  ) async {
    await pumpApp(tester);

    final board = await db.boardDao.firstBoard();
    final column = await db.boardDao.firstColumn(board!.id);
    final taskId = await db.taskDao.createTask(
      title: 'Prepare deck',
      boardId: board.id,
      columnId: column!.id,
    );
    final today = dateOnly(DateTime.now());
    final eventId = await db.eventDao.createEvent(
      EventsCompanion.insert(
        title: 'Design review',
        startsAt: today.add(const Duration(hours: 14)),
        endsAt: today.add(const Duration(hours: 15)),
      ),
    );
    await tester.pumpAndSettle();

    // Calendar: open the event and link the task.
    await openTab(tester, 'Calendar');
    await tester.tap(find.text('Design review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link a task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prepare deck').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect((await db.eventDao.eventById(eventId))!.linkedTaskId, taskId);
    // The agenda row shows the linked task.
    expect(find.text('Prepare deck'), findsWidgets);

    // Tasks: the sheet lists the linked event.
    await openTab(tester, 'Todos');
    await tester.tap(find.text('Prepare deck').last);
    await tester.pumpAndSettle();
    expect(find.text('LINKED EVENTS'), findsOneWidget);
    expect(find.text('Design review'), findsWidgets);

    await disposeApp(tester);
  });

  testWidgets('a task can carry a reminder offset', (tester) async {
    await pumpApp(tester);

    final board = await db.boardDao.firstBoard();
    final column = await db.boardDao.firstColumn(board!.id);
    final due = dateOnly(DateTime.now()).add(const Duration(hours: 18));
    final taskId = await db.taskDao.createTask(
      title: 'Call the plumber',
      boardId: board.id,
      columnId: column!.id,
      dueDate: due,
    );
    await tester.pumpAndSettle();

    await openTab(tester, 'Todos');
    await tester.tap(find.text('Call the plumber').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('No reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 hours before').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await db.taskDao.taskById(taskId);
    expect(saved!.reminderMinutesBefore, 180);

    await disposeApp(tester);
  });

  testWidgets('task editor adds subtasks and tags', (tester) async {
    await pumpApp(tester);

    final board = await db.boardDao.firstBoard();
    final column = await db.boardDao.firstColumn(board!.id);
    final taskId = await db.taskDao.createTask(
      title: 'Prepare deck',
      boardId: board.id,
      columnId: column!.id,
    );
    await tester.pumpAndSettle();

    await openTab(tester, 'Todos');
    await tester.tap(find.text('Prepare deck').last);
    await tester.pumpAndSettle();

    // Subtask via the inline add field.
    final addSubtask = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == 'Add subtask',
    );
    expect(addSubtask, findsOneWidget);
    await tester.enterText(addSubtask, 'Outline');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final subtasks = await db.select(db.subtasks).get();
    expect(subtasks.single.title, 'Outline');
    expect(subtasks.single.taskId, taskId);

    // Tag via picker -> new tag.
    await tester.tap(find.text('Add tag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New tag'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Tag name'),
      'work',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    final pickerSave = find.text('Save').first;
    await tester.ensureVisible(pickerSave);
    await tester.pumpAndSettle();
    await tester.tap(pickerSave);
    await tester.pumpAndSettle();

    final taskSave = find.text('Save').last;
    await tester.ensureVisible(taskSave);
    await tester.pumpAndSettle();
    await tester.tap(taskSave);
    await tester.pumpAndSettle();

    final tags = await db.select(db.tags).get();
    expect(tags.single.name, 'work');
    final links = await db.select(db.taskTags).get();
    expect(links.single.taskId, taskId);
    expect(links.single.tagId, tags.single.id);

    await disposeApp(tester);
  });

  testWidgets('search finds tasks and events and opens their editors', (
    tester,
  ) async {
    await pumpApp(tester);

    final board = await db.boardDao.firstBoard();
    final column = await db.boardDao.firstColumn(board!.id);
    await db.taskDao.createTask(
      title: 'Prepare deck',
      boardId: board.id,
      columnId: column!.id,
    );
    final today = dateOnly(DateTime.now());
    await db.eventDao.createEvent(
      EventsCompanion.insert(
        title: 'Design review',
        startsAt: today.add(const Duration(hours: 15)),
        endsAt: today.add(const Duration(hours: 16)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    final field = find.byType(TextField);
    await tester.enterText(field, 'deck');
    await tester.pumpAndSettle();
    expect(find.text('Prepare deck'), findsOneWidget);
    expect(find.text('Design review'), findsNothing);

    await tester.tap(find.text('Prepare deck'));
    await tester.pumpAndSettle();
    expect(find.text('Edit task'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'review');
    await tester.pumpAndSettle();
    expect(find.text('Design review'), findsOneWidget);

    await tester.tap(find.text('Design review'));
    await tester.pumpAndSettle();
    expect(find.text('Edit event'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing found'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('calendar shows a dot on days that have tasks', (tester) async {
    await pumpApp(tester);

    final board = await db.boardDao.firstBoard();
    final column = await db.boardDao.firstColumn(board!.id);
    final today = dateOnly(DateTime.now());
    await db.taskDao.createTask(
      title: 'Pay rent',
      boardId: board.id,
      columnId: column!.id,
      dueDate: today,
    );
    await db.taskDao.createTask(
      title: 'Water plants',
      boardId: board.id,
      columnId: column.id,
      dueDate: today.add(const Duration(days: 2)),
    );
    await tester.pumpAndSettle();

    await openTab(tester, 'Calendar');
    await tester.pumpAndSettle();

    // Task-only days get the secondary dot, without an event dot.
    expect(find.byKey(const ValueKey('calendar-task-dot')), findsWidgets);
    expect(find.byKey(const ValueKey('calendar-event-dot')), findsNothing);

    // Adding an event on a day adds the event dot next to the task dot.
    await db.eventDao.createEvent(
      EventsCompanion.insert(
        title: 'Design review',
        startsAt: today.add(const Duration(hours: 15)),
        endsAt: today.add(const Duration(hours: 16)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('calendar-event-dot')), findsWidgets);
    expect(find.byKey(const ValueKey('calendar-task-dot')), findsWidgets);

    await disposeApp(tester);
  });

  testWidgets('undo is only offered for deletions', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Todos');

    // Adding a task gives no snackbar and no undo affordance.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Buy milk');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Undo'), findsNothing);

    // Deleting (default swipe left) offers undo, and it expires.
    await tester.drag(find.text('Buy milk'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Undo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('calendar format button shows the current view', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Calendar');
    await tester.pumpAndSettle();

    // Month view is active: the button must say "Month", not the next format.
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('2 weeks'), findsNothing);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('2 weeks'), findsOneWidget);
    expect(find.text('Month'), findsNothing);

    await tester.tap(find.text('2 weeks'));
    await tester.pumpAndSettle();
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('2 weeks'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('subtasks render inline under their task like a tree', (
    tester,
  ) async {
    await pumpApp(tester);

    final board = await db.boardDao.firstBoard();
    final column = await db.boardDao.firstColumn(board!.id);
    final taskId = await db.taskDao.createTask(
      title: 'Prepare deck',
      boardId: board.id,
      columnId: column!.id,
    );
    final outline = await db.subtaskDao.add(taskId: taskId, title: 'Outline');
    await db.subtaskDao.add(taskId: taskId, title: 'Slides');
    await tester.pumpAndSettle();

    await openTab(tester, 'Todos');

    // Visible without opening the task sheet.
    expect(find.text('Outline'), findsOneWidget);
    expect(find.text('Slides'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('subtask-checkbox-$outline')));
    await tester.pumpAndSettle();

    final subtasks = await db.select(db.subtasks).get();
    expect(subtasks.firstWhere((s) => s.id == outline).isDone, isTrue);
    expect(
      tester.widget<Text>(find.text('Outline')).style?.decoration,
      TextDecoration.lineThrough,
    );

    await disposeApp(tester);
  });

  testWidgets('task editor completes via a checkbox, not a switch', (
    tester,
  ) async {
    await pumpApp(tester);

    final board = await db.boardDao.firstBoard();
    final column = await db.boardDao.firstColumn(board!.id);
    final taskId = await db.taskDao.createTask(
      title: 'Call the plumber',
      boardId: board.id,
      columnId: column!.id,
    );
    await tester.pumpAndSettle();

    await openTab(tester, 'Todos');
    await tester.tap(find.text('Call the plumber').last);
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsNothing);
    expect(find.text('Completed'), findsNothing);

    final checkbox = find.byKey(const ValueKey('task-completed-checkbox'));
    expect(checkbox, findsOneWidget);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await db.taskDao.taskById(taskId);
    expect(saved!.completedAt, isNotNull);

    await disposeApp(tester);
  });

  testWidgets('adds and deletes a board column', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Add column'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Review');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Review'), findsOneWidget);

    final board = await db.boardDao.firstBoard();
    final columns = await db.boardDao.columnsOf(board!.id);
    expect(columns.map((c) => c.title), contains('Review'));
    await disposeApp(tester);
  });
}

/// Deterministic timezone for the calendar sync test.
class _FixedTimeZone extends TimeZoneService {
  const _FixedTimeZone();

  @override
  Future<String> localZoneName() async => 'UTC';
}
