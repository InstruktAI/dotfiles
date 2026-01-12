#!/bin/bash
# Idempotent installer for terminal/tmux appearance setup
# Works on macOS and Linux

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

echo "Installing terminal appearance setup..."
echo "OS: $OS"
echo "Source: $SCRIPT_DIR"

# =============================================================================
# Create directories
# =============================================================================
mkdir -p ~/.local/bin

# =============================================================================
# Symlink scripts
# =============================================================================
echo ""
echo "Symlinking scripts to ~/.local/bin/"

for script in "$SCRIPT_DIR/bin/"*; do
    name=$(basename "$script")
    target="$HOME/.local/bin/$name"

    # Skip Swift source files - they need to be compiled
    if [[ "$name" == *.swift ]]; then
        continue
    fi

    if [[ -L "$target" ]]; then
        current=$(readlink "$target")
        if [[ "$current" == "$script" ]]; then
            echo "  $name: already linked"
            continue
        fi
        rm "$target"
    elif [[ -e "$target" ]]; then
        echo "  $name: backing up existing file to $target.bak"
        mv "$target" "$target.bak"
    fi

    ln -s "$script" "$target"
    echo "  $name: linked"
done

# Make scripts executable
chmod +x "$SCRIPT_DIR/bin/appearance"

# =============================================================================
# Symlink tmux.conf
# =============================================================================
echo ""
echo "Symlinking tmux.conf"

if [[ -L ~/.tmux.conf ]]; then
    current=$(readlink ~/.tmux.conf)
    if [[ "$current" == "$SCRIPT_DIR/tmux.conf" ]]; then
        echo "  tmux.conf: already linked"
    else
        rm ~/.tmux.conf
        ln -s "$SCRIPT_DIR/tmux.conf" ~/.tmux.conf
        echo "  tmux.conf: linked"
    fi
elif [[ -e ~/.tmux.conf ]]; then
    echo "  tmux.conf: backing up to ~/.tmux.conf.bak"
    mv ~/.tmux.conf ~/.tmux.conf.bak
    ln -s "$SCRIPT_DIR/tmux.conf" ~/.tmux.conf
    echo "  tmux.conf: linked"
else
    ln -s "$SCRIPT_DIR/tmux.conf" ~/.tmux.conf
    echo "  tmux.conf: linked"
fi

# =============================================================================
# macOS-specific: Compile Swift watcher and install launchd job
# =============================================================================
if [[ "$OS" == "Darwin" ]]; then
    echo ""
    echo "macOS detected - setting up appearance watcher"

    # Compile Swift watcher
    swift_source="$SCRIPT_DIR/bin/appearance-watcher.swift"
    swift_binary="$HOME/.local/bin/appearance-watcher"

    if [[ -f "$swift_source" ]]; then
        echo "  Compiling appearance-watcher.swift..."
        swiftc -O -o "$swift_binary" "$swift_source"
        echo "  Compiled to $swift_binary"
    fi

    # Install launchd plist
    plist_source="$SCRIPT_DIR/launchd/com.morriz.appearance-watcher.plist"
    plist_target="$HOME/Library/LaunchAgents/com.morriz.appearance-watcher.plist"

    if [[ -f "$plist_source" ]]; then
        # Update paths in plist to use actual home directory
        mkdir -p ~/Library/LaunchAgents
        sed "s|/Users/Morriz|$HOME|g" "$plist_source" > "$plist_target"
        echo "  Installed launchd plist"

        # Unload if running, then load
        launchctl unload "$plist_target" 2>/dev/null || true
        launchctl load "$plist_target"
        echo "  Loaded launchd job"
    fi
fi

# =============================================================================
# Verify installation
# =============================================================================
echo ""
echo "Verifying installation..."

if command -v appearance &>/dev/null; then
    echo "  appearance command: OK"
else
    echo "  WARNING: appearance not in PATH. Add ~/.local/bin to your PATH."
fi

if [[ -L ~/.tmux.conf ]]; then
    echo "  tmux.conf symlink: OK"
fi

if [[ "$OS" == "Darwin" ]]; then
    if pgrep -f appearance-watcher >/dev/null; then
        echo "  appearance-watcher: running"
    else
        echo "  WARNING: appearance-watcher not running"
    fi
fi

echo ""
echo "Installation complete!"
echo ""
echo "Make sure ~/.local/bin is in your PATH:"
echo '  export PATH="$HOME/.local/bin:$PATH"'
