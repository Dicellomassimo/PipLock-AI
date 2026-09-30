// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:piplock_ai/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });
  testWidgets('PipLock app smoke test', (WidgetTester tester) async {
    // PipLockApp owns its ProviderScope; wrapping it here creates a duplicate
    // scope and makes the smoke assertion fail without testing app behavior.
    await tester.pumpWidget(const PipLockApp());
    await tester.pump();
    // Let the splash timeout complete so the test leaves no pending timers.
    await tester.pump(const Duration(seconds: 8));
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
