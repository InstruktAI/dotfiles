#!/bin/bash
# Dotfiles installer - creates symlinks for all configs
# Idempotent: safe to run multiple times

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

echo "Installing dotfiles..."
echo "Source: $DOTFILES"
echo "OS: $OS"
echo ""

# Helper to create symlink (with backup if needed)
link() {
    local src="$1"
    local dst="$2"

    if [[ -L "$dst" ]]; then
        local current
        current=$(readlink "$dst")
        if [[ "$current" == "$src" ]]; then
            echo "  [OK] $dst"
            return
        fi
        rm "$dst"
    elif [[ -e "$dst" ]]; then
        echo "  [BACKUP] $dst -> $dst.bak"
        mv "$dst" "$dst.bak"
    fi

    # Ensure parent directory exists
    mkdir -p "$(dirname "$dst")"

    ln -s "$src" "$dst"
    echo "  [LINK] $dst -> $src"
}

# =============================================================================
# ZSH Configuration
# =============================================================================
echo "=== ZSH ==="
link "$DOTFILES/zsh" "$HOME/.config/zsh"
# .zshenv is sourced for non-interactive ssh shells; without it PATH (Homebrew,
# toolchains) is missing for cross-computer tmux attach and other ssh-invoked tools.
link "$DOTFILES/zsh/zshenv" "$HOME/.zshenv"

# =============================================================================
# Terminal / Appearance
# =============================================================================
echo ""
echo "=== Terminal ==="
mkdir -p "$HOME/.local/bin"

link "$DOTFILES/terminal/bin/appearance.py" "$HOME/.local/bin/appearance"
link "$DOTFILES/terminal/tmux.conf" "$HOME/.tmux.conf"

# macOS-specific
if [[ "$OS" == "Darwin" ]]; then
    # iTerm2: load preferences from dotfiles
    if [[ -d "$DOTFILES/iterm2" ]]; then
        defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$DOTFILES/iterm2"
        defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
        echo "  [OK] iTerm2 prefs -> $DOTFILES/iterm2"
    fi

    # appearance-watcher binary and launchd
    link "$DOTFILES/terminal/bin/appearance-watcher" "$HOME/.local/bin/appearance-watcher"

    # Install launchd plist (copy, not symlink - launchd prefers this)
    plist_src="$DOTFILES/terminal/launchd/ai.instrukt.appearance-watcher.plist"
    plist_dst="$HOME/Library/LaunchAgents/ai.instrukt.appearance-watcher.plist"

    mkdir -p "$HOME/Library/LaunchAgents"
    sed "s|__HOME__|$HOME|g" "$plist_src" > "$plist_dst"
    echo "  [COPY] $plist_dst"

    # Load launchd job
    launchctl unload "$plist_dst" 2>/dev/null || true
    launchctl load "$plist_dst"
    echo "  [LAUNCHD] appearance-watcher loaded"
fi

# =============================================================================
# Verify
# =============================================================================
echo ""
echo "=== Verification ==="

if [[ -L "$HOME/.config/zsh" ]]; then
    echo "  [OK] ~/.config/zsh"
else
    echo "  [WARN] ~/.config/zsh not linked"
fi

if command -v appearance &>/dev/null || [[ -x "$HOME/.local/bin/appearance" ]]; then
    echo "  [OK] appearance command"
else
    echo "  [WARN] appearance not in PATH - add ~/.local/bin to PATH"
fi

if [[ "$OS" == "Darwin" ]]; then
    if pgrep -qf appearance-watcher; then
        echo "  [OK] appearance-watcher running"
    else
        echo "  [WARN] appearance-watcher not running"
    fi
fi

echo ""
echo "Done! Make sure ~/.local/bin is in your PATH."
echo ""
echo "If not already, add to your ~/.zshrc:"
echo '  export ZDOTDIR="$HOME/.config/zsh"'
echo '  [[ -r "$ZDOTDIR/00-helpers.zsh" ]] && for f in "$ZDOTDIR"/*.zsh; do source "$f"; done'
