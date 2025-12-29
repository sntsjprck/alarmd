import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/alarm.dart';
import '../../providers/alarm_provider.dart';
import '../../providers/active_alarm_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/alarm_tile.dart';
import '../widgets/snooze_sheet.dart';
import '../dialogs/create_alarm_dialog.dart';
import '../dialogs/custom_time_dialog.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await ref.read(alarmListProvider.notifier).loadAlarms();
    final alarms = ref.read(alarmListProvider);
    ref.read(activeAlarmProvider.notifier).startScheduler(alarms);
  }

  void _showCreateDialog() async {
    final result = await showDialog<CreateAlarmResult>(
      context: context,
      builder: (context) => const CreateAlarmDialog(),
    );

    if (result != null && mounted) {
      final settings = ref.read(settingsProvider);
      await ref.read(alarmListProvider.notifier).addMultipleAlarms(
            times: result.times,
            label: result.label,
            soundAsset: settings.defaultSoundAsset,
          );
      await ref.read(activeAlarmProvider.notifier).updateSchedulerAlarms(
            ref.read(alarmListProvider),
          );
    }
  }

  void _showEditDialog(Alarm alarm) async {
    final result = await showDialog<CustomTimeResult>(
      context: context,
      builder: (context) => CustomTimeDialog(
        initialTime: TimeOfDay(hour: alarm.hour, minute: alarm.minute),
        initialLabel: alarm.label,
        title: 'Edit Alarm',
      ),
    );

    if (result != null && mounted) {
      final updatedAlarm = alarm.copyWith(
        hour: result.hour,
        minute: result.minute,
        label: result.label,
      );
      await ref.read(alarmListProvider.notifier).updateAlarm(updatedAlarm);
    }
  }

  void _showSnoozeSheet(ActiveAlarmState activeState) {
    if (activeState.currentAlarm == null) return;

    final settings = ref.read(settingsProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SnoozeSheet(
        alarm: activeState.currentAlarm!,
        snoozeIntervals: settings.snoozeIntervals,
        maxSnoozeCount: settings.maxSnoozeCount,
        onSnooze: (minutes) {
          ref.read(activeAlarmProvider.notifier).snooze(minutes);
          Navigator.of(context).pop();
        },
        onDismiss: () {
          ref.read(activeAlarmProvider.notifier).dismiss();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alarms = ref.watch(alarmListProvider);
    final activeState = ref.watch(activeAlarmProvider);
    final theme = Theme.of(context);

    ref.listen(alarmListProvider, (previous, next) {
      ref.read(activeAlarmProvider.notifier).updateSchedulerAlarms(next);
    });

    ref.listen(activeAlarmProvider, (previous, next) {
      if (next.isRinging && (previous == null || !previous.isRinging)) {
        _showSnoozeSheet(next);
      }
    });

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (activeState.isRinging)
            IconButton(
              icon: const Icon(Icons.alarm_on),
              onPressed: () => _showSnoozeSheet(activeState),
              tooltip: 'Show ringing alarm',
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: alarms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.alarm_add,
                    size: 80,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No alarms yet',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to create one',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                const minTileWidth = 300.0;
                const spacing = 12.0;
                const padding = 16.0;
                const maxColumns = 3;

                final availableWidth = constraints.maxWidth - (padding * 2);
                final columns = ((availableWidth + spacing) / (minTileWidth + spacing))
                    .floor()
                    .clamp(1, maxColumns);

                return GridView.builder(
                  padding: const EdgeInsets.all(padding),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    mainAxisExtent: 100,
                  ),
                  itemCount: alarms.length,
                  itemBuilder: (context, index) {
                    final alarm = alarms[index];
                    final isRinging =
                        activeState.isRinging && activeState.currentAlarm?.id == alarm.id;

                    return AlarmTile(
                      alarm: alarm,
                      isRinging: isRinging,
                      currentTime: _currentTime,
                      onToggle: (enabled) {
                        ref.read(alarmListProvider.notifier).toggleAlarm(alarm.id, enabled);
                      },
                      onDelete: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Alarm'),
                            content: Text('Delete alarm for ${alarm.time12Formatted}?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          ref.read(alarmListProvider.notifier).deleteAlarm(alarm.id);
                        }
                      },
                      onTap: isRinging
                          ? () => _showSnoozeSheet(activeState)
                          : () => _showEditDialog(alarm),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add_alarm),
        label: const Text('New Alarm'),
      ),
    );
  }
}
