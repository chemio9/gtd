import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtd/app.dart';
import 'package:gtd/core/date_x.dart';
import 'package:gtd/data/database.dart';
import 'package:gtd/providers.dart';

/// Subject grouping and batch actions in the Todos tab.
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

  /// Unmounts the app so drift's deferred stream-close timers can run.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> openTodos(WidgetTester tester) async {
    await tester.tap(find.text('Todos').last);
    await tester.pumpAndSettle();
  }

  Finder header(int? tagId) =>
      find.byKey(ValueKey('todo-group-${tagId ?? 'none'}'));

  Future<Task?> task(String title) async {
    final all = await db.select(db.tasks).get();
    return all.where((t) => t.title == title).firstOrNull;
  }

  /// Seeds one task per subject plus an uncategorized one.
  Future<({int math, int physics, int algebra, int optics, int milk})>
  seedSubjects() async {
    final board = await db.boardDao.firstBoard();
    final math = await db.tagDao.create('Math', color: 0xFF4F46E5);
    final physics = await db.tagDao.create('Physics', color: 0xFF10B981);
    final algebra = await db.taskDao.createTask(
      title: 'Algebra set',
      boardId: board!.id,
    );
    final optics = await db.taskDao.createTask(
      title: 'Optics lab',
      boardId: board.id,
    );
    final milk = await db.taskDao.createTask(
      title: 'Buy milk',
      boardId: board.id,
    );
    await db.tagDao.attach(algebra, math);
    await db.tagDao.attach(optics, physics);
    return (
      math: math,
      physics: physics,
      algebra: algebra,
      optics: optics,
      milk: milk,
    );
  }

  testWidgets('groups tasks by subject and keeps uncategorized last', (
    tester,
  ) async {
    final ids = await seedSubjects();
    await pumpApp(tester);
    await openTodos(tester);

    expect(header(ids.math), findsOneWidget);
    expect(header(ids.physics), findsOneWidget);
    expect(header(null), findsOneWidget);

    // Alphabetical subjects before the uncategorized bucket.
    final mathY = tester.getTopLeft(header(ids.math)).dy;
    final physicsY = tester.getTopLeft(header(ids.physics)).dy;
    final noneY = tester.getTopLeft(header(null)).dy;
    expect(mathY, lessThan(physicsY));
    expect(physicsY, lessThan(noneY));

    await disposeApp(tester);
  });

  testWidgets('a task with two subjects shows up under both', (tester) async {
    final board = await db.boardDao.firstBoard();
    final math = await db.tagDao.create('Math');
    final physics = await db.tagDao.create('Physics');
    final id = await db.taskDao.createTask(
      title: 'Lab report',
      boardId: board!.id,
    );
    await db.tagDao.attach(id, math);
    await db.tagDao.attach(id, physics);

    await pumpApp(tester);
    await openTodos(tester);

    expect(find.text('Lab report'), findsNWidgets(2));
    await disposeApp(tester);
  });

  testWidgets('tapping a subject header collapses its tasks', (tester) async {
    final ids = await seedSubjects();
    await pumpApp(tester);
    await openTodos(tester);

    expect(find.text('Algebra set'), findsOneWidget);

    await tester.tap(header(ids.math));
    await tester.pumpAndSettle();
    expect(find.text('Algebra set'), findsNothing);
    // The header itself stays so the group can be reopened.
    expect(header(ids.math), findsOneWidget);

    await tester.tap(header(ids.math));
    await tester.pumpAndSettle();
    expect(find.text('Algebra set'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('long pressing a header filters to that subject', (tester) async {
    final ids = await seedSubjects();
    await pumpApp(tester);
    await openTodos(tester);

    await tester.longPress(header(ids.math));
    await tester.pumpAndSettle();

    expect(header(ids.math), findsOneWidget);
    expect(header(ids.physics), findsNothing);
    expect(find.text('Optics lab'), findsNothing);
    expect(find.text('Buy milk'), findsNothing);

    await tester.tap(find.text('Show all subjects'));
    await tester.pumpAndSettle();
    expect(header(ids.physics), findsOneWidget);
    expect(find.text('Buy milk'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('switches between subject and due-date grouping', (tester) async {
    await seedSubjects();
    await pumpApp(tester);
    await openTodos(tester);

    await tester.tap(find.byTooltip('Group by due date'));
    await tester.pumpAndSettle();

    // No due dates yet, so everything lands in ANYTIME.
    expect(find.text('ANYTIME'), findsOneWidget);
    expect(find.text('UNCATEGORIZED'), findsNothing);

    await tester.tap(find.byTooltip('Group by subject'));
    await tester.pumpAndSettle();
    expect(find.text('Uncategorized'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('batch selection sets the same due date on many tasks', (
    tester,
  ) async {
    await seedSubjects();
    await pumpApp(tester);
    await openTodos(tester);

    await tester.longPress(find.text('Algebra set'));
    await tester.pumpAndSettle();
    expect(find.text('1 task selected'), findsOneWidget);

    await tester.tap(find.text('Optics lab'));
    await tester.pumpAndSettle();
    expect(find.text('2 tasks selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Tomorrow'));
    await tester.pumpAndSettle();

    final tomorrow = dateOnly(DateTime.now()).add(const Duration(days: 1));
    expect(dateOnly((await task('Algebra set'))!.dueDate!), tomorrow);
    expect(dateOnly((await task('Optics lab'))!.dueDate!), tomorrow);
    // Selection mode ended and the untouched task kept its date.
    expect(await task('Buy milk'), isNotNull);
    expect((await task('Buy milk'))!.dueDate, isNull);
    expect(find.text('Updated 2 tasks'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('batch complete moves every selected task to the done column', (
    tester,
  ) async {
    final ids = await seedSubjects();
    await pumpApp(tester);
    await openTodos(tester);

    await tester.longPress(find.text('Algebra set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Optics lab'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Complete'));
    await tester.pumpAndSettle();

    final board = await db.boardDao.firstBoard();
    final done = (await db.boardDao.columnsOf(
      board!.id,
    )).firstWhere((column) => column.isDone);
    for (final id in [ids.algebra, ids.optics]) {
      final row = (await db.select(db.tasks).get()).firstWhere(
        (t) => t.id == id,
      );
      expect(row.completedAt, isNotNull);
      expect(row.columnId, done.id);
    }
    expect((await task('Buy milk'))!.completedAt, isNull);

    await disposeApp(tester);
  });

  testWidgets('batch delete asks for confirmation first', (tester) async {
    await seedSubjects();
    await pumpApp(tester);
    await openTodos(tester);

    await tester.longPress(find.text('Algebra set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Optics lab'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    // Cancelling keeps both rows.
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(await task('Algebra set'), isNotNull);
    expect(await task('Optics lab'), isNotNull);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await task('Algebra set'), isNull);
    expect(await task('Optics lab'), isNull);
    expect(await task('Buy milk'), isNotNull);

    await disposeApp(tester);
  });

  testWidgets('batch tagging attaches one tag to every selected task', (
    tester,
  ) async {
    await seedSubjects();
    await pumpApp(tester);
    await openTodos(tester);

    await tester.longPress(find.text('Algebra set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy milk'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add tags'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CheckboxListTile),
        matching: find.text('Physics'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final physics = (await db.select(db.tags).get()).firstWhere(
      (t) => t.name == 'Physics',
    );
    final links = await db.select(db.taskTags).get();
    expect(links.where((l) => l.tagId == physics.id), hasLength(3));

    await disposeApp(tester);
  });
}
