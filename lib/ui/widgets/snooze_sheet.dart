import 'package:flutter/material.dart';
import '../../models/alarm.dart';

class SnoozeSheet extends StatefulWidget {
  final Alarm alarm;
  final List<int> snoozeIntervals;
  final int maxSnoozeCount;
  final ValueChanged<int> onSnooze;
  final VoidCallback onDismiss;

  const SnoozeSheet({
    super.key,
    required this.alarm,
    required this.snoozeIntervals,
    required this.maxSnoozeCount,
    required this.onSnooze,
    required this.onDismiss,
  });

  @override
  State<SnoozeSheet> createState() => _SnoozeSheetState();
}

class _SnoozeSheetState extends State<SnoozeSheet> {
  void _showCustomSnoozeDialog() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => _CustomSnoozeDialog(),
    );

    if (result != null && mounted) {
      widget.onSnooze(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remainingSnoozes = widget.maxSnoozeCount - widget.alarm.snoozeCount;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.alarm.time12Formatted,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.alarm.label != null && widget.alarm.label!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.alarm.label!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 24),
          if (remainingSnoozes > 0) ...[
            Text(
              'Snooze ($remainingSnoozes remaining)',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: widget.snoozeIntervals.map((minutes) {
                return _SnoozeButton(
                  minutes: minutes,
                  onPressed: () => widget.onSnooze(minutes),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _showCustomSnoozeDialog,
              icon: const Icon(Icons.schedule),
              label: const Text('Custom'),
            ),
            const SizedBox(height: 8),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                'No snoozes remaining',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          FilledButton.icon(
            onPressed: widget.onDismiss,
            icon: const Icon(Icons.alarm_off),
            label: const Text('Dismiss'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SnoozeButton extends StatelessWidget {
  final int minutes;
  final VoidCallback onPressed;

  const _SnoozeButton({
    required this.minutes,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: Text('$minutes min'),
    );
  }
}

class _CustomSnoozeDialog extends StatefulWidget {
  @override
  State<_CustomSnoozeDialog> createState() => _CustomSnoozeDialogState();
}

class _CustomSnoozeDialogState extends State<_CustomSnoozeDialog> {
  final _controller = TextEditingController(text: '10');
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom Snooze'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Minutes',
            hintText: 'Enter minutes',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a value';
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
          child: const Text('Snooze'),
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
