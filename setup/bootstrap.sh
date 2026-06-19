#!/bin/bash
# Bootstrap dotfiles on a new machine.
#
# Usage:
#   ./install.sh                 # core setup, local defaults, Homebrew check
#   ./install.sh --install-apps  # install missing Brewfile entries without upgrades
#   ./install.sh --no-apps       # skip Homebrew entirely
#   ./install.sh --no-defaults   # skip macOS defaults

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS="$(uname -s)"
SKIP_APPS=false
INSTALL_APPS=false
APPLY_DEFAULTS=true

usage() {
    cat <<'EOF'
Bootstrap dotfiles on a new machine.

Usage:
  ./install.sh                 # core setup, local defaults, Homebrew check
  ./install.sh --install-apps  # install missing Brewfile entries without upgrades
  ./install.sh --no-apps       # skip Homebrew entirely
  ./install.sh --no-defaults   # skip macOS defaults
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-apps | --install-brew)
            INSTALL_APPS=true
            ;;
        --no-apps | --no-brew)
            SKIP_APPS=true
            ;;
        --no-defaults)
            APPLY_DEFAULTS=false
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

ensure_local_file() {
    local src="$1"
    local dst="$2"
    local rel="${dst#"$DOTFILES"/}"

    if [[ -f "$dst" ]]; then
        echo "  [OK] $rel"
        return
    fi

    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "  [NEW] $rel (customize to your machine)"
}

pin_node_formula() {
    if ! command -v brew &>/dev/null; then
        return
    fi

    # Keep `node` on the v24 line. Some formulae depend on unversioned `node`;
    # pinning keeps the autoupdate agent from relinking past v24.
    if brew list --formula node &>/dev/null; then
        brew pin node 2>/dev/null || true
        brew unlink node &>/dev/null || true
    fi
    if brew list --formula node@24 &>/dev/null; then
        brew link --overwrite --force node@24
    fi
}

run_brew_bundle() {
    local brewfile="$DOTFILES/macos/Brewfile.local"

    if [[ "$SKIP_APPS" == true || "$OS" != "Darwin" || ! -f "$brewfile" ]]; then
        return
    fi

    echo ""
    echo "=== Homebrew Packages ==="

    if brew bundle check --file="$brewfile"; then
        echo "  [OK] Brewfile.local is satisfied"
        pin_node_formula
        return
    fi

    if [[ "$INSTALL_APPS" != true ]]; then
        echo "  [WARN] Brewfile.local has missing entries; not installing by default."
        echo "        Run ./install.sh --install-apps to install missing entries without upgrades."
        return
    fi

    HOMEBREW_BUNDLE_NO_UPGRADE=1 \
    HOMEBREW_NO_INSTALL_UPGRADE=1 \
        brew bundle install --file="$brewfile" --no-lock --no-upgrade
    pin_node_formula
}

echo "=== Dotfiles Bootstrap ==="
echo ""

if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
else
    echo "[OK] Homebrew already installed"
fi

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "[OK] Oh My Zsh already installed"
fi

if ! command -v bun &>/dev/null; then
    echo "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
else
    echo "[OK] Bun already installed"
fi

echo ""
echo "=== Local Config ==="
ensure_local_file "$DOTFILES/macos/Brewfile" "$DOTFILES/macos/Brewfile.local"

while IFS= read -r example; do
    local_file="${example/.example/}"
    ensure_local_file "$example" "$local_file"
done < <(find "$DOTFILES" -type f -name '*.local.example.*')

echo ""
"$DOTFILES/setup/install-core.sh"

run_brew_bundle

if [[ "$APPLY_DEFAULTS" == true && "$OS" == "Darwin" ]]; then
    echo ""
    echo "=== macOS Defaults ==="
    bash "$DOTFILES/macos/defaults.sh"
elif [[ "$OS" == "Darwin" ]]; then
    echo ""
    echo "=== macOS Defaults ==="
    echo "  [SKIP] Run later with: bash $DOTFILES/macos/defaults.sh"
fi

echo ""
echo "=== Bootstrap complete ==="
echo ""
echo "GPG import remains manual: $DOTFILES/setup/import-gpg-key.sh"
