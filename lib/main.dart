import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:media_kit/media_kit.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'providers/alarm_provider.dart';
import 'providers/settings_provider.dart';
import 'ui/screens/home_screen.dart';

Future<void> _cleanupOrphanedMpvProcesses() async {
  try {
    await Process.run('pkill', ['-f', 'mpv.*alarmd']);
  } catch (_) {}
}

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

  // Initialize notification service
  await localNotifier.setup(
    appName: 'Alarmd',
    shortcutPolicy: ShortcutPolicy.requireCreate,
  );

  // Create provider container to initialize services
  final container = ProviderContainer();

  // Initialize storage service
  await container.read(storageServiceProvider).init();

  // Initialize settings
  await container.read(settingsProvider.notifier).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AlarmdApp(),
    ),
  );
}

class AlarmdApp extends StatelessWidget {
  const AlarmdApp({super.key});

  @override
  Widget build(BuildContext context) {
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
