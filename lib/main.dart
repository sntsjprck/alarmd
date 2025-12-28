import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:media_kit/media_kit.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'providers/alarm_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/active_alarm_provider.dart';
import 'services/desktop_integration_service.dart';
import 'services/tray_service.dart';
import 'ui/screens/home_screen.dart';

Future<void> _cleanupOrphanedMpvProcesses() async {
  try {
    await Process.run('pkill', ['-f', 'mpv.*alarmd']);
  } catch (_) {}
}

late TrayService _trayService;
late ProviderContainer _container;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _cleanupOrphanedMpvProcesses();

  // Initialize MediaKit for audio playback on Linux
  MediaKit.ensureInitialized();
  JustAudioMediaKit.ensureInitialized();

  // Initialize window manager for desktop
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(400, 600));
  await windowManager.setTitle('Alarmd');
  await windowManager.setPreventClose(true);

  // Initialize notification service
  // Use 'ignore' shortcut policy to avoid "ready" notification on startup
  await localNotifier.setup(
    appName: 'Alarmd',
    shortcutPolicy: ShortcutPolicy.ignore,
  );

  // Create provider container to initialize services
  _container = ProviderContainer();

  // Initialize storage service
  await _container.read(storageServiceProvider).init();

  // Initialize settings
  await _container.read(settingsProvider.notifier).init();

  // Tray service will be initialized after app starts
  _trayService = TrayService();

  // Auto-create desktop entry on first run (AppImage only, release mode only)
  await DesktopIntegrationService.autoIntegrateOnFirstRun();

  runApp(
    UncontrolledProviderScope(
      container: _container,
      child: const AlarmdApp(),
    ),
  );
}

class AlarmdApp extends ConsumerStatefulWidget {
  const AlarmdApp({super.key});

  @override
  ConsumerState<AlarmdApp> createState() => _AlarmdAppState();
}

class _AlarmdAppState extends ConsumerState<AlarmdApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initTray();
  }

  Future<void> _initTray() async {
    await _trayService.init();
    _setupTrayCallbacks();
  }

  void _setupTrayCallbacks() {
    _trayService.onShowWindow = _showWindow;
    _trayService.onExit = _handleExit;
  }

  Future<void> _showWindow() async {
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.show();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.focus();
    await windowManager.setAlwaysOnTop(false);
  }

  Future<void> _handleExit() async {
    await _trayService.destroy();
    await windowManager.destroy();
    exit(0);
  }

  @override
  void onWindowClose() async {
    final settings = ref.read(settingsProvider);

    if (settings.minimizeToTray) {
      // Hide window instead of closing
      await windowManager.hide();
    } else {
      // Actually close the app
      await _handleExit();
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to alarm ringing state and update tray tooltip
    ref.listen<ActiveAlarmState>(activeAlarmProvider, (previous, next) {
      _trayService.setRingingState(next.isRinging);
    });

    return MaterialApp(
      title: 'Alarmd',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
