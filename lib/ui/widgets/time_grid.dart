import 'package:flutter/material.dart';

class TimeSlot {
  final int hour;
  final int minute;

  const TimeSlot(this.hour, this.minute);

  String get formatted {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  String get formatted24 {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  int get totalMinutes => hour * 60 + minute;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeSlot && other.hour == hour && other.minute == minute;
  }

  @override
  int get hashCode => hour.hashCode ^ minute.hashCode;
}

class TimeGrid extends StatefulWidget {
  final Set<TimeSlot> selectedSlots;
  final ValueChanged<Set<TimeSlot>> onSelectionChanged;
  final int columns;

  const TimeGrid({
    super.key,
    required this.selectedSlots,
    required this.onSelectionChanged,
    this.columns = 6,
  });

  @override
  State<TimeGrid> createState() => _TimeGridState();
}

class _TimeGridState extends State<TimeGrid> {
  late Set<TimeSlot> _selected;
  final ScrollController _scrollController = ScrollController();
  TimeSlot _rangeStart = const TimeSlot(6, 0);
  TimeSlot _rangeEnd = const TimeSlot(9, 0);

  static final List<TimeSlot> _allSlots = List.generate(
    96,
    (index) => TimeSlot(index ~/ 4, (index % 4) * 15),
  );

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedSlots);
  }

  @override
  void didUpdateWidget(TimeGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSlots != oldWidget.selectedSlots) {
      _selected = Set.from(widget.selectedSlots);
    }
  }

  void _toggleSlot(TimeSlot slot) {
    setState(() {
      if (_selected.contains(slot)) {
        _selected.remove(slot);
      } else {
        _selected.add(slot);
      }
    });
    widget.onSelectionChanged(_selected);
  }

  void _clearAll() {
    setState(() {
      _selected.clear();
    });
    widget.onSelectionChanged(_selected);
  }

  void _selectRange() {
    final startMinutes = _rangeStart.totalMinutes;
    final endMinutes = _rangeEnd.totalMinutes;

    if (startMinutes >= endMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    setState(() {
      for (final slot in _allSlots) {
        if (slot.totalMinutes >= startMinutes && slot.totalMinutes < endMinutes) {
          _selected.add(slot);
        }
      }
    });
    widget.onSelectionChanged(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _TimeDropdown(
                label: 'From',
                value: _rangeStart,
                slots: _allSlots,
                onChanged: (slot) {
                  if (slot != null) {
                    setState(() => _rangeStart = slot);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimeDropdown(
                label: 'To',
                value: _rangeEnd,
                slots: _allSlots,
                onChanged: (slot) {
                  if (slot != null) {
                    setState(() => _rangeEnd = slot);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: FilledButton.tonal(
                onPressed: _selectRange,
                child: const Text('Select'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Selected: ${_selected.length} time(s)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton.icon(
              onPressed: _selected.isNotEmpty ? _clearAll : null,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: GridView.builder(
              controller: _scrollController,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: widget.columns,
                childAspectRatio: 1.8,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: _allSlots.length,
              itemBuilder: (context, index) {
                final slot = _allSlots[index];
                final isSelected = _selected.contains(slot);

                return _TimeChip(
                  slot: slot,
                  isSelected: isSelected,
                  onTap: () => _toggleSlot(slot),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _TimeDropdown extends StatelessWidget {
  final String label;
  final TimeSlot value;
  final List<TimeSlot> slots;
  final ValueChanged<TimeSlot?> onChanged;

  const _TimeDropdown({
    required this.label,
    required this.value,
    required this.slots,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<TimeSlot>(
          initialValue: value,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
          items: slots.map((slot) {
            return DropdownMenuItem<TimeSlot>(
              value: slot,
              child: Text(slot.formatted),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  final TimeSlot slot;
  final bool isSelected;
  final VoidCallback onTap;

  const _TimeChip({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            slot.formatted,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isSelected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
