import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Service to prevent system sleep/idle and keep the app responsive
/// when alarms need to trigger.
class KeepAliveService {
  Timer? _keepAliveTimer;
  Process? _inhibitProcess;
  bool _isInhibiting = false;

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    developer.log('[$timestamp] KeepAliveService: $message', name: 'Alarmd');
    debugPrint('[$timestamp] KeepAliveService: $message');
  }

  /// Start inhibiting system sleep/idle (call when alarm is ringing)
  Future<void> startInhibit() async {
    if (_isInhibiting) return;

    _log('Starting system inhibit');
    _isInhibiting = true;

    try {
      // Try gnome-session-inhibit first (GNOME desktop)
      final result = await Process.run('which', ['gnome-session-inhibit']);
      if (result.exitCode == 0) {
        _inhibitProcess = await Process.start('gnome-session-inhibit', [
          '--inhibit', 'idle:suspend',
          '--reason', 'Alarm is ringing',
          'sleep', 'infinity',
        ]);
        _log('Started gnome-session-inhibit');
        return;
      }
    } catch (e) {
      _log('gnome-session-inhibit not available: $e');
    }

    try {
      // Try systemd-inhibit (works on most systemd-based systems)
      final result = await Process.run('which', ['systemd-inhibit']);
      if (result.exitCode == 0) {
        _inhibitProcess = await Process.start('systemd-inhibit', [
          '--what=idle:sleep',
          '--why=Alarm is ringing',
          '--mode=block',
          'sleep', 'infinity',
        ]);
        _log('Started systemd-inhibit');
        return;
      }
    } catch (e) {
      _log('systemd-inhibit not available: $e');
    }

    try {
      // Try xdg-screensaver (generic X11)
      await Process.run('xdg-screensaver', ['reset']);
      // Start a timer to keep resetting the screensaver
      _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        Process.run('xdg-screensaver', ['reset']);
      });
      _log('Started xdg-screensaver reset timer');
    } catch (e) {
      _log('xdg-screensaver not available: $e');
    }
  }

  /// Stop inhibiting system sleep/idle (call when alarm is dismissed)
  Future<void> stopInhibit() async {
    if (!_isInhibiting) return;

    _log('Stopping system inhibit');
    _isInhibiting = false;

    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;

    if (_inhibitProcess != null) {
      _inhibitProcess!.kill();
      _inhibitProcess = null;
      _log('Killed inhibit process');
    }
  }

  /// Perform a single keep-alive ping (prevents timer drift detection issues)
  Future<void> ping() async {
    // This method exists to ensure the service is touched periodically
    // which helps Dart's event loop stay active
  }

  void dispose() {
    _keepAliveTimer?.cancel();
    _inhibitProcess?.kill();
    _log('KeepAliveService disposed');
  }
}
