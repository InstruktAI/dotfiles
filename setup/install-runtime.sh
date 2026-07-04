#!/bin/bash
# Dotfiles runtime installer: the appearance daemon / system-service tier.
#
# macOS loads the launchd agents (the Swift KVO watcher for instant OS-appearance
# changes, and the solar apply-system job). Linux enables a systemd --user service
# that polls `appearance watch`. Both tiers read the same APPEARANCE_* config.
#
# Split out from install-core.sh so `make install` sets up user config without
# touching daemons; `make install-runtime` owns the service layer.
# Idempotent: safe to run multiple times.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS="$(uname -s)"

echo "Installing appearance runtime..."
echo "OS: $OS"

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

# Render the shared APPEARANCE_* config into a launchd plist or systemd unit.
# Both service definitions use the same __TOKEN__ placeholders, so one renderer
# feeds both platforms from a single config source.
render_template() {
    local src="$1"
    local dst="$2"

    sed \
        -e "s|__HOME__|$HOME|g" \
        -e "s|__APPEARANCE_WATCHER__|$DOTFILES/terminal/bin/appearance-watcher|g" \
        -e "s|__APPEARANCE_LATITUDE__|$(env_value APPEARANCE_LATITUDE 52.37)|g" \
        -e "s|__APPEARANCE_LONGITUDE__|$(env_value APPEARANCE_LONGITUDE 4.89)|g" \
        -e "s|__APPEARANCE_DARK_OFFSET_MINUTES__|$(env_value APPEARANCE_DARK_OFFSET_MINUTES 0)|g" \
        -e "s|__APPEARANCE_DST_DARK_OFFSET_MINUTES__|$(env_value APPEARANCE_DST_DARK_OFFSET_MINUTES 0)|g" \
        -e "s|__BREW_AUTOUPDATE_ITERM__|$DOTFILES/macos/bin/brew-autoupdate-iterm|g" \
        "$src" > "$dst"
}

if [[ "$OS" == "Darwin" ]]; then
    watcher_bin="$DOTFILES/terminal/bin/appearance-watcher"
    # The compiled binary is committed to git and synced across machines, so it
    # works out of the box with no per-machine build. Only build when it is
    # actually missing; never overwrite the committed binary, so its code hash
    # stays identical everywhere (one Full Disk Access identity) and Syncthing
    # has nothing to conflict. To rebuild after editing the source, delete the
    # binary and re-run the installer, or run swiftc manually.
    if [[ -f "$watcher_bin" ]]; then
        echo "  [OK] appearance-watcher present (from git)"
    elif command -v swiftc >/dev/null 2>&1; then
        swiftc "$DOTFILES/terminal/bin/appearance-watcher.swift" -o "$watcher_bin"
        echo "  [BUILD] appearance-watcher"
    else
        echo "  [WARN] no appearance-watcher binary and swiftc not found; skipping"
    fi

    # The watcher is a daemon, not a CLI. launchd runs the real binary directly
    # (see __APPEARANCE_WATCHER__ in the plist). A ~/.local/bin symlink made
    # launchd target the symlink, which macOS lists separately from the resolved
    # binary — two Full Disk Access entries for one program. Drop the stale link.
    rm -f "$HOME/.local/bin/appearance-watcher"

    chmod +x "$DOTFILES/macos/bin/brew-autoupdate" "$DOTFILES/macos/bin/brew-autoupdate-iterm"

    mkdir -p "$HOME/Library/LaunchAgents"

    for plist_dir_and_name in \
        "terminal:ai.instrukt.appearance-watcher.plist" \
        "terminal:ai.instrukt.appearance-system.plist" \
        "macos:ai.instrukt.brew-autoupdate.plist" \
    ; do
        plist_dir="${plist_dir_and_name%%:*}"
        plist_name="${plist_dir_and_name##*:}"
        plist_src="$DOTFILES/$plist_dir/launchd/$plist_name"
        plist_dst="$HOME/Library/LaunchAgents/$plist_name"
        plist_label="${plist_name%.plist}"

        rendered="$(mktemp)"
        render_template "$plist_src" "$rendered"

        # Only re-install and reload when the rendered plist actually changed or
        # the agent is not loaded. Otherwise reloading would needlessly restart a
        # running daemon on every install.
        if [[ -f "$plist_dst" ]] && cmp -s "$rendered" "$plist_dst" && launchctl list "$plist_label" &>/dev/null; then
            rm -f "$rendered"
            echo "  [OK] $plist_label loaded"
            continue
        fi

        mv "$rendered" "$plist_dst"
        echo "  [COPY] $plist_dst"
        launchctl unload "$plist_dst" 2>/dev/null || true
        launchctl load "$plist_dst"
        echo "  [LAUNCHD] $plist_label loaded"
    done

    if pgrep -qf appearance-watcher; then
        echo "  [OK] appearance-watcher running"
    else
        echo "  [WARN] appearance-watcher not running"
    fi
else
    service_src="$DOTFILES/terminal/systemd/appearance.service"
    service_dir="$HOME/.config/systemd/user"
    service_dst="$service_dir/appearance.service"
    mkdir -p "$service_dir"

    rendered="$(mktemp)"
    render_template "$service_src" "$rendered"
    if [[ -f "$service_dst" ]] && cmp -s "$rendered" "$service_dst"; then
        rm -f "$rendered"
        echo "  [OK] appearance.service up to date"
    else
        mv "$rendered" "$service_dst"
        echo "  [COPY] $service_dst"
    fi

    systemctl --user daemon-reload
    systemctl --user enable --now appearance.service
    echo "  [SYSTEMD] appearance.service enabled"
fi

echo ""
echo "Appearance runtime done."
