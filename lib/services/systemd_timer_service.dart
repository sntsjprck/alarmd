import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/alarm.dart';

/// Service for integrating with systemd user timers to ensure reliable alarm triggering
/// even when the app is backgrounded or the system sleeps.
///
/// This creates systemd timer units that wake the app at scheduled alarm times,
/// providing OS-level scheduling that survives app suspension.
class SystemdTimerService {
  static const _timerName = 'alarmd';
  static const _serviceUnit = '$_timerName.service';
  static const _timerUnit = '$_timerName.timer';

  bool _isInitialized = false;
  bool _isAvailable = false;

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    developer.log('[$timestamp] SystemdTimerService: $message', name: 'Alarmd');
    debugPrint('[$timestamp] SystemdTimerService: $message');
  }

  String get _configDir {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '~';
    return '$home/.config/systemd/user';
  }

  String get _timerPath => '$_configDir/$_timerUnit';
  String get _servicePath => '$_configDir/$_serviceUnit';

  /// Initialize the service and check if systemd user session is available
  Future<void> init() async {
    if (_isInitialized) return;

    _isAvailable = await _checkAvailability();
    _isInitialized = true;

    if (_isAvailable) {
      _log('Systemd user session available');
    } else {
      _log('Systemd user session not available - timer integration disabled');
    }
  }

  Future<bool> _checkAvailability() async {
    // Only available on Linux
    if (!Platform.isLinux) return false;

    try {
      // Check if systemctl --user works
      final result = await Process.run('systemctl', ['--user', 'status'], runInShell: true);
      // Exit code 0 = running, 3 = no units active but systemd is running
      return result.exitCode == 0 || result.exitCode == 3;
    } catch (e) {
      _log('Failed to check systemd availability: $e');
      return false;
    }
  }

  /// Get the path to use for launching the app
  /// Handles AppImage, installed app, and development scenarios
  String _getExecutablePath() {
    // Check for AppImage environment variable first
    final appImage = Platform.environment['APPIMAGE'];
    if (appImage != null && appImage.isNotEmpty) {
      return appImage;
    }

    // Fall back to resolved executable path
    return Platform.resolvedExecutable;
  }

  /// Sync all alarms to systemd timer
  /// Call this whenever alarms are added, updated, deleted, or toggled
  Future<void> syncAlarms(List<Alarm> alarms) async {
    if (!_isInitialized) await init();
    if (!_isAvailable) return;

    final enabledAlarms = alarms.where((a) => a.enabled).toList();

    if (enabledAlarms.isEmpty) {
      await _disableAndRemoveTimer();
      return;
    }

    try {
      await _ensureConfigDir();
      await _writeServiceFile();
      await _writeTimerFile(enabledAlarms);
      await _reloadAndEnable();
      _log('Synced ${enabledAlarms.length} alarms to systemd timer');
    } catch (e) {
      _log('Failed to sync alarms to systemd timer: $e');
    }
  }

  Future<void> _ensureConfigDir() async {
    final dir = Directory(_configDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      _log('Created systemd user config directory: $_configDir');
    }
  }

  Future<void> _writeServiceFile() async {
    final exePath = _getExecutablePath();

    // The service launches the app with --wake-check flag
    // If the app is already running (single-instance), it will activate the existing instance
    // The app's catch-up mechanism will then trigger any due alarms
    final content = '''[Unit]
Description=Alarmd Alarm Trigger
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=$exePath --wake-check
Environment=DISPLAY=:0
# Give the app time to start and trigger alarms
TimeoutStartSec=30
''';

    await File(_servicePath).writeAsString(content);
    _log('Wrote service file: $_servicePath');
  }

  Future<void> _writeTimerFile(List<Alarm> alarms) async {
    final buffer = StringBuffer();
    buffer.writeln('[Unit]');
    buffer.writeln('Description=Alarmd Scheduled Alarms');
    buffer.writeln();
    buffer.writeln('[Timer]');

    // Add OnCalendar entry for each enabled alarm
    // Format: *-*-* HH:MM:00 (daily at specified time)
    for (final alarm in alarms) {
      final hour = alarm.hour.toString().padLeft(2, '0');
      final minute = alarm.minute.toString().padLeft(2, '0');
      buffer.writeln('OnCalendar=*-*-* $hour:$minute:00');
    }

    // Persistent=true: If system was off during scheduled time,
    // the timer fires immediately when system comes back up
    buffer.writeln('Persistent=true');

    // High accuracy for alarm timing
    buffer.writeln('AccuracySec=1s');

    buffer.writeln();
    buffer.writeln('[Install]');
    buffer.writeln('WantedBy=timers.target');

    await File(_timerPath).writeAsString(buffer.toString());
    _log('Wrote timer file with ${alarms.length} alarms: $_timerPath');
  }

  Future<void> _reloadAndEnable() async {
    // Reload systemd to pick up changes
    var result = await Process.run(
      'systemctl',
      ['--user', 'daemon-reload'],
      runInShell: true,
    );
    if (result.exitCode != 0) {
      _log('Warning: daemon-reload failed: ${result.stderr}');
    }

    // Enable and start the timer
    result = await Process.run(
      'systemctl',
      ['--user', 'enable', '--now', _timerUnit],
      runInShell: true,
    );
    if (result.exitCode != 0) {
      _log('Warning: enable timer failed: ${result.stderr}');
    } else {
      _log('Timer enabled and started');
    }
  }

  Future<void> _disableAndRemoveTimer() async {
    try {
      // Stop and disable the timer
      await Process.run(
        'systemctl',
        ['--user', 'disable', '--now', _timerUnit],
        runInShell: true,
      );

      // Remove the files
      final timerFile = File(_timerPath);
      final serviceFile = File(_servicePath);

      if (await timerFile.exists()) {
        await timerFile.delete();
        _log('Removed timer file');
      }
      if (await serviceFile.exists()) {
        await serviceFile.delete();
        _log('Removed service file');
      }

      // Reload systemd
      await Process.run(
        'systemctl',
        ['--user', 'daemon-reload'],
        runInShell: true,
      );

      _log('Timer disabled and removed (no enabled alarms)');
    } catch (e) {
      _log('Error during timer cleanup: $e');
    }
  }

  /// Schedule a one-time wake for snooze
  /// Uses systemd-run for one-shot timer
  Future<void> scheduleSnoozeWake(DateTime snoozeTime) async {
    if (!_isInitialized) await init();
    if (!_isAvailable) return;

    try {
      final exePath = _getExecutablePath();

      // Calculate delay in seconds
      final now = DateTime.now();
      final delaySeconds = snoozeTime.difference(now).inSeconds;

      if (delaySeconds <= 0) {
        _log('Snooze time is in the past, skipping systemd schedule');
        return;
      }

      // Use systemd-run to create a transient timer
      final result = await Process.run(
        'systemd-run',
        [
          '--user',
          '--on-active=${delaySeconds}s',
          '--timer-property=AccuracySec=1s',
          exePath,
          '--wake-check',
        ],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        _log('Scheduled snooze wake in $delaySeconds seconds');
      } else {
        _log('Failed to schedule snooze wake: ${result.stderr}');
      }
    } catch (e) {
      _log('Error scheduling snooze wake: $e');
    }
  }

  /// Check the current timer status
  Future<String?> getTimerStatus() async {
    if (!_isInitialized) await init();
    if (!_isAvailable) return null;

    try {
      final result = await Process.run(
        'systemctl',
        ['--user', 'status', _timerUnit],
        runInShell: true,
      );
      return result.stdout as String;
    } catch (e) {
      return null;
    }
  }

  /// Get next scheduled trigger time
  Future<DateTime?> getNextTriggerTime() async {
    if (!_isInitialized) await init();
    if (!_isAvailable) return null;

    try {
      final result = await Process.run(
        'systemctl',
        ['--user', 'show', _timerUnit, '--property=NextElapseUSecRealtime'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final output = (result.stdout as String).trim();
        // Format: NextElapseUSecRealtime=<microseconds since epoch>
        final match = RegExp(r'NextElapseUSecRealtime=(\d+)').firstMatch(output);
        if (match != null) {
          final microseconds = int.tryParse(match.group(1)!);
          if (microseconds != null && microseconds > 0) {
            return DateTime.fromMicrosecondsSinceEpoch(microseconds);
          }
        }
      }
    } catch (e) {
      _log('Error getting next trigger time: $e');
    }
    return null;
  }
}
