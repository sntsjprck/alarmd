# Alarmd

A simple desktop alarm clock application for Linux.

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

## Installation

> **Note:** This application has only been tested on Ubuntu 24.04.3. It may work on other Linux distributions but is not guaranteed.

### Download AppImage (Recommended)

Download the latest AppImage from [Releases](https://github.com/sntsjprck/alarmd/releases):

```bash
# Install dependencies
sudo apt-get install mpv pulseaudio ffmpeg libfuse2t64

# Create a directory for the app and move the AppImage there
mkdir -p ~/Applications
mv Alarmd-*.AppImage ~/Applications/

# Make executable and run
chmod +x ~/Applications/Alarmd-*.AppImage
~/Applications/Alarmd-*.AppImage &
```

> **Important:** The AppImage file *is* the application. Move it to a permanent location like `~/Applications` before running. If you delete the AppImage file, the application is removed.

The app will automatically add itself to your application menu on first launch.

> **GNOME Users:** Install the [AppIndicator Support](https://extensions.gnome.org/extension/615/appindicator-support/) extension for the system tray icon to appear.

### Uninstall

To completely remove Alarmd and all its data:

```bash
# Remove the AppImage file (adjust path if you placed it elsewhere)
rm ~/Applications/Alarmd-*.AppImage

# Remove desktop entry and icon
rm ~/.local/share/applications/alarmd.desktop
rm ~/.local/share/icons/hicolor/256x256/apps/alarmd.png

# Remove app data (alarms and settings)
rm -rf ~/.local/share/alarmd

# Remove systemd timer (if enabled)
systemctl --user disable --now alarmd.timer 2>/dev/null
rm -f ~/.config/systemd/user/alarmd.timer ~/.config/systemd/user/alarmd.service
systemctl --user daemon-reload
```

## Usage

1. Click the **New Alarm** button to create alarms
2. Use **Quick Select** tab to choose multiple 15-minute time slots
3. Use **Custom Time** tab for a specific time
4. Toggle alarms on/off with the switch
5. When an alarm rings, choose to **Dismiss** or **Snooze**

---

## Development

### Prerequisites

Install system dependencies for building:

```bash
sudo apt-get install mpv libnotify-dev pulseaudio ffmpeg libayatana-appindicator3-dev
```

### Setup

```bash
# Clone the repository
git clone https://github.com/sntsjprck/alarmd.git
cd alarmd

# Install Flutter dependencies
flutter pub get

# Generate Hive adapters
flutter pub run build_runner build
```

### Run in Debug Mode

```bash
flutter run -d linux
```

### Build Release

```bash
flutter build linux --release
```

Output: `build/linux/x64/release/bundle/` (folder with executable and libraries)

---

## Creating a Release

### Prerequisites (one-time setup)

**Using script:**
```bash
./scripts/install-appimage-tools.sh
```

**Or manually:**
```bash
mkdir -p ~/.local/bin
wget -O ~/.local/bin/appimagetool https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x ~/.local/bin/appimagetool
```

### 1. Build the AppImage

**Using script:**
```bash
./scripts/build-appimage.sh
```

**Or manually:**
```bash
# Build release
flutter build linux --release

# Create AppDir structure
mkdir -p AppDir/usr/{bin,lib,share/icons/hicolor/256x256/apps}
cp -r build/linux/x64/release/bundle/* AppDir/usr/bin/
cp -r build/linux/x64/release/bundle/lib/* AppDir/usr/lib/
cp assets/icon/app_icon.png AppDir/alarmd.png
cp assets/icon/app_icon.png AppDir/usr/share/icons/hicolor/256x256/apps/alarmd.png

# Create AppRun script
cat > AppDir/AppRun << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/usr/bin/alarmd" "$@"
EOF
chmod +x AppDir/AppRun

# Create desktop entry
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

# Build the AppImage
ARCH=x86_64 ~/.local/bin/appimagetool --appimage-extract-and-run AppDir Alarmd-1.0.0-x86_64.AppImage

# Cleanup
rm -rf AppDir
```

Output: `Alarmd-1.0.0-x86_64.AppImage` in project root (~17MB)

### 2. Publish to GitHub Releases

**Using GitHub Web:**
1. Go to https://github.com/sntsjprck/alarmd/releases/new
2. Create tag: `v1.0.0`
3. Upload `Alarmd-1.0.0-x86_64.AppImage`
4. Add release notes
5. Publish

**Using GitHub CLI:**
```bash
gh release create v1.0.0 Alarmd-1.0.0-x86_64.AppImage \
  --title "Alarmd v1.0.0" \
  --notes "Release notes here"
```

---

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models (Alarm, Settings)
├── providers/                # Riverpod state management
├── services/                 # Audio, notifications, tray, storage
└── ui/
    ├── screens/              # Home, Settings screens
    ├── widgets/              # Reusable widgets
    └── dialogs/              # Alarm creation dialogs
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md) - Technical design and architecture
- [Implementation](docs/IMPLEMENTATION.md) - Implementation progress tracker

## License

MIT
