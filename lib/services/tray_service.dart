import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayService with TrayListener {
  bool _isInitialized = false;
  bool _isRinging = false;
  String? _iconPath;

  VoidCallback? onShowWindow;
  VoidCallback? onExit;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _iconPath = await _extractAsset('assets/icon/app_icon.png', 'tray_icon.png');

      await trayManager.setIcon(_iconPath!);

      // setToolTip is not supported on Linux
      if (!Platform.isLinux) {
        await trayManager.setToolTip('Alarmd');
      }

      trayManager.addListener(this);
      await _updateContextMenu();

      _isInitialized = true;
    } catch (_) {}
  }

  Future<String> _extractAsset(String assetPath, String fileName) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/alarmd_$fileName');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file.path;
  }

  Future<void> _updateContextMenu() async {
    final menu = Menu(
      items: [
        MenuItem(
          key: 'show_window',
          label: 'Show Alarmd',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit',
          label: 'Exit',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  Future<void> setRingingState(bool isRinging) async {
    if (!_isInitialized || _isRinging == isRinging) return;

    _isRinging = isRinging;

    // setToolTip is not supported on Linux
    if (Platform.isLinux) return;

    try {
      if (isRinging) {
        await trayManager.setToolTip('Alarmd - ALARM RINGING!');
      } else {
        await trayManager.setToolTip('Alarmd');
      }
    } catch (_) {}
  }

  @override
  void onTrayIconMouseDown() {
    onShowWindow?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        onShowWindow?.call();
        break;
      case 'exit':
        onExit?.call();
        break;
    }
  }

  Future<void> destroy() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
    _isInitialized = false;
  }
}
