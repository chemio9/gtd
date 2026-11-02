import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtd/ui/kanban/kanban_board_view.dart';

void main() {
  final columns = [
    const KanbanColumn<String>(id: 'todo', title: 'To do', items: ['a', 'b']),
    const KanbanColumn<String>(id: 'done', title: 'Done', items: []),
  ];

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders every column and its items', (tester) async {
    await tester.pumpWidget(
      wrap(
        KanbanBoardView<String>(
          columns: columns,
          itemBuilder: (context, item, isDragging) => Text(item),
          onMove: (_) {},
        ),
      ),
    );

    expect(find.text('To do'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('Drop tasks here'), findsOneWidget);
  });

  testWidgets('tapping a card reports the item', (tester) async {
    String? tapped;
    await tester.pumpWidget(
      wrap(
        KanbanBoardView<String>(
          columns: columns,
          itemBuilder: (context, item, isDragging) => Text(item),
          onItemTap: (item) => tapped = item,
          onMove: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('a'));
    await tester.pump();
    expect(tapped, 'a');
  });

  testWidgets('add button reports its column', (tester) async {
    KanbanColumn<String>? added;
    await tester.pumpWidget(
      wrap(
        KanbanBoardView<String>(
          columns: columns,
          itemBuilder: (context, item, isDragging) => Text(item),
          onAddItem: (column) => added = column,
          onMove: (_) {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('Add task').first);
    await tester.pump();
    expect(added?.id, 'todo');
  });
}
