#!/bin/bash
# Install prerequisites for building AppImage

set -e

echo "Installing appimagetool..."

mkdir -p ~/.local/bin

if [ -f ~/.local/bin/appimagetool ]; then
    echo "appimagetool already installed at ~/.local/bin/appimagetool"
else
    wget -O ~/.local/bin/appimagetool https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x ~/.local/bin/appimagetool
    echo "appimagetool installed successfully"
fi

# Ensure ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo ""
    echo "NOTE: Add ~/.local/bin to your PATH by adding this to ~/.bashrc:"
    echo '  export PATH="$HOME/.local/bin:$PATH"'
fi

echo ""
echo "Done! You can now run: ./scripts/build-appimage.sh"
