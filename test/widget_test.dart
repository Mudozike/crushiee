import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:crushie/main.dart';
import 'package:crushie/providers/auth_provider.dart';
import 'package:crushie/providers/post_provider.dart';
import 'package:crushie/providers/connection_provider.dart';
import 'package:crushie/providers/chat_provider.dart';
import 'package:crushie/providers/theme_provider.dart';
import 'package:crushie/providers/notification_provider.dart';

void main() {
  testWidgets('Crushie app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => PostProvider()),
          ChangeNotifierProvider(create: (_) => ConnectionProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ],
        child: const CrushieApp(),
      ),
    );

    // Verify Crushie title is present on landing screen
    expect(find.text('Crushie'), findsOneWidget);
  });
}
