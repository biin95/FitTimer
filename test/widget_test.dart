import 'package:flutter_test/flutter_test.dart';
import 'package:fittimer/main.dart';

void main() {
  testWidgets('App 应该启动并显示主页', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // 验证 App 标题存在
    expect(find.text('FitTimer'), findsOneWidget);
  });
}
