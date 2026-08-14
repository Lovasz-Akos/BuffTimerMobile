import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/buff_timer_state.dart';
import '../services/timer_manager.dart';
import '../services/native_service.dart';


class HomeScreen extends StatefulWidget {
  final TimerManager timerManager;

  const HomeScreen({super.key, required this.timerManager});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _isNothingDevice = false;
  bool _exactAlarmPermission = true;
  bool _notificationPermission = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _checkDeviceAndPermissions();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    widget.timerManager.addListener(_onTimerStateChanged);
  }

  void _onTimerStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.timerManager.removeListener(_onTimerStateChanged);
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkDeviceAndPermissions() async {
    final isNothing = await NativeService.isNothingDevice();
    final notifStatus = await Permission.notification.status;
    
    // Check exact alarm status on Android 12+
    PermissionStatus alarmStatus = PermissionStatus.granted;
    if (await Permission.scheduleExactAlarm.status.isDenied) {
      alarmStatus = await Permission.scheduleExactAlarm.status;
    }

    if (mounted) {
      setState(() {
        _isNothingDevice = isNothing;
        _notificationPermission = notifStatus.isGranted;
        _exactAlarmPermission = !alarmStatus.isDenied;
      });
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
    await _checkDeviceAndPermissions();
  }

  String _formatDuration(Duration d) {
    if (d <= Duration.zero) return "00:00:00";
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return "--:--";
    return DateFormat('EEE, MMM d • HH:mm:ss').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final manager = widget.timerManager;
    final state = manager.state;
    final isRinging = manager.isAlarmRinging;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_moon_outlined, color: Color(0xFFFFD700), size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'FF14 FC BUFF TRACKER',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          if (_isNothingDevice)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                avatar: const Icon(Icons.light_mode, color: Colors.white, size: 14),
                label: const Text('Glyph API', style: TextStyle(color: Colors.white, fontSize: 11)),
                backgroundColor: const Color(0xFF238636),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Main Primary Button & Circular Timer Display
                  _buildPrimaryTimerButton(manager, state),
                  const SizedBox(height: 24),

                  // Expiry Timeline Details
                  _buildTimelineCard(state),
                  const SizedBox(height: 20),

                  // Pre-Alarm Margin Selector
                  _buildMarginSelectorCard(manager, state),
                  const SizedBox(height: 20),

                  // Android Background Reliability & Permission Actions
                  _buildSystemSettingsCard(manager),
                ],
              ),
            ),
          ),

          // Alarm Ringing Full Screen Overlay
          if (isRinging) _buildAlarmRingingOverlay(manager),
        ],
      ),
    );
  }

  Widget _buildPrimaryTimerButton(TimerManager manager, BuffTimerState state) {
    final isActive = state.isActive && !state.isExpired;
    final remaining = state.timeUntilExpiry;
    final progress = isActive ? remaining.inSeconds / (24 * 3600) : 0.0;


    return Column(
      children: [
        const SizedBox(height: 12),
        Center(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final glowScale = isActive ? (1.0 + _pulseController.value * 0.04) : 1.0;
              return Transform.scale(
                scale: glowScale,
                child: GestureDetector(
                  onTap: () {
                    manager.start24HourTimer();
                  },
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isActive
                            ? [const Color(0xFF1F6FEB), const Color(0xFF238636)]
                            : [const Color(0xFF21262D), const Color(0xFF161B22)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isActive
                              ? const Color(0xFF1F6FEB).withValues(alpha: 0.5)
                              : Colors.black45,
                          blurRadius: isActive ? 24 : 12,
                          spreadRadius: isActive ? 4 : 2,
                        ),
                      ],
                      border: Border.all(
                        color: isActive ? const Color(0xFFFFD700) : const Color(0xFF30363D),
                        width: 4,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isActive)
                          SizedBox(
                            width: 220,
                            height: 220,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 8,
                              backgroundColor: Colors.white10,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                            ),
                          ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isActive ? Icons.bolt : Icons.play_arrow_rounded,
                              size: 44,
                              color: isActive ? const Color(0xFFFFD700) : Colors.white70,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isActive ? 'BUFFS ACTIVE' : 'REFRESH BUFFS',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),

                            const SizedBox(height: 4),
                            Text(
                              isActive ? 'RESTART 24H TIMER' : 'START 24H TIMER',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (isActive)
                              Text(
                                _formatDuration(remaining),
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (isActive) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => manager.cancelTimer(),
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
            label: const Text('Cancel Active Timer', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ],
    );
  }

  Widget _buildTimelineCard(BuffTimerState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.schedule, color: Color(0xFF58A6FF), size: 18),
              SizedBox(width: 8),
              Text(
                'TIMER TIMELINE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF30363D), height: 20),
          _buildTimelineRow(
            icon: Icons.notifications_active,
            iconColor: const Color(0xFFFFD700),
            title: 'Pre-Alarm Alert (${state.marginMinutes}m margin):',
            subtitle: _formatDateTime(state.alarmTime),
            isTriggered: state.isAlarmDue,
          ),
          const SizedBox(height: 12),
          _buildTimelineRow(
            icon: Icons.timer_off,
            iconColor: Colors.redAccent,
            title: '24h Full Expiry Time:',
            subtitle: _formatDateTime(state.expiryTime),
            isTriggered: state.isExpired,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isTriggered,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                subtitle,
                style: TextStyle(
                  color: isTriggered ? Colors.redAccent : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMarginSelectorCard(TimerManager manager, BuffTimerState state) {

    const options = [5, 15, 30, 60];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.alarm, color: Color(0xFF58A6FF), size: 18),
              SizedBox(width: 8),
              Text(
                'PRE-ALARM MARGIN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Select how long before 24h expiry the phone wakes up & alarms:',
            style: TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: options.map((margin) {
              final isSelected = state.marginMinutes == margin;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => manager.setMarginMinutes(margin),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1F6FEB) : const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFFD700) : const Color(0xFF30363D),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        '${margin}m',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemSettingsCard(TimerManager manager) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.shield_sharp, color: Color(0xFF238636), size: 18),
              SizedBox(width: 8),
              Text(
                'ANDROID BACKGROUND PROTECTION',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPermissionRow(
            title: 'Exact Alarms & Notifications',
            isGranted: _notificationPermission && _exactAlarmPermission,
            onTap: _requestPermissions,
          ),
          const SizedBox(height: 8),
          _buildPermissionRow(
            title: 'Ignore Battery Saver Restrictions',
            isGranted: true,
            onTap: () => NativeService.requestIgnoreBatteryOptimizations(),
            actionLabel: 'OPEN SETTINGS',
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => manager.triggerTestAlarm(),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFD700),
                side: const BorderSide(color: Color(0xFFFFD700)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.vibration),
              label: const Text('TEST ALARM SOUND & NOTIFICATIONS'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow({
    required String title,
    required bool isGranted,
    required VoidCallback onTap,
    String actionLabel = 'REQUEST',
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: isGranted ? const Color(0xFF238636) : const Color(0xFFDA3633),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            isGranted ? 'ACTIVE' : actionLabel,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildAlarmRingingOverlay(TimerManager manager) {
    return Container(
      color: Colors.red.shade900.withValues(alpha: 0.95),
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 100, color: Color(0xFFFFD700)),
            const SizedBox(height: 20),
            const Text(
              '⚠️ FF14 FC BUFF EXPIRING SOON!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your Free Company buffs expire in ${manager.state.marginMinutes} minutes!\nLog in to FF14 and refresh your buffs now.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),

            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                manager.dismissAlarm();
                manager.start24HourTimer();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh, size: 28),
              label: const Text(
                'REFRESHED! RESTART 24H TIMER',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => manager.dismissAlarm(),
              icon: const Icon(Icons.close, color: Colors.white),
              label: const Text('DISMISS ALARM', style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
