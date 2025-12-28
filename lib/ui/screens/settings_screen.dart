import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/desktop_integration_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Process? _process;
  String? _playingSound;
  String? _tempFilePath;

  @override
  void dispose() {
    _process?.kill();
    _cleanupTempFile();
    super.dispose();
  }

  void _cleanupTempFile() {
    if (_tempFilePath != null) {
      try {
        File(_tempFilePath!).deleteSync();
      } catch (_) {}
    }
  }

  Future<String> _getAssetFilePath(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final fileName = assetPath.split('/').last;
    final tempFile = File('${tempDir.path}/alarmd_preview_$fileName');
    await tempFile.writeAsBytes(byteData.buffer.asUint8List());
    _tempFilePath = tempFile.path;
    return tempFile.path;
  }

  Future<void> _playSound(String soundAsset) async {
    if (_playingSound == soundAsset) {
      await _stopSound();
      return;
    }

    _process?.kill();
    setState(() => _playingSound = soundAsset);

    try {
      final volume = ref.read(settingsProvider).volume;
      final filePath = await _getAssetFilePath(soundAsset);
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
    } catch (e) {
      if (mounted) {
        setState(() => _playingSound = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play sound: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _stopSound() async {
    _process?.kill();
    _process = null;
    if (mounted) {
      setState(() => _playingSound = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Snooze Options',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Max snooze count'),
                      DropdownButton<int>(
                        value: settings.maxSnoozeCount,
                        items: [1, 2, 3, 4, 5, 10]
                            .map((v) => DropdownMenuItem(
                                  value: v,
                                  child: Text('$v'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            ref
                                .read(settingsProvider.notifier)
                                .setMaxSnoozeCount(value);
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  const Text('Snooze intervals (minutes)'),
                  const SizedBox(height: 8),
                  _SnoozeIntervalsEditor(
                    intervals: settings.snoozeIntervals,
                    onChanged: (intervals) {
                      ref
                          .read(settingsProvider.notifier)
                          .setSnoozeIntervals(intervals);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Alarm Sound',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: settings.availableSounds.map((sound) {
                final isSelected = settings.defaultSoundAsset == sound;
                final isPlaying = _playingSound == sound;
                return ListTile(
                  title: Text(settings.getSoundName(sound)),
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? theme.colorScheme.primary : null,
                  ),
                  trailing: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isPlaying
                        ? IconButton(
                            key: const ValueKey('stop'),
                            icon: Icon(Icons.stop, color: theme.colorScheme.error),
                            onPressed: _stopSound,
                            tooltip: 'Stop',
                          )
                        : IconButton(
                            key: const ValueKey('play'),
                            icon: const Icon(Icons.play_arrow),
                            onPressed: () => _playSound(sound),
                            tooltip: 'Preview',
                          ),
                  ),
                  onTap: () {
                    ref.read(settingsProvider.notifier).setDefaultSound(sound);
                    _playSound(sound);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Volume',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.volume_down),
                  Expanded(
                    child: Slider(
                      value: settings.volume.clamp(0.1, 1.25),
                      min: 0.1,
                      max: 1.25,
                      divisions: 23,
                      label: '${(settings.volume.clamp(0.1, 1.25) * 100).round()}%',
                      onChanged: (value) {
                        ref.read(settingsProvider.notifier).setVolume(value);
                      },
                    ),
                  ),
                  const Icon(Icons.volume_up),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 45,
                    child: Text(
                      '${(settings.volume * 100).round()}%',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Desktop Integration',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _DesktopIntegrationSection(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Window Behavior',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Minimize to tray on close'),
              subtitle: const Text('App continues running when window is closed'),
              value: settings.minimizeToTray,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).setMinimizeToTray(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SnoozeIntervalsEditor extends StatefulWidget {
  final List<int> intervals;
  final ValueChanged<List<int>> onChanged;

  const _SnoozeIntervalsEditor({
    required this.intervals,
    required this.onChanged,
  });

  @override
  State<_SnoozeIntervalsEditor> createState() => _SnoozeIntervalsEditorState();
}

class _SnoozeIntervalsEditorState extends State<_SnoozeIntervalsEditor> {
  late List<int> _intervals;

  @override
  void initState() {
    super.initState();
    _intervals = List.from(widget.intervals);
  }

  @override
  void didUpdateWidget(_SnoozeIntervalsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.intervals != oldWidget.intervals) {
      _intervals = List.from(widget.intervals);
    }
  }

  void _addInterval() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => _IntervalDialog(),
    );
    if (result != null && !_intervals.contains(result)) {
      setState(() {
        _intervals.add(result);
        _intervals.sort();
      });
      widget.onChanged(_intervals);
    }
  }

  void _removeInterval(int interval) {
    if (_intervals.length <= 1) return;
    setState(() {
      _intervals.remove(interval);
    });
    widget.onChanged(_intervals);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._intervals.map((interval) => Chip(
              label: Text('$interval min'),
              onDeleted: _intervals.length > 1
                  ? () => _removeInterval(interval)
                  : null,
            )),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: const Text('Add'),
          onPressed: _addInterval,
        ),
      ],
    );
  }
}

class _IntervalDialog extends StatefulWidget {
  @override
  State<_IntervalDialog> createState() => _IntervalDialogState();
}

class _IntervalDialogState extends State<_IntervalDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Snooze Interval'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Minutes',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Enter a value';
            }
            final num = int.tryParse(value);
            if (num == null || num < 1 || num > 60) {
              return 'Enter 1-60 minutes';
            }
            return null;
          },
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(int.parse(_controller.text));
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _DesktopIntegrationSection extends StatefulWidget {
  @override
  State<_DesktopIntegrationSection> createState() => _DesktopIntegrationSectionState();
}

class _DesktopIntegrationSectionState extends State<_DesktopIntegrationSection> {
  String _status = 'Checking...';
  bool _isInstalled = false;
  bool _canIntegrate = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final status = await DesktopIntegrationService.getStatusMessage();
    final installed = await DesktopIntegrationService.isDesktopEntryInstalled();
    final canIntegrate = DesktopIntegrationService.canIntegrate;

    if (mounted) {
      setState(() {
        _status = status;
        _isInstalled = installed;
        _canIntegrate = canIntegrate;
      });
    }
  }

  Future<void> _createEntry() async {
    setState(() => _isLoading = true);

    final success = await DesktopIntegrationService.createDesktopEntry();

    if (mounted) {
      setState(() => _isLoading = false);
      await _checkStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Desktop entry created successfully'
              : 'Failed to create desktop entry'),
        ),
      );
    }
  }

  Future<void> _removeEntry() async {
    setState(() => _isLoading = true);

    final success = await DesktopIntegrationService.removeDesktopEntry();

    if (mounted) {
      setState(() => _isLoading = false);
      await _checkStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Desktop entry removed'
              : 'Failed to remove desktop entry'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _isInstalled ? Icons.check_circle : Icons.info_outline,
              color: _isInstalled ? Colors.green : theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _status,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        if (_canIntegrate) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              if (!_isInstalled)
                FilledButton.icon(
                  onPressed: _isLoading ? null : _createEntry,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('Create Desktop Entry'),
                ),
              if (_isInstalled)
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _removeEntry,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove Desktop Entry'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
