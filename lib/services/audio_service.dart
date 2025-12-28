import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class AudioService {
  Process? _process;
  bool _isPlaying = false;
  String? _cachedAssetPath;
  String? _tempFilePath;
  Timer? _processMonitor;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  bool get isPlaying => _isPlaying && _process != null;

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    developer.log('[$timestamp] AudioService: $message', name: 'Alarmd');
    debugPrint('[$timestamp] AudioService: $message');
  }

  void _verifyProcessState() {
    if (_process == null && _isPlaying) {
      _log('WARNING: Process was null but _isPlaying was true - correcting state');
      _isPlaying = false;
    }
  }

  Future<String> _getAssetFilePath(String assetPath) async {
    if (_tempFilePath != null && _cachedAssetPath == assetPath) {
      final file = File(_tempFilePath!);
      if (await file.exists()) {
        return _tempFilePath!;
      }
    }

    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final fileName = assetPath.split('/').last;
    final tempFile = File('${tempDir.path}/alarmd_$fileName');
    await tempFile.writeAsBytes(byteData.buffer.asUint8List());

    _cachedAssetPath = assetPath;
    _tempFilePath = tempFile.path;
    _log('Asset extracted to: ${tempFile.path}');
    return tempFile.path;
  }

  Future<bool> _checkMpvAvailable() async {
    try {
      final result = await Process.run('which', ['mpv']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<void> _playFallbackBeep() async {
    _log('Playing fallback beep using paplay');
    try {
      // Try system bell/beep as fallback
      // First try paplay with a system sound
      final sounds = [
        '/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga',
        '/usr/share/sounds/gnome/default/alerts/glass.ogg',
        '/usr/share/sounds/ubuntu/stereo/bell.ogg',
      ];

      for (final sound in sounds) {
        if (await File(sound).exists()) {
          _process = await Process.start('paplay', ['--volume=65536', sound]);
          _isPlaying = true;
          _log('Fallback: playing $sound');

          // Loop the fallback sound
          _process!.exitCode.then((_) {
            if (_isPlaying) {
              _playFallbackBeep();
            }
          });
          return;
        }
      }

      // Last resort: terminal bell (may not work in all environments)
      _log('No system sounds found, trying terminal bell');
      await Process.run('bash', ['-c', 'echo -e "\\a"']);
    } catch (e) {
      _log('Fallback beep failed: $e');
    }
  }

  Future<void> playAlarm(String assetPath, {double volume = 1.0}) async {
    _verifyProcessState();
    _retryCount = 0;

    // Kill any existing process before starting new one
    await _stopProcess();

    await _attemptPlayAlarm(assetPath, volume: volume);
  }

  Future<void> _attemptPlayAlarm(String assetPath, {double volume = 1.0}) async {
    _log('Attempting to play alarm: $assetPath (attempt ${_retryCount + 1}/$_maxRetries)');

    // Check if mpv is available
    if (!await _checkMpvAvailable()) {
      _log('ERROR: mpv is not installed!');
      await _playFallbackBeep();
      return;
    }

    try {
      final filePath = await _getAssetFilePath(assetPath);
      final mpvVolume = (volume * 100).round();

      _log('Starting mpv with volume: $mpvVolume');

      _process = await Process.start('mpv', [
        '--ao=pulse',
        '--no-video',
        '--loop=inf',
        '--volume=$mpvVolume',
        '--af=lavfi=[loudnorm=i=-10]',
        '--no-terminal',
        filePath,
      ]);

      _isPlaying = true;
      _log('mpv process started with PID: ${_process!.pid}');

      // Monitor the process for unexpected exits
      _startProcessMonitor(assetPath, volume);

      // Also listen for process exit
      _process!.exitCode.then((exitCode) {
        if (_isPlaying) {
          _log('WARNING: mpv process exited unexpectedly with code $exitCode');
          _handleProcessCrash(assetPath, volume);
        }
      });

      // Give it a moment to start, then verify it's running
      await Future.delayed(const Duration(milliseconds: 500));
      if (_process != null) {
        try {
          // Check if process is still alive
          Process.killPid(_process!.pid, ProcessSignal.sigcont);
          _log('mpv process verified running');
        } catch (e) {
          _log('WARNING: mpv process may have died immediately');
          await _handleProcessCrash(assetPath, volume);
        }
      }
    } catch (e) {
      _log('ERROR: Failed to start mpv: $e');
      _isPlaying = false;
      await _handleProcessCrash(assetPath, volume);
    }
  }

  void _startProcessMonitor(String assetPath, double volume) {
    _processMonitor?.cancel();
    _processMonitor = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isPlaying) {
        _processMonitor?.cancel();
        return;
      }

      if (_process == null) {
        _log('WARNING: Process monitor detected null process while isPlaying=true');
        _handleProcessCrash(assetPath, volume);
      }
    });
  }

  Future<void> _handleProcessCrash(String assetPath, double volume) async {
    _retryCount++;
    if (_retryCount < _maxRetries && _isPlaying) {
      _log('Retrying alarm playback... (attempt ${_retryCount + 1}/$_maxRetries)');
      await Future.delayed(const Duration(milliseconds: 500));
      await _attemptPlayAlarm(assetPath, volume: volume);
    } else if (_isPlaying) {
      _log('Max retries reached, falling back to system beep');
      await _playFallbackBeep();
    }
  }

  Future<void> _stopProcess() async {
    _processMonitor?.cancel();
    _processMonitor = null;

    if (_process != null) {
      _log('Stopping mpv process (PID: ${_process!.pid})');
      _process!.kill();
      _process = null;
    }
    _isPlaying = false;
  }

  Future<void> stop() async {
    _log('Stop requested');
    await _stopProcess();
  }

  Future<void> setVolume(double volume) async {
    // Cannot change volume on running mpv process without IPC
    _log('setVolume called but not supported without IPC');
  }

  void dispose() {
    _log('Disposing AudioService');
    _processMonitor?.cancel();
    _process?.kill();
    if (_tempFilePath != null) {
      try {
        File(_tempFilePath!).deleteSync();
      } catch (_) {}
    }
  }
}
