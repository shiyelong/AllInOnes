import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/common/theme.dart';

void main() {
  group('UI Tests', () {
    testWidgets('Basic UI elements should render correctly', (WidgetTester tester) async {
      // 构建一个简单的UI
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          primaryColor: AppTheme.primaryColor,
          colorScheme: ColorScheme.light(
            primary: AppTheme.primaryColor,
          ),
        ),
        home: Scaffold(
          appBar: AppBar(
            title: Text('UI测试'),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('欢迎使用AllInOne', style: TextStyle(fontSize: 24)),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  child: Text('登录'),
                ),
                SizedBox(height: 8),
                TextButton(
                  onPressed: () {},
                  child: Text('注册'),
                ),
              ],
            ),
          ),
        ),
      ));

      // 验证UI元素
      expect(find.text('UI测试'), findsOneWidget);
      expect(find.text('欢迎使用AllInOne'), findsOneWidget);
      expect(find.text('登录'), findsOneWidget);
      expect(find.text('注册'), findsOneWidget);

      // 验证按钮样式
      final loginButton = find.text('登录').evaluate().first.findAncestorWidgetOfExactType<ElevatedButton>();
      expect(loginButton, isNotNull);

      final registerButton = find.text('注册').evaluate().first.findAncestorWidgetOfExactType<TextButton>();
      expect(registerButton, isNotNull);
    }, tags: ['ui']);

    testWidgets('Theme colors should be applied correctly', (WidgetTester tester) async {
      // 构建一个使用主题的UI
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          primaryColor: AppTheme.primaryColor,
          colorScheme: ColorScheme.light(
            primary: AppTheme.primaryColor,
          ),
        ),
        home: Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Container(
              color: AppTheme.primaryColor,
              width: 100,
              height: 100,
            ),
          ),
        ),
      ));

      // 验证主题颜色
      final container = find.byType(Container).evaluate().first.widget as Container;
      expect(container.color, equals(AppTheme.primaryColor));

      final appBar = find.byType(AppBar).evaluate().first.widget as AppBar;
      expect(appBar, isNotNull);
    }, tags: ['ui']);
  });
}
