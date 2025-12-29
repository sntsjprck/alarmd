# Alarmd Implementation Tracker

## Status Overview

| Phase | Status |
|-------|--------|
| 1. Project Setup | Done |
| 2. Data Model | Done |
| 3. Services | Done |
| 4. State Management | Done |
| 5. UI Components | Done |
| 6. Integration | Done |
| 7. Settings | Done |
| 8. System Tray & Background | Done |

---

## Build Requirements

Before building, install system dependencies:

**Linux:**
```bash
sudo apt-get install mpv libnotify-dev pulseaudio ffmpeg libayatana-appindicator3-dev
```

**Build commands:**
```bash
# Run in debug mode
flutter run -d linux

# Build release
flutter build linux
```

---

## Pending Tasks

### Before First Run
- [x] Add alarm sound files to `assets/sounds/` (beat.mp3, standard.mp3, chill.mp3)
- [ ] Run `sudo apt-get install mpv libnotify-dev` on Linux

---

## Completed

### Phase 1: Project Setup
- [x] Added dependencies to pubspec.yaml (riverpod, hive, just_audio, local_notifier, window_manager, uuid)
- [x] Created folder structure (models, services, providers, ui/screens, ui/widgets, ui/dialogs)
- [x] Created assets/sounds directory with README

### Phase 2: Data Model
- [x] Created `lib/models/alarm.dart` with Hive annotations
- [x] Generated Hive adapter (`alarm.g.dart`)

### Phase 3: Services
- [x] `lib/services/storage_service.dart` - Hive CRUD for alarms
- [x] `lib/services/audio_service.dart` - mpv-based audio playback with loop
- [x] `lib/services/notification_service.dart` - Desktop notifications with actions
- [x] `lib/services/alarm_scheduler.dart` - Timer-based triggering with snooze support

### Phase 4: State Management
- [x] `lib/providers/alarm_provider.dart` - Alarm list state with CRUD operations
- [x] `lib/providers/active_alarm_provider.dart` - Ringing alarm state with queue

### Phase 5: UI Components
- [x] `lib/ui/widgets/alarm_tile.dart` - Individual alarm display with ringing animation
- [x] `lib/ui/widgets/time_grid.dart` - 96-slot selection grid with quick range selection
- [x] `lib/ui/widgets/snooze_sheet.dart` - Snooze options (5/10/15 min + custom)
- [x] `lib/ui/dialogs/create_alarm_dialog.dart` - Tabbed alarm creation (Quick Select / Custom Time)
- [x] `lib/ui/dialogs/custom_time_dialog.dart` - Single time picker dialog
- [x] `lib/ui/screens/home_screen.dart` - Main screen with alarm list, edit, and FAB
- [x] `lib/main.dart` - App entry with Riverpod, Hive, window manager initialization
- [x] `test/widget_test.dart` - Updated with Alarm model tests

### Phase 6: Integration
- [x] All services wired to providers
- [x] Alarm scheduler integrated with active alarm state
- [x] Code analysis passes (0 issues)
- [x] Unit tests pass (4/4)

### Phase 7: Settings
- [x] `lib/models/settings.dart` - Settings model with Hive persistence
- [x] `lib/providers/settings_provider.dart` - Settings state management
- [x] `lib/ui/screens/settings_screen.dart` - Settings UI with:
  - Max snooze count selector
  - Customizable snooze intervals (add/remove)
  - Default alarm sound selection
- [x] Integrated settings into snooze sheet and alarm creation

### Phase 8: System Tray & Background Support
- [x] Update pubspec.yaml - Add `tray_manager: ^0.5.2`, update description
- [x] Update README.md - Linux-only, add `libayatana-appindicator3-dev` prerequisite
- [x] Remove intrusive window focus on alarm trigger
- [x] Add `minimizeToTray` setting to AppSettings model
- [x] Run build_runner to regenerate settings.g.dart
- [x] Create `lib/services/tray_service.dart` - System tray icon and menu
- [x] Update `lib/main.dart` - Tray initialization, window close handling
- [x] Add "Minimize to tray on close" toggle in settings UI
- [x] Connect alarm ringing state to tray tooltip

---

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── models/
│   ├── alarm.dart                     # Alarm data model
│   ├── alarm.g.dart                   # Generated Hive adapter
│   ├── settings.dart                  # Settings data model
│   └── settings.g.dart                # Generated Hive adapter
├── services/
│   ├── storage_service.dart           # Hive persistence
│   ├── audio_service.dart             # Sound playback
│   ├── notification_service.dart      # Desktop notifications
│   ├── alarm_scheduler.dart           # Timer-based scheduling
│   ├── tray_service.dart              # System tray icon and menu
│   ├── keep_alive_service.dart        # System sleep inhibition
│   └── desktop_integration_service.dart # AppImage desktop entry
├── providers/
│   ├── alarm_provider.dart            # Alarm list state
│   ├── active_alarm_provider.dart     # Ringing alarm state
│   └── settings_provider.dart         # Settings state
└── ui/
    ├── screens/
    │   ├── home_screen.dart           # Main screen
    │   └── settings_screen.dart       # Settings screen
    ├── widgets/
    │   ├── alarm_tile.dart            # Alarm list item
    │   ├── time_grid.dart             # 96-slot grid
    │   └── snooze_sheet.dart          # Snooze options
    └── dialogs/
        ├── create_alarm_dialog.dart   # Alarm creation
        └── custom_time_dialog.dart    # Time picker
```
