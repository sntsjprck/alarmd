import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class AudioService {
  Process? _process;
  bool _isPlaying = false;
  String? _cachedAssetPath;
  String? _tempFilePath;

  bool get isPlaying => _isPlaying && _process != null;

  void _verifyProcessState() {
    if (_process == null && _isPlaying) {
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
    return tempFile.path;
  }

  Future<void> playAlarm(String assetPath, {double volume = 1.0}) async {
    _verifyProcessState();

    // Kill any existing process before starting new one
    if (_process != null) {
      _process!.kill();
      _process = null;
      _isPlaying = false;
    }

    try {
      final filePath = await _getAssetFilePath(assetPath);
      final mpvVolume = (volume * 100).round();

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
    } catch (e) {
      _isPlaying = false;
      rethrow;
    }
  }

  Future<void> stop() async {
    _process?.kill();
    _process = null;
    _isPlaying = false;
  }

  Future<void> setVolume(double volume) async {
    // Cannot change volume on running mpv process without IPC
  }

  void dispose() {
    _process?.kill();
    if (_tempFilePath != null) {
      try {
        File(_tempFilePath!).deleteSync();
      } catch (_) {}
    }
  }
}
