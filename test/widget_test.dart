import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crushie/screens/auth/landing_screen.dart';

void main() {
  testWidgets('Crushie landing screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LandingScreen(
          onGetStarted: () {},
          onSignIn: () {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Crushie title is present on landing screen
    expect(find.text('Crushie'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
