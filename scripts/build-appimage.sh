#!/bin/bash
# Build Alarmd AppImage

set -e

# Get version from pubspec.yaml
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
APPIMAGE_NAME="Alarmd-${VERSION}-x86_64.AppImage"

echo "Building Alarmd AppImage v${VERSION}..."

# Check if appimagetool is installed
if ! command -v ~/.local/bin/appimagetool &> /dev/null; then
    echo "Error: appimagetool not found. Run ./scripts/install-appimage-tools.sh first"
    exit 1
fi

# Build Flutter release
echo "Building Flutter release..."
flutter build linux --release

# Clean up previous AppDir
rm -rf AppDir

# Create AppDir structure
echo "Creating AppDir structure..."
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

# Build AppImage
echo "Building AppImage..."
ARCH=x86_64 ~/.local/bin/appimagetool --appimage-extract-and-run AppDir "$APPIMAGE_NAME"

# Cleanup
rm -rf AppDir

echo ""
echo "Done! Created: $APPIMAGE_NAME"
ls -lh "$APPIMAGE_NAME"
