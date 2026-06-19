#!/bin/bash
# Dotfiles core installer: symlinks, launchd agents, and shell activation.
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

env_value() {
    local key="$1"
    local default="$2"
    local value="${!key:-}"

    if [[ -n "$value" ]]; then
        printf '%s\n' "$value"
        return
    fi

    if [[ -f "$DOTFILES/.env" ]]; then
        value=$(
            awk -F= -v key="$key" '
                $0 ~ "^[[:space:]]*(export[[:space:]]+)?" key "=" {
                    sub(/^[[:space:]]*export[[:space:]]+/, "", $0)
                    sub("^[[:space:]]*" key "=", "", $0)
                    sub(/[[:space:]]*#.*$/, "", $0)
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
                    gsub(/^'\''|'\''$/, "", $0)
                    gsub(/^"|"$/, "", $0)
                    value = $0
                }
                END { print value }
            ' "$DOTFILES/.env"
        )
        if [[ -n "$value" ]]; then
            printf '%s\n' "$value"
            return
        fi
    fi

    printf '%s\n' "$default"
}

render_launchd_plist() {
    local src="$1"
    local dst="$2"

    sed \
        -e "s|__HOME__|$HOME|g" \
        -e "s|__APPEARANCE_WATCHER__|$DOTFILES/terminal/bin/appearance-watcher|g" \
        -e "s|__APPEARANCE_LATITUDE__|$(env_value APPEARANCE_LATITUDE 52.37)|g" \
        -e "s|__APPEARANCE_LONGITUDE__|$(env_value APPEARANCE_LONGITUDE 4.89)|g" \
        -e "s|__APPEARANCE_DARK_OFFSET_MINUTES__|$(env_value APPEARANCE_DARK_OFFSET_MINUTES 0)|g" \
        -e "s|__APPEARANCE_DST_DARK_OFFSET_MINUTES__|$(env_value APPEARANCE_DST_DARK_OFFSET_MINUTES 60)|g" \
        "$src" > "$dst"
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
# .zshenv is sourced for non-interactive ssh shells; without it PATH (Homebrew,
# toolchains) is missing for cross-computer tmux attach and other ssh-invoked tools.
link "$DOTFILES/zsh/zshenv" "$HOME/.zshenv"
install_zsh_activation

echo ""
echo "=== Terminal ==="
mkdir -p "$HOME/.local/bin"

link "$DOTFILES/terminal/bin/appearance.py" "$HOME/.local/bin/appearance"
link "$DOTFILES/terminal/tmux.conf" "$HOME/.tmux.conf"

if [[ "$OS" == "Darwin" ]]; then
    if [[ -d "$DOTFILES/iterm2" ]]; then
        defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$DOTFILES/iterm2"
        defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
        echo "  [OK] iTerm2 prefs -> $DOTFILES/iterm2"
    fi

    watcher_src="$DOTFILES/terminal/bin/appearance-watcher.swift"
    watcher_bin="$DOTFILES/terminal/bin/appearance-watcher"
    # Rebuild only when missing or the source changed. The binary is ad-hoc
    # signed, so each recompile changes its code hash and macOS re-prompts for
    # Full Disk Access.
    if command -v swiftc >/dev/null 2>&1 && [[ ! -f "$watcher_bin" || "$watcher_src" -nt "$watcher_bin" ]]; then
        swiftc "$watcher_src" -o "$watcher_bin"
        echo "  [BUILD] appearance-watcher"
    elif [[ -f "$watcher_bin" ]]; then
        echo "  [OK] appearance-watcher up to date"
    else
        echo "  [WARN] swiftc not found and no prebuilt appearance-watcher; skipping"
    fi

    # The watcher is a daemon, not a CLI. launchd runs the real binary directly
    # (see __APPEARANCE_WATCHER__ in the plist). A ~/.local/bin symlink made
    # launchd target the symlink, which macOS lists separately from the resolved
    # binary — two Full Disk Access entries for one program. Drop the stale link.
    rm -f "$HOME/.local/bin/appearance-watcher"

    mkdir -p "$HOME/Library/LaunchAgents"

    for plist_name in ai.instrukt.appearance-watcher.plist ai.instrukt.appearance-system.plist; do
        plist_src="$DOTFILES/terminal/launchd/$plist_name"
        plist_dst="$HOME/Library/LaunchAgents/$plist_name"
        render_launchd_plist "$plist_src" "$plist_dst"
        echo "  [COPY] $plist_dst"

        launchctl unload "$plist_dst" 2>/dev/null || true
        launchctl load "$plist_dst"
        echo "  [LAUNCHD] ${plist_name%.plist} loaded"
    done
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

if [[ "$OS" == "Darwin" ]]; then
    if pgrep -qf appearance-watcher; then
        echo "  [OK] appearance-watcher running"
    else
        echo "  [WARN] appearance-watcher not running"
    fi
fi

echo ""
echo "Dotfiles core done."
