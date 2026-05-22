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
}
