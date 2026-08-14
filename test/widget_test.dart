// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buff_timer_mobile/main.dart';
import 'package:buff_timer_mobile/services/storage_service.dart';
import 'package:buff_timer_mobile/services/timer_manager.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storageService = StorageService(prefs);
    final timerManager = TimerManager(storageService);

    await tester.pumpWidget(BuffTimerApp(timerManager: timerManager));
    expect(find.text('FF14 FC BUFF TRACKER'), findsOneWidget);
  });
}

