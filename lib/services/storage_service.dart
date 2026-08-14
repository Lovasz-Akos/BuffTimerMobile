import 'package:shared_preferences/shared_preferences.dart';
import '../models/buff_timer_state.dart';

class StorageService {
  static const String _keyExpiryTimestamp = 'ff14_buff_expiry_timestamp';
  static const String _keyMarginMinutes = 'ff14_buff_margin_minutes';
  static const String _keyIsActive = 'ff14_buff_is_active';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  BuffTimerState loadState() {
    final expiryMillis = _prefs.getInt(_keyExpiryTimestamp);
    final marginMinutes = _prefs.getInt(_keyMarginMinutes) ?? 30;
    final isActive = _prefs.getBool(_keyIsActive) ?? false;

    DateTime? expiryTime;
    if (expiryMillis != null) {
      expiryTime = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
    }

    return BuffTimerState(
      expiryTime: expiryTime,
      marginMinutes: marginMinutes,
      isActive: isActive,
    );
  }

  Future<void> saveState(BuffTimerState state) async {
    if (state.expiryTime != null) {
      await _prefs.setInt(_keyExpiryTimestamp, state.expiryTime!.millisecondsSinceEpoch);
    } else {
      await _prefs.remove(_keyExpiryTimestamp);
    }
    await _prefs.setInt(_keyMarginMinutes, state.marginMinutes);
    await _prefs.setBool(_keyIsActive, state.isActive);
  }

  Future<void> clearTimer() async {
    await _prefs.remove(_keyExpiryTimestamp);
    await _prefs.setBool(_keyIsActive, false);
  }
}
