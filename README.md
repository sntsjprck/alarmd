# Alarmd

A desktop alarm application for Linux.

## Features

- Quick time selection via 96-slot grid (15-minute intervals)
- Select multiple times at once for batch alarm creation
- Custom single-time alarm creation
- Snooze options: 5, 10, 15 minutes + custom (max 3 snoozes per alarm)
- Desktop notifications with dismiss/snooze actions
- System tray with minimize-to-tray option
- Visual feedback when alarms ring
- Persistent storage (alarms saved between sessions)
- Light/dark theme support

## Prerequisites

### Linux

Install the required system dependencies:

```bash
sudo apt-get install mpv libnotify-dev pulseaudio ffmpeg libayatana-appindicator3-dev
```

- `mpv` - Audio playback
- `libnotify-dev` - Desktop notifications
- `pulseaudio` - Audio output (PulseAudio or PipeWire with PulseAudio compatibility)
- `ffmpeg` - Required for audio normalization filters
- `libayatana-appindicator3-dev` - System tray support

> **GNOME Users:** Install the [AppIndicator and KStatusNotifierItem Support](https://extensions.gnome.org/extension/615/appindicator-support/) extension for tray icons to appear.

## Installation

### AppImage (Recommended)

Download the latest AppImage from [Releases](https://github.com/sntsjprck/alarmd/releases):

```bash
# Install FUSE (required for AppImages on Ubuntu 22.04+)
sudo apt-get install libfuse2t64

# Download and run
chmod +x Alarmd-*.AppImage
./Alarmd-*.AppImage
```

The app will automatically create a desktop entry on first launch, adding it to your application menu.

### Build from Source

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

### Build AppImage

```bash
# Build release first
flutter build linux --release

# Download appimagetool (one-time)
wget -O ~/.local/bin/appimagetool https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x ~/.local/bin/appimagetool

# Create AppDir structure
mkdir -p AppDir/usr/{bin,lib,share/icons/hicolor/256x256/apps}
cp -r build/linux/x64/release/bundle/* AppDir/usr/bin/
cp -r build/linux/x64/release/bundle/lib/* AppDir/usr/lib/
cp assets/icon/app_icon.png AppDir/alarmd.png
cp assets/icon/app_icon.png AppDir/usr/share/icons/hicolor/256x256/apps/alarmd.png

# Create AppRun
cat > AppDir/AppRun << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/usr/bin/alarmd" "$@"
EOF
chmod +x AppDir/AppRun

# Create desktop file
cat > AppDir/alarmd.desktop << 'EOF'
[Desktop Entry]
Name=Alarmd
Comment=Simple alarm clock application
Exec=alarmd
Icon=alarmd
Type=Application
Categories=Utility;Clock;
Terminal=false
StartupNotify=true
EOF

# Build AppImage
ARCH=x86_64 ~/.local/bin/appimagetool --appimage-extract-and-run AppDir Alarmd-1.0.0-x86_64.AppImage
```

## Usage

1. Click the **New Alarm** button to create alarms
2. Use **Quick Select** tab to choose multiple 15-minute time slots
3. Use **Custom Time** tab for a specific time
4. Toggle alarms on/off with the switch
5. When an alarm rings, choose to **Dismiss** or **Snooze**

## Documentation

- [Architecture](docs/ARCHITECTURE.md) - Technical design and architecture
- [Implementation](docs/IMPLEMENTATION.md) - Implementation progress tracker
