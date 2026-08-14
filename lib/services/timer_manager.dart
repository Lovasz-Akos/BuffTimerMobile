import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/buff_timer_state.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import 'native_service.dart';

class TimerManager extends ChangeNotifier {
  final StorageService _storageService;

  BuffTimerState _state = const BuffTimerState();
  Timer? _ticker;
  bool _isAlarmRinging = false;
  bool _hasTriggeredForCurrentCycle = false;

  TimerManager(this._storageService) {
    _loadInitialState();
  }

  BuffTimerState get state => _state;
  bool get isAlarmRinging => _isAlarmRinging;

  void _loadInitialState() {
    _state = _storageService.loadState();
    if (_state.isActive && !_state.isExpired) {
      _startTicker();
    } else if (_state.isExpired && _state.isActive) {
      _state = _state.copyWith(isActive: false, clearExpiry: true);
      _storageService.saveState(_state);
    }
    notifyListeners();
  }

  /// Start a brand new 24-hour FC Buff Timer
  Future<void> start24HourTimer() async {
    final now = DateTime.now();
    final expiryTime = now.add(const Duration(hours: 24));

    _state = _state.copyWith(
      expiryTime: expiryTime,
      isActive: true,
    );

    _hasTriggeredForCurrentCycle = false;
    _isAlarmRinging = false;
    await NativeService.stopAlarmSound();
    await NativeService.stopGlyphAlarm();

    await _storageService.saveState(_state);

    // Schedule system exact alarm
    final alarmTime = _state.alarmTime;
    if (alarmTime != null) {
      await NotificationService.scheduleAlarmNotification(
        scheduledTime: alarmTime,
        title: '⚠️ FF14 FC BUFF EXPIRING SOON!',
        body: 'Your Free Company buffs expire in ${_state.marginMinutes} minutes! Tap to refresh.',
      );
    }

    _startTicker();
    notifyListeners();
  }

  /// Update Pre-Alarm Margin (5, 15, 30, 60 minutes)
  Future<void> setMarginMinutes(int margin) async {
    _state = _state.copyWith(marginMinutes: margin);
    await _storageService.saveState(_state);

    if (_state.isActive && !_state.isExpired) {
      final alarmTime = _state.alarmTime;
      if (alarmTime != null) {
        await NotificationService.scheduleAlarmNotification(
          scheduledTime: alarmTime,
          title: '⚠️ FF14 FC BUFF EXPIRING SOON!',
          body: 'Your Free Company buffs expire in ${_state.marginMinutes} minutes! Tap to refresh.',
        );
      }
    }

    notifyListeners();
  }

  /// Reset/Stop active timer
  Future<void> cancelTimer() async {
    _ticker?.cancel();
    _ticker = null;

    _state = _state.copyWith(isActive: false, clearExpiry: true);
    _hasTriggeredForCurrentCycle = false;
    await dismissAlarm();

    await NotificationService.cancelAlarmNotification();
    await _storageService.clearTimer();

    notifyListeners();
  }

  /// Trigger a 5-second quick test alarm to verify sound, screen wakeup & Nothing Glyph
  Future<void> triggerTestAlarm() async {
    await NativeService.wakeUpScreen();
    await NativeService.startAlarmSound();
    await NativeService.triggerGlyphAlarm();

    await NotificationService.showInstantAlarmNotification(
      title: '🔔 TEST ALARM - FF14 FC Buff Tracker',
      body: 'Testing alarm sound, screen wake lock & Nothing Glyph LEDs.',
    );

    _isAlarmRinging = true;
    notifyListeners();
  }

  /// Dismiss active ringing alarm
  Future<void> dismissAlarm() async {
    _isAlarmRinging = false;
    await NativeService.stopAlarmSound();
    await NativeService.stopGlyphAlarm();
    await NotificationService.cancelAlarmNotification();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state.expiryTime == null || !_state.isActive) {
        timer.cancel();
        return;
      }

      if (_state.isExpired) {
        timer.cancel();
        _state = _state.copyWith(isActive: false, clearExpiry: true);
        _storageService.saveState(_state);
        dismissAlarm();
      } else if (_state.isAlarmDue && !_hasTriggeredForCurrentCycle) {
        _hasTriggeredForCurrentCycle = true;
        _isAlarmRinging = true;
        
        // Trigger screen wake, audio, and glyph LEDs
        NativeService.wakeUpScreen();
        NativeService.startAlarmSound();
        NativeService.triggerGlyphAlarm();
        
        NotificationService.showInstantAlarmNotification(
          title: '⚠️ FF14 FC BUFF EXPIRING SOON!',
          body: 'Your Free Company buffs expire in ${_state.marginMinutes} minutes! Tap to refresh.',
        );
      }

      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
