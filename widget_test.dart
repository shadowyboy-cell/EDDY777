import 'package:flutter_test/flutter_test.dart';
import 'package:ism_almizania/main.dart';

void main() {
  testWidgets('app starts', (tester) async {
    await tester.pumpWidget(const BudgetApp());
    expect(find.text('اسم الميزانية'), findsOneWidget);
  });
}
