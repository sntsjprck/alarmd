# Alarmd

A desktop alarm application for Linux, macOS, and Windows.

## Features

- Quick time selection via 96-slot grid (15-minute intervals)
- Select multiple times at once for batch alarm creation
- Custom single-time alarm creation
- Snooze options: 5, 10, 15 minutes + custom (max 3 snoozes per alarm)
- Desktop notifications with dismiss/snooze actions
- Visual feedback when alarms ring
- Persistent storage (alarms saved between sessions)
- Light/dark theme support

## Prerequisites

### Linux

Install the required system dependencies:

```bash
sudo apt-get install mpv libnotify-dev pulseaudio ffmpeg
```

- `mpv` - Audio playback
- `libnotify-dev` - Desktop notifications
- `pulseaudio` - Audio output (PulseAudio or PipeWire with PulseAudio compatibility)
- `ffmpeg` - Required for audio normalization filters

## Installation

```bash
# Get dependencies
flutter pub get

# Generate Hive adapters (if needed)
flutter pub run build_runner build

# Run in debug mode
flutter run -d linux

# Build release
flutter build linux
```

## Usage

1. Click the **New Alarm** button to create alarms
2. Use **Quick Select** tab to choose multiple 15-minute time slots
3. Use **Custom Time** tab for a specific time
4. Toggle alarms on/off with the switch
5. When an alarm rings, choose to **Dismiss** or **Snooze**

## Documentation

- [Architecture](docs/ARCHITECTURE.md) - Technical design and architecture
- [Implementation](docs/implementation.md) - Implementation progress tracker
