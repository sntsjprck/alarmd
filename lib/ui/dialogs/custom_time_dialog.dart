import 'package:flutter/material.dart';

class CustomTimeResult {
  final int hour;
  final int minute;
  final String? label;

  const CustomTimeResult({
    required this.hour,
    required this.minute,
    this.label,
  });
}

class CustomTimeDialog extends StatefulWidget {
  final TimeOfDay? initialTime;
  final String? initialLabel;
  final String title;

  const CustomTimeDialog({
    super.key,
    this.initialTime,
    this.initialLabel,
    this.title = 'Set Time',
  });

  @override
  State<CustomTimeDialog> createState() => _CustomTimeDialogState();
}

class _CustomTimeDialogState extends State<CustomTimeDialog> {
  late TimeOfDay _time;
  late TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    _time = widget.initialTime ?? TimeOfDay.now();
    _labelController = TextEditingController(text: widget.initialLabel ?? '');
  }

  void _pickTimeAndSave() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null && mounted) {
      final label = _labelController.text.trim();
      Navigator.of(context).pop(CustomTimeResult(
        hour: picked.hour,
        minute: picked.minute,
        label: label.isNotEmpty ? label : null,
      ));
    }
  }

  void _saveWithCurrentTime() {
    final label = _labelController.text.trim();
    Navigator.of(context).pop(CustomTimeResult(
      hour: _time.hour,
      minute: _time.minute,
      label: label.isNotEmpty ? label : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final period = _time.hour >= 12 ? 'PM' : 'AM';
    final hour = _time.hour % 12 == 0 ? 12 : _time.hour % 12;
    final minute = _time.minute.toString().padLeft(2, '0');

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _pickTimeAndSave,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$hour:$minute $period',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to change time and save',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Label (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveWithCurrentTime,
          child: const Text('Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }
}
