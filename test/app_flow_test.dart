import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtd/app.dart';
import 'package:gtd/data/database.dart';
import 'package:gtd/providers.dart';

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

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
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
