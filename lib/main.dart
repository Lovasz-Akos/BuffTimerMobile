import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/timer_manager.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize persistent storage and notification engine
  final storageService = await StorageService.init();
  await NotificationService.init();

  final timerManager = TimerManager(storageService);

  runApp(BuffTimerApp(timerManager: timerManager));
}

class BuffTimerApp extends StatelessWidget {
  final TimerManager timerManager;

  const BuffTimerApp({super.key, required this.timerManager});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FF14 FC Buff Timer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1F6FEB),
          secondary: Color(0xFFFFD700),
          surface: Color(0xFF161B22),
        ),
      ),
      home: HomeScreen(timerManager: timerManager),
    );
  }
}
