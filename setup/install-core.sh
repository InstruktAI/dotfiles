#!/bin/bash
# Dotfiles core installer: symlinks, user config, and shell activation.
# The appearance daemon/service tier lives in install-runtime.sh (make install-runtime).
# Idempotent: safe to run multiple times.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS="$(uname -s)"

echo "Installing dotfiles core..."
echo "Source: $DOTFILES"
echo "OS: $OS"
echo ""

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

    mkdir -p "$(dirname "$dst")"

    ln -s "$src" "$dst"
    echo "  [LINK] $dst -> $src"
}

install_zsh_activation() {
    local shell_name
    shell_name="$(basename "${SHELL:-}")"
    if [[ "$shell_name" != "zsh" && ! -f "$HOME/.zshrc" && ! -d "$HOME/.oh-my-zsh" ]]; then
        echo "  [WARN] Shell activation skipped: unsupported shell '$shell_name'"
        return
    fi
    if [[ "$shell_name" != "zsh" ]]; then
        echo "  [INFO] Shell is '$shell_name'; wiring ~/.zshrc because zsh config is present"
    fi

    local zshrc="$HOME/.zshrc"

    # Skip the rewrite when the managed block is already present, correct, and
    # free of legacy lines this installer used to strip.
    if [[ -f "$zshrc" ]] \
        && grep -qF '# >>> instrukt dotfiles >>>' "$zshrc" \
        && grep -qF '[[ -r "$HOME/.config/zsh/init.zsh" ]] && source "$HOME/.config/zsh/init.zsh"' "$zshrc" \
        && ! grep -qE 'ZDOTDIR="\$HOME/\.config/zsh"|\$ZDOTDIR/00-helpers\.zsh|Sync/dotfiles/zsh/init\.zsh|Workspace/InstruktAI/dotfiles/zsh/init\.zsh' "$zshrc"; then
        echo "  [OK] ~/.zshrc already sources ~/.config/zsh/init.zsh"
        return
    fi

    local tmp
    tmp="$(mktemp)"
    touch "$zshrc"

    awk '
        BEGIN {
            in_block = 0
            inserted = 0
        }
        /^# >>> instrukt dotfiles >>>$/ {
            in_block = 1
            next
        }
        /^# <<< instrukt dotfiles <<<$/ {
            in_block = 0
            next
        }
        in_block {
            next
        }
        /^export ZDOTDIR="\$HOME\/\.config\/zsh"$/ {
            next
        }
        /\$ZDOTDIR\/00-helpers\.zsh/ {
            next
        }
        /Sync\/dotfiles\/zsh\/init\.zsh/ {
            next
        }
        /Workspace\/InstruktAI\/dotfiles\/zsh\/init\.zsh/ {
            next
        }
        {
            print
        }
        !inserted && /^source[[:space:]]+\$ZSH\/oh-my-zsh\.sh$/ {
            print ""
            print "# >>> instrukt dotfiles >>>"
            print "[[ -r \"$HOME/.config/zsh/init.zsh\" ]] && source \"$HOME/.config/zsh/init.zsh\""
            print "# <<< instrukt dotfiles <<<"
            inserted = 1
        }
        END {
            if (!inserted) {
                print ""
                print "# >>> instrukt dotfiles >>>"
                print "[[ -r \"$HOME/.config/zsh/init.zsh\" ]] && source \"$HOME/.config/zsh/init.zsh\""
                print "# <<< instrukt dotfiles <<<"
            }
        }
    ' "$zshrc" > "$tmp"
    mv "$tmp" "$zshrc"

    echo "  [OK] ~/.zshrc sources ~/.config/zsh/init.zsh"
}

echo "=== ZSH ==="
link "$DOTFILES/zsh" "$HOME/.config/zsh"
link "$DOTFILES/zsh/zshenv" "$HOME/.zshenv"
install_zsh_activation

echo ""
echo "=== Terminal ==="
mkdir -p "$HOME/.local/bin"

link "$DOTFILES/terminal/bin/appearance.py" "$HOME/.local/bin/appearance"
link "$DOTFILES/terminal/tmux.conf" "$HOME/.tmux.conf"

# appearance logs through the shared InstruktAI logger, which writes under the
# canonical /var/log/instrukt-ai/<app> root.
if telec_bin="$(command -v telec)"; then
    provision_logs="$(dirname "$(readlink "$telec_bin")")/provision-logs.sh"
    if [[ -x "$provision_logs" ]]; then
        "$provision_logs" appearance --non-interactive && echo "  [OK] appearance log dir provisioned"
    fi
fi

if [[ "$OS" == "Darwin" ]]; then
    if [[ -d "$DOTFILES/iterm2" ]]; then
        iterm_folder="$(defaults read com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null || true)"
        iterm_load="$(defaults read com.googlecode.iterm2 LoadPrefsFromCustomFolder 2>/dev/null || true)"
        if [[ "$iterm_folder" == "$DOTFILES/iterm2" && "$iterm_load" == "1" ]]; then
            echo "  [OK] iTerm2 prefs -> $DOTFILES/iterm2"
        else
            defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$DOTFILES/iterm2"
            defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
            echo "  [SET] iTerm2 prefs -> $DOTFILES/iterm2"
        fi
    fi
fi

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

echo ""
echo "Dotfiles core done."
