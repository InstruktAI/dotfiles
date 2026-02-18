#!/bin/bash
# Bootstrap dotfiles on a new machine.
# Installs prerequisites, then runs the main installer.
#
# Usage:
#   ./setup/bootstrap.sh            # full setup
#   ./setup/bootstrap.sh --no-apps  # skip Brewfile

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKIP_APPS=false
[[ "${1:-}" == "--no-apps" ]] && SKIP_APPS=true

echo "=== Dotfiles Bootstrap ==="
echo ""

# ─── Homebrew ───────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add to current session (the installer prints this but doesn't do it)
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
else
    echo "[OK] Homebrew already installed"
fi

# ─── Oh My Zsh ─────────────────────────────────────────────────────────────
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "[OK] Oh My Zsh already installed"
fi

# ─── Bun ──────────────────────────────────────────────────────────────────
if ! command -v bun &>/dev/null; then
    echo "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
else
    echo "[OK] Bun already installed"
fi

# ─── Local config templates ───────────────────────────────────────────────
echo ""
echo "=== Local Config ==="
for example in "$DOTFILES"/**/*.example; do
    local_file="${example%.example}"
    if [[ ! -f "$local_file" ]]; then
        cp "$example" "$local_file"
        echo "  [NEW] ${local_file#$DOTFILES/} (customize to your machine)"
    else
        echo "  [OK] ${local_file#$DOTFILES/}"
    fi
done

# ─── Main installer (symlinks) ─────────────────────────────────────────────
echo ""
"$DOTFILES/install.sh"

# ─── Brewfile (macOS) ──────────────────────────────────────────────────────
if [[ "$SKIP_APPS" == false && "$(uname -s)" == "Darwin" && -f "$DOTFILES/macos/Brewfile" ]]; then
    echo ""
    echo "=== Homebrew Packages ==="
    brew bundle --file="$DOTFILES/macos/Brewfile" --no-lock
fi

# ─── macOS defaults ────────────────────────────────────────────────────────
if [[ "$(uname -s)" == "Darwin" && -f "$DOTFILES/macos/defaults.sh" ]]; then
    echo ""
    read -rp "Apply macOS system defaults? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        bash "$DOTFILES/macos/defaults.sh"
    else
        echo "Skipped. Run later with: bash $DOTFILES/macos/defaults.sh"
    fi
fi

echo ""
echo "=== Bootstrap complete ==="
echo ""
echo "Remaining manual steps:"
echo "  1. Add to ~/.zshrc if not already:"
echo '     export ZDOTDIR="$HOME/.config/zsh"'
echo '     [[ -r "$ZDOTDIR/00-helpers.zsh" ]] && for f in "$ZDOTDIR"/*.zsh; do source "$f"; done'
echo "  2. Import GPG key: $DOTFILES/setup/import-gpg-key.sh"
