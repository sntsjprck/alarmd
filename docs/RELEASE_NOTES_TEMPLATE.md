# Release Notes Guide

Use this template when creating a new GitHub release.

## Release Title Format

```
Alarmd v{VERSION} - {SHORT_DESCRIPTION}
```

Examples:
- `Alarmd v1.0.0 - Initial Release`
- `Alarmd v1.1.0 - System Tray Support`
- `Alarmd v1.0.1 - Bug Fixes`

## Release Notes Template

```markdown
# Alarmd v{VERSION}

A simple desktop alarm clock application for Linux.

## What's New

- Feature 1
- Feature 2
- Bug fix 1

## Installation

### Prerequisites

```bash
sudo apt-get install mpv pulseaudio ffmpeg libfuse2t64
```

> `libfuse2t64` is required to run AppImages on Ubuntu 22.04+

### Download & Run

```bash
chmod +x Alarmd-{VERSION}-x86_64.AppImage
./Alarmd-{VERSION}-x86_64.AppImage
```

The app will automatically add itself to your application menu on first launch.

### GNOME Users

Install the [AppIndicator Support](https://extensions.gnome.org/extension/615/appindicator-support/) extension for the system tray icon to appear.

## Feedback

Report issues at https://github.com/sntsjprck/alarmd/issues
```

## Version Types

| Type | When to Use | Example |
|------|-------------|---------|
| Major (X.0.0) | Breaking changes, major rewrites | 2.0.0 |
| Minor (1.X.0) | New features, backwards compatible | 1.1.0 |
| Patch (1.0.X) | Bug fixes, small improvements | 1.0.1 |

## Checklist Before Release

- [ ] Update version in `pubspec.yaml` (this is the source of truth)
- [ ] Test the app thoroughly
- [ ] Build AppImage: `./scripts/build-appimage.sh`
- [ ] Test the AppImage
- [ ] Create GitHub release with notes (version MUST match `pubspec.yaml`)
- [ ] Upload AppImage to release

## Getting the Version

Always use the version from `pubspec.yaml` as the source of truth:

```bash
grep "^version:" pubspec.yaml | cut -d' ' -f2 | cut -d'+' -f1
```

Example output: `1.0.2`
