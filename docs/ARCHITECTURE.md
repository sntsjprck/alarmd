# Alarmd - Architecture Documentation

A desktop alarm application built with Flutter for Linux, macOS, and Windows.

## Table of Contents

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Tech Stack](#tech-stack)
4. [Project Structure](#project-structure)
5. [Data Model](#data-model)
6. [State Management](#state-management)
7. [Services](#services)
8. [UI Components](#ui-components)
9. [Alarm Flow](#alarm-flow)
10. [Configuration](#configuration)

---

## Overview

Alarmd is a personal alarm application designed for users who need multiple alarms set at regular intervals. The primary use case is setting dozens of alarms (e.g., every 15 minutes over a 2-hour period) to help wake up.

### Key Features

- **Quick Time Selection**: 96-slot grid (15-minute intervals) for rapid multi-alarm creation
- **Custom Time Entry**: Single alarm creation with precise time picker
- **Optional Labels**: Name your alarms for easy identification
- **Snooze System**: Predefined intervals (5/10/15 min) + custom, max 3 snoozes per alarm
- **Non-Intrusive Notifications**: System notifications that don't interrupt fullscreen apps
- **Visual Feedback**: In-app animation when alarm is ringing
- **Multiple Alarm Sounds**: 3 bundled sounds to choose from

### Constraints

- App must be running for alarms to trigger (no system-level wake from suspend)
- Desktop only (no mobile/web support)
- Linux is the primary target platform

---

## Requirements

### Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| F1 | Create alarms via 15-min interval grid | Must |
| F2 | Create alarms via custom time picker | Must |
| F3 | Enable/disable individual alarms | Must |
| F4 | Delete alarms | Must |
| F5 | Play alarm sound when triggered | Must |
| F6 | Show system notification when triggered | Must |
| F7 | Snooze alarm (5/10/15 min or custom) | Must |
| F8 | Limit snooze to 3 times per alarm | Must |
| F9 | Visual indicator for ringing alarm | Must |
| F10 | Optional alarm labels | Should |
| F11 | Multiple alarm sound options | Should |
| F12 | Persist alarms across app restarts | Must |

### Non-Functional Requirements

| ID | Requirement |
|----|-------------|
| NF1 | Alarm triggers within 1 second of scheduled time |
| NF2 | Notifications must not steal focus from other apps |
| NF3 | UI must be responsive during alarm checks |
| NF4 | Minimal resource usage when idle |

---

## Tech Stack

| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| Framework | Flutter | 3.x | Cross-platform UI |
| State Management | Riverpod | ^2.4.9 | Reactive state |
| Local Storage | Hive | ^2.2.3 | Alarm persistence |
| Audio | just_audio | ^0.9.36 | Sound playback |
| Notifications | local_notifier | ^0.1.6 | Desktop notifications |
| Window Management | window_manager | ^0.3.8 | Focus detection |
| UUID | uuid | ^4.2.2 | Unique alarm IDs |

### Why These Choices?

**Riverpod over Provider/BLoC**:
- No BuildContext dependency (easier testing)
- Compile-time safety for providers
- Clean separation of state and logic
- Less boilerplate than BLoC

**Hive over SQLite**:
- No native dependencies
- Faster for simple key-value data
- Built-in Flutter support
- Type adapters for custom objects

**just_audio over audioplayers**:
- Better desktop platform support
- More reliable playback controls
- Active maintenance

---

## Project Structure

```
lib/
├── main.dart                         # App entry point
│
├── models/
│   └── alarm.dart                    # Alarm data model + Hive adapter
│
├── services/
│   ├── alarm_scheduler.dart          # Timer-based alarm triggering
│   ├── audio_service.dart            # Sound playback management
│   ├── notification_service.dart     # Desktop notification handling
│   └── storage_service.dart          # Hive CRUD operations
│
├── providers/
│   ├── alarm_provider.dart           # Alarm list state
│   └── active_alarm_provider.dart    # Currently ringing alarm state
│
└── ui/
    ├── screens/
    │   └── home_screen.dart          # Main alarm list view
    │
    ├── widgets/
    │   ├── alarm_tile.dart           # Individual alarm display
    │   ├── time_grid.dart            # 96-slot selection grid
    │   └── snooze_sheet.dart         # Snooze options bottom sheet
    │
    └── dialogs/
        ├── create_alarm_dialog.dart  # Multi-alarm creation
        └── custom_time_dialog.dart   # Single alarm creation

assets/
├── sounds/
│   ├── alarm_gentle.mp3              # Soft alarm tone
│   ├── alarm_standard.mp3            # Default alarm tone
│   └── alarm_urgent.mp3              # Loud alarm tone

docs/
└── ARCHITECTURE.md                   # This file
```

---

## Data Model

### Alarm

```dart
@HiveType(typeId: 0)
class Alarm extends HiveObject {
  @HiveField(0)
  final String id;              // UUID

  @HiveField(1)
  final int hour;               // 0-23

  @HiveField(2)
  final int minute;             // 0-59

  @HiveField(3)
  bool enabled;                 // Toggle state

  @HiveField(4)
  String? label;                // Optional description

  @HiveField(5)
  int snoozeCount;              // Current snooze count (0-3)

  @HiveField(6)
  final int maxSnooze;          // Maximum allowed snoozes (default: 3)

  @HiveField(7)
  String soundAsset;            // Path to alarm sound

  // Computed property
  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  // For display
  String get formattedTime => /* "11:30 AM" format */;
}
```

### Why Store hour/minute Instead of TimeOfDay?

Hive requires primitive types or custom adapters. Storing `hour` and `minute` as integers:
- Avoids complex TimeOfDay adapter
- Simpler serialization
- Easy to reconstruct TimeOfDay when needed

---

## State Management

### Provider Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Riverpod                         │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────────┐    ┌──────────────────────┐   │
│  │ alarmProvider   │    │ activeAlarmProvider  │   │
│  │                 │    │                      │   │
│  │ - List<Alarm>   │    │ - Alarm? current     │   │
│  │ - add()         │    │ - Queue<Alarm>       │   │
│  │ - remove()      │    │ - dismiss()          │   │
│  │ - toggle()      │    │ - snooze()           │   │
│  │ - update()      │    │ - next()             │   │
│  └────────┬────────┘    └──────────┬───────────┘   │
│           │                        │               │
│           └────────────┬───────────┘               │
│                        │                           │
│              ┌─────────▼─────────┐                 │
│              │  StorageService   │                 │
│              │  (Hive Box)       │                 │
│              └───────────────────┘                 │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### AlarmNotifier

Manages the list of all alarms:

```dart
class AlarmNotifier extends Notifier<List<Alarm>> {
  @override
  List<Alarm> build() {
    // Load from Hive on init
    return ref.read(storageServiceProvider).getAllAlarms();
  }

  void addAlarm(Alarm alarm) { /* Add + persist */ }
  void removeAlarm(String id) { /* Remove + persist */ }
  void toggleAlarm(String id) { /* Toggle enabled + persist */ }
  void updateSnoozeCount(String id, int count) { /* Update + persist */ }
}
```

### ActiveAlarmNotifier

Manages currently ringing alarms:

```dart
class ActiveAlarmNotifier extends Notifier<ActiveAlarmState> {
  @override
  ActiveAlarmState build() => ActiveAlarmState.empty();

  void triggerAlarm(Alarm alarm) { /* Add to queue, start sound */ }
  void dismiss() { /* Stop sound, clear current, process next */ }
  void snooze(Duration duration) { /* Stop, schedule re-trigger */ }
}

class ActiveAlarmState {
  final Alarm? currentAlarm;      // Currently ringing
  final Queue<Alarm> pending;     // Waiting to ring
}
```

---

## Services

### AlarmScheduler

Runs a periodic timer (every 1 second) to check for alarms:

```dart
class AlarmScheduler {
  Timer? _timer;
  final Set<String> _triggeredThisMinute = {};

  void start(List<Alarm> alarms, Function(Alarm) onTrigger) {
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      final now = TimeOfDay.now();

      // Reset tracking on minute change
      if (now.minute != _lastMinute) {
        _triggeredThisMinute.clear();
      }

      for (final alarm in alarms) {
        if (alarm.enabled &&
            alarm.hour == now.hour &&
            alarm.minute == now.minute &&
            !_triggeredThisMinute.contains(alarm.id)) {
          _triggeredThisMinute.add(alarm.id);
          onTrigger(alarm);
        }
      }
    });
  }

  void stop() => _timer?.cancel();
}
```

### Conflict Handling

When multiple alarms trigger at the same time:
1. All matching alarms are added to the pending queue
2. Queue is sorted by time (earlier first, though same-minute alarms are effectively equal)
3. Only one alarm rings at a time
4. User must dismiss/snooze before next alarm starts
5. This prevents overlapping sounds and notification spam

### AudioService

```dart
class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playAlarm(String assetPath) async {
    await _player.setAsset(assetPath);
    await _player.setLoopMode(LoopMode.one);  // Loop until dismissed
    await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
  }
}
```

### NotificationService

```dart
class NotificationService {
  Future<void> init() async {
    await localNotifier.setup(appName: 'Alarmd');
  }

  void showAlarmNotification(Alarm alarm) {
    final notification = LocalNotification(
      title: 'Alarm',
      body: alarm.label ?? alarm.formattedTime,
    );
    notification.show();
  }

  void dismiss() {
    // Close any active notifications
  }
}
```

### StorageService

```dart
class StorageService {
  late Box<Alarm> _alarmBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(AlarmAdapter());
    _alarmBox = await Hive.openBox<Alarm>('alarms');
  }

  List<Alarm> getAllAlarms() => _alarmBox.values.toList();
  Future<void> saveAlarm(Alarm alarm) => _alarmBox.put(alarm.id, alarm);
  Future<void> deleteAlarm(String id) => _alarmBox.delete(id);
}
```

---

## UI Components

### HomeScreen

Main screen layout:

```
┌──────────────────────────────────────┐
│  Alarmd                    [⚙️]      │  <- AppBar with settings
├──────────────────────────────────────┤
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 6:00 AM                    [×] │  │  <- AlarmTile (ringing state
│  │ Wake up - attempt 1        🔔  │  │     shows animation)
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 6:15 AM                    [×] │  │
│  │                            ⬚   │  │  <- Toggle switch
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 6:30 AM                    [×] │  │
│  │ Wake up                    ✓   │  │
│  └────────────────────────────────┘  │
│                                      │
│                                      │
│                           [+ Add]    │  <- FAB
└──────────────────────────────────────┘
```

### TimeGrid (Create Dialog - Quick Select)

Flat scrollable grid with all 96 time slots:

```
┌──────────────────────────────────────┐
│  Quick Select    |    Custom Time   │  <- Tab bar
├──────────────────────────────────────┤
│                                      │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ │
│  │12:00 │ │12:15 │ │12:30 │ │12:45 │ │  <- Time slots
│  │  AM  │ │  AM  │ │  AM  │ │  AM  │ │     (checkable)
│  └──────┘ └──────┘ └──────┘ └──────┘ │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ │
│  │ 1:00 │ │ 1:15 │ │ 1:30 │ │ 1:45 │ │
│  │  AM  │ │  AM  │ │  AM  │ │  AM  │ │
│  └──────┘ └──────┘ └──────┘ └──────┘ │
│                                      │
│  ... (scrollable) ...                │
│                                      │
│  Label (optional): [____________]    │
│                                      │
│  Selected: 8 times                   │
│                                      │
│  [Cancel]              [Create (8)]  │
└──────────────────────────────────────┘
```

### SnoozeSheet

Bottom sheet shown when alarm is ringing:

```
┌──────────────────────────────────────┐
│                                      │
│         🔔 6:00 AM                   │
│         "Wake up"                    │
│                                      │
│  Snoozes remaining: 3                │
│                                      │
│  ┌────────┐ ┌────────┐ ┌────────┐   │
│  │ 5 min  │ │ 10 min │ │ 15 min │   │
│  └────────┘ └────────┘ └────────┘   │
│                                      │
│  ┌────────────────────────────────┐  │
│  │         Custom...              │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │          Dismiss               │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

---

## Alarm Flow

### Creating Alarms (Quick Select)

```
User opens dialog
       │
       ▼
User checks multiple time slots
       │
       ▼
User optionally adds label
       │
       ▼
User taps "Create"
       │
       ▼
For each selected time:
  ├── Generate UUID
  ├── Create Alarm object
  ├── Save to Hive
  └── Add to state
       │
       ▼
Dialog closes
       │
       ▼
AlarmScheduler picks up new alarms
```

### Alarm Triggering

```
Timer fires (every 1 second)
       │
       ▼
Check current time against all enabled alarms
       │
       ▼
Match found?
  │
  ├── No → Continue
  │
  └── Yes → Already triggered this minute?
              │
              ├── Yes → Skip
              │
              └── No → Trigger alarm
                        │
                        ▼
                  Add to pending queue
                        │
                        ▼
                  Is another alarm already ringing?
                        │
                        ├── Yes → Wait in queue
                        │
                        └── No → Start this alarm
                                  │
                                  ├── Play sound (loop)
                                  ├── Show notification
                                  └── Update UI (animate tile)
```

### Snooze Flow

```
User taps snooze (e.g., 5 min)
       │
       ▼
Check snoozeCount < maxSnooze?
  │
  ├── No → Show "Max snoozes reached"
  │
  └── Yes → Stop sound
            │
            ▼
      Increment snoozeCount
            │
            ▼
      Calculate snooze time (now + duration)
            │
            ▼
      Schedule one-time timer
            │
            ▼
      Process next queued alarm (if any)
            │
            ▼
      Timer fires → Re-trigger alarm
```

### Dismiss Flow

```
User taps "Dismiss"
       │
       ▼
Stop sound
       │
       ▼
Close notification
       │
       ▼
Reset snoozeCount to 0
       │
       ▼
Process next queued alarm (if any)
       │
       ▼
Update UI
```

---

## Configuration

### Default Values

| Setting | Default | Notes |
|---------|---------|-------|
| Max snooze count | 3 | Per alarm |
| Default sound | alarm_standard.mp3 | Can be changed per alarm |
| Time grid interval | 15 minutes | Fixed at 96 slots |
| Scheduler precision | 1 second | Balance of accuracy vs CPU |

### Future Enhancements (Not in Scope)

- [ ] Repeating alarms (daily, weekdays, etc.)
- [ ] System tray integration
- [ ] Wake from suspend (requires OS-level integration)
- [ ] Gradually increasing volume
- [ ] Multiple alarm profiles
- [ ] Import/export alarms
- [ ] Keyboard shortcuts

---

## Development Notes

### Running the App

```bash
# Linux
flutter run -d linux

# macOS
flutter run -d macos

# Windows
flutter run -d windows
```

### Building

```bash
flutter build linux --release
flutter build macos --release
flutter build windows --release
```

### Testing

```bash
flutter test
```

### Code Generation (Hive Adapters)

After modifying the Alarm model:

```bash
dart run build_runner build --delete-conflicting-outputs
```
