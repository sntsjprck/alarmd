import 'dart:io';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/services.dart' show rootBundle;

class DesktopIntegrationService {
  static const _desktopFileName = 'alarmd.desktop';
  static const _iconFileName = 'alarmd.png';

  /// Check if running from an AppImage
  static bool get isAppImage {
    return Platform.environment.containsKey('APPIMAGE');
  }

  /// Get the AppImage path
  static String? get appImagePath {
    return Platform.environment['APPIMAGE'];
  }

  /// Get the desktop entry path
  static String get _desktopEntryPath {
    final home = Platform.environment['HOME'] ?? '/home';
    return '$home/.local/share/applications/$_desktopFileName';
  }

  /// Get the icon path
  static String get _iconPath {
    final home = Platform.environment['HOME'] ?? '/home';
    return '$home/.local/share/icons/hicolor/256x256/apps/$_iconFileName';
  }

  /// Check if desktop entry already exists
  static Future<bool> isDesktopEntryInstalled() async {
    return File(_desktopEntryPath).exists();
  }

  /// Check if desktop integration is available (AppImage + release mode)
  static bool get canIntegrate {
    return isAppImage && kReleaseMode;
  }

  /// Create desktop entry and install icon
  /// Returns true if successful, false otherwise
  static Future<bool> createDesktopEntry() async {
    if (!canIntegrate) {
      return false;
    }

    final appImage = appImagePath;
    if (appImage == null) {
      return false;
    }

    try {
      // Create directories if they don't exist
      final home = Platform.environment['HOME'] ?? '/home';
      await Directory('$home/.local/share/applications').create(recursive: true);
      await Directory('$home/.local/share/icons/hicolor/256x256/apps').create(recursive: true);

      // Extract and save icon
      final iconData = await rootBundle.load('assets/icon/app_icon.png');
      final iconFile = File(_iconPath);
      await iconFile.writeAsBytes(iconData.buffer.asUint8List());

      // Create desktop entry
      // StartupWMClass must match the APPLICATION_ID in linux/CMakeLists.txt
      // for notifications to display the correct app name
      final desktopContent = '''[Desktop Entry]
Name=Alarmd
Comment=Simple alarm clock application
Exec="$appImage"
Icon=$_iconPath
Type=Application
Categories=Utility;Clock;
Terminal=false
StartupNotify=true
StartupWMClass=com.rcksnts.alarmd
''';

      final desktopFile = File(_desktopEntryPath);
      await desktopFile.writeAsString(desktopContent);

      // Update desktop database (optional, may fail silently)
      try {
        await Process.run('update-desktop-database', [
          '$home/.local/share/applications',
        ]);
      } catch (_) {}

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove desktop entry and icon
  static Future<bool> removeDesktopEntry() async {
    try {
      final desktopFile = File(_desktopEntryPath);
      final iconFile = File(_iconPath);

      if (await desktopFile.exists()) {
        await desktopFile.delete();
      }
      if (await iconFile.exists()) {
        await iconFile.delete();
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get installation status message
  static Future<String> getStatusMessage() async {
    if (!kReleaseMode) {
      return 'Only available in release mode';
    }
    if (!isAppImage) {
      return 'Only available when running from AppImage';
    }
    if (await isDesktopEntryInstalled()) {
      return 'Desktop entry installed';
    }
    return 'Desktop entry not installed';
  }

  /// Auto-integrate on first run (call from main.dart)
  static Future<void> autoIntegrateOnFirstRun() async {
    if (!canIntegrate) return;

    final alreadyInstalled = await isDesktopEntryInstalled();
    if (!alreadyInstalled) {
      await createDesktopEntry();
    }
  }
}
