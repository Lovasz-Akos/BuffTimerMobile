class BuffTimerState {
  final DateTime? expiryTime;
  final int marginMinutes;
  final bool isActive;

  const BuffTimerState({
    this.expiryTime,
    this.marginMinutes = 30,
    this.isActive = false,
  });

  /// Calculate the pre-alarm trigger timestamp (Expiry minus Margin)
  DateTime? get alarmTime {
    if (expiryTime == null) return null;
    return expiryTime!.subtract(Duration(minutes: marginMinutes));
  }

  /// Time left until the pre-alarm fires
  Duration get timeUntilAlarm {
    if (alarmTime == null) return Duration.zero;
    final diff = alarmTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Time left until full 24h buff expiry
  Duration get timeUntilExpiry {
    if (expiryTime == null) return Duration.zero;
    final diff = expiryTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Check if the buff is currently expired
  bool get isExpired {
    if (expiryTime == null) return true;
    return DateTime.now().isAfter(expiryTime!);
  }

  /// Check if pre-alarm has been triggered
  bool get isAlarmDue {
    if (alarmTime == null || !isActive) return false;
    final now = DateTime.now();
    return now.isAfter(alarmTime!) && now.isBefore(expiryTime!);
  }

  BuffTimerState copyWith({
    DateTime? expiryTime,
    int? marginMinutes,
    bool? isActive,
    bool clearExpiry = false,
  }) {
    return BuffTimerState(
      expiryTime: clearExpiry ? null : (expiryTime ?? this.expiryTime),
      marginMinutes: marginMinutes ?? this.marginMinutes,
      isActive: isActive ?? this.isActive,
    );
  }
}
