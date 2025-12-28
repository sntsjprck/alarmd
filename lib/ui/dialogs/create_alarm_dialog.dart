import 'package:flutter/material.dart';
import '../widgets/time_grid.dart';

class CreateAlarmResult {
  final List<({int hour, int minute})> times;
  final String? label;

  const CreateAlarmResult({
    required this.times,
    this.label,
  });
}

class CreateAlarmDialog extends StatefulWidget {
  const CreateAlarmDialog({super.key});

  @override
  State<CreateAlarmDialog> createState() => _CreateAlarmDialogState();
}

class _CreateAlarmDialogState extends State<CreateAlarmDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _labelController = TextEditingController();
  Set<TimeSlot> _selectedSlots = {};
  TimeOfDay _customTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _pickCustomTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _customTime,
    );
    if (picked != null) {
      setState(() {
        _customTime = picked;
      });
    }
  }

  void _create() {
    List<({int hour, int minute})> times;

    if (_tabController.index == 0) {
      if (_selectedSlots.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one time')),
        );
        return;
      }
      times = _selectedSlots
          .map((slot) => (hour: slot.hour, minute: slot.minute))
          .toList();
    } else {
      times = [(hour: _customTime.hour, minute: _customTime.minute)];
    }

    final label = _labelController.text.trim();
    Navigator.of(context).pop(CreateAlarmResult(
      times: times,
      label: label.isNotEmpty ? label : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create Alarm',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Quick Select'),
                  Tab(text: 'Custom Time'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    TimeGrid(
                      selectedSlots: _selectedSlots,
                      onSelectionChanged: (slots) {
                        setState(() {
                          _selectedSlots = slots;
                        });
                      },
                    ),
                    _CustomTimeTab(
                      time: _customTime,
                      onPickTime: _pickCustomTime,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Label (optional)',
                  hintText: 'e.g., Wake up, Meeting',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.add_alarm),
                    label: const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _labelController.dispose();
    super.dispose();
  }
}

class _CustomTimeTab extends StatelessWidget {
  final TimeOfDay time;
  final VoidCallback onPickTime;

  const _CustomTimeTab({
    required this.time,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$hour:$minute $period',
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onPickTime,
            icon: const Icon(Icons.access_time),
            label: const Text('Change Time'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
