import 'package:flutter/services.dart';

class NativeService {
  static const MethodChannel _channel = MethodChannel('com.ff14.bufftimer/native');

  static Future<void> wakeUpScreen() async {
    try {
      await _channel.invokeMethod('wakeUpScreen');
    } catch (e) {
      // Ignored if platform method fails
    }
  }

  static Future<void> startAlarmSound() async {
    try {
      await _channel.invokeMethod('startAlarmSound');
    } catch (e) {
      // Ignored if platform method fails
    }
  }

  static Future<void> stopAlarmSound() async {
    try {
      await _channel.invokeMethod('stopAlarmSound');
    } catch (e) {
      // Ignored if platform method fails
    }
  }

  static Future<bool> triggerGlyphAlarm() async {
    try {
      final result = await _channel.invokeMethod<bool>('triggerGlyphAlarm');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> stopGlyphAlarm() async {
    try {
      await _channel.invokeMethod('stopGlyphAlarm');
    } catch (e) {
      // Ignored if platform method fails
    }
  }

  static Future<bool> isNothingDevice() async {
    try {
      final result = await _channel.invokeMethod<bool>('isNothingDevice');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      // Ignored if platform method fails
    }
  }
}
