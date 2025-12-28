import 'package:flutter/material.dart';
import '../../models/alarm.dart';

class AlarmTile extends StatelessWidget {
  final Alarm alarm;
  final bool isRinging;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final DateTime currentTime;

  const AlarmTile({
    super.key,
    required this.alarm,
    required this.isRinging,
    required this.onToggle,
    required this.onDelete,
    required this.currentTime,
    this.onTap,
  });

  String _getTimeUntilAlarm() {
    if (!alarm.enabled) return '';

    final now = currentTime;
    var alarmDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      alarm.hour,
      alarm.minute,
    );

    // If alarm time has passed today, it's for tomorrow
    if (alarmDateTime.isBefore(now) || alarmDateTime.isAtSameMomentAs(now)) {
      alarmDateTime = alarmDateTime.add(const Duration(days: 1));
    }

    final difference = alarmDateTime.difference(now);
    final totalMinutes = difference.inMinutes;

    if (totalMinutes < 1) {
      return 'Less than a minute';
    } else if (totalMinutes < 60) {
      return '$totalMinutes min';
    } else {
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      if (minutes == 0) {
        return '$hours hr';
      }
      return '$hours hr $minutes min';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isRinging
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: isRinging
            ? Border.all(
                color: theme.colorScheme.error,
                width: 2,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alarm.time12Formatted,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: alarm.enabled
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      if (alarm.enabled)
                        Text(
                          _getTimeUntilAlarm(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      if (alarm.label != null && alarm.label!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            alarm.label!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (alarm.snoozeCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Snoozed ${alarm.snoozeCount}/${alarm.maxSnooze}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.tertiary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: alarm.enabled,
                  onChanged: onToggle,
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: onDelete,
                  tooltip: 'Delete alarm',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
