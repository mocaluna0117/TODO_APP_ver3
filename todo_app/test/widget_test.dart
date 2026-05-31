import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo_app/main.dart';

void main() {
  testWidgets('Todo add sheet saves the optional description', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('TODO'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('概要を入力（任意）'), findsOneWidget);
    expect(find.text('画像を添付（任意）'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '買い物');
    await tester.enterText(find.byType(TextField).at(1), '牛乳とパンを買う');
    await tester.tap(find.text('追加'));
    await tester.pumpAndSettle();

    expect(find.text('買い物'), findsOneWidget);
    expect(find.text('牛乳とパンを買う'), findsOneWidget);
  });

  testWidgets('Completed tab can delete all visible completed tasks', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'todo_items': jsonEncode([
        {
          'id': 1,
          'title': '完了したタスク',
          'description': null,
          'isDone': true,
          'category': 'todo',
          'taskTag': null,
          'dueDate': null,
          'recurrenceRule': 'none',
          'imageBase64List': <String>[],
          'priority': 'none',
        },
      ]),
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('完了済み'));
    await tester.pumpAndSettle();

    expect(find.text('完了したタスク'), findsOneWidget);
    expect(find.byIcon(Icons.delete_sweep_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();
    expect(find.text('完了済みを全削除'), findsOneWidget);

    await tester.tap(find.text('全削除'));
    await tester.pumpAndSettle();

    expect(find.text('完了したタスク'), findsNothing);
    expect(find.text('完了済みのタスクはありません'), findsOneWidget);
  });
}
