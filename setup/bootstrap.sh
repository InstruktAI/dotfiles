#!/bin/bash
# Bootstrap dotfiles on a new machine.
#
# Usage:
#   ./install.sh                 # full setup: symlinks, defaults, Homebrew packages
#   ./install.sh --diff-apps     # show what install will add, then exit
#   ./install.sh --upgrade-apps  # safely upgrade brew packages (hold major bumps), then exit
#   ./install.sh --no-apps       # skip Homebrew package install
#   ./install.sh --no-defaults   # skip macOS defaults

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS="$(uname -s)"
SKIP_APPS=false
DIFF_APPS=false
UPGRADE_APPS=false
APPLY_DEFAULTS=true

usage() {
    cat <<'EOF'
Bootstrap dotfiles on a new machine.

Usage:
  ./install.sh                 # full setup: symlinks, defaults, Homebrew packages
  ./install.sh --diff-apps     # show what install will add, then exit
  ./install.sh --upgrade-apps  # safely upgrade brew packages (hold major bumps), then exit
  ./install.sh --no-apps       # skip Homebrew package install
  ./install.sh --no-defaults   # skip macOS defaults
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --diff-apps)
            DIFF_APPS=true
            ;;
        --upgrade-apps)
            UPGRADE_APPS=true
            ;;
        --no-apps)
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
    # pinning keeps the autoupdate agent from relinking past v24. Skip entirely
    # when node@24 is already the active node, so re-runs do not relink.
    if ! brew list --formula node@24 &>/dev/null; then
        return
    fi

    if [[ "$(node --version 2>/dev/null)" == v24.* ]]; then
        return
    fi

    if brew list --formula node &>/dev/null; then
        brew pin node 2>/dev/null || true
        brew unlink node &>/dev/null || true
    fi
    brew link --overwrite --force node@24
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

    echo "  Installing missing Brewfile.local entries (no upgrades)..."
    # --adopt lets brew take over apps already installed by hand (iTerm2,
    # VS Code, ...) when they match the cask, instead of erroring on the
    # existing artifact. A leftover mismatch (app at a different version, a
    # flaky cask) must not abort the whole bootstrap, so the run is non-fatal
    # and reported.
    if ! HOMEBREW_BUNDLE_NO_UPGRADE=1 \
        HOMEBREW_NO_INSTALL_UPGRADE=1 \
        HOMEBREW_CASK_OPTS="--adopt" \
        brew bundle install --file="$brewfile" --no-lock --no-upgrade; then
        echo "  [WARN] Some entries did not install (e.g. an app already present"
        echo "         at a different version). Continuing."
    fi
    pin_node_formula
}

diff_brew_bundle() {
    local brewfile="$DOTFILES/macos/Brewfile.local"

    if [[ "$OS" != "Darwin" ]]; then
        echo "Homebrew diff is macOS-only."
        return
    fi
    if ! command -v brew &>/dev/null; then
        echo "Homebrew is not installed."
        return
    fi
    if [[ ! -f "$brewfile" ]]; then
        echo "No Brewfile.local at $brewfile"
        return
    fi

    # What a --no-upgrade install would actually add: Brewfile entries that are
    # not installed at all. Outdated or unlinked packages are left untouched by
    # the install, so they are excluded here (unlike `brew bundle check`).
    local missing_casks missing_formulae
    missing_casks="$(comm -23 \
        <(brew bundle list --casks --file="$brewfile" 2>/dev/null | sort -u) \
        <(brew list --cask -1 2>/dev/null | sort -u))"
    missing_formulae="$(comm -23 \
        <(brew bundle list --formulae --file="$brewfile" 2>/dev/null | sort -u) \
        <(brew list --formula -1 2>/dev/null | sort -u))"

    echo "=== Homebrew: what ./install.sh will install ==="
    echo ""
    if [[ -z "$missing_casks$missing_formulae" ]]; then
        echo "Nothing - every Brewfile.local entry is already installed."
    else
        if [[ -n "$missing_casks" ]]; then
            echo "Casks:"
            printf '%s\n' "$missing_casks" | sed 's/^/  /'
        fi
        if [[ -n "$missing_formulae" ]]; then
            echo "Formulae:"
            printf '%s\n' "$missing_formulae" | sed 's/^/  /'
        fi
    fi

    echo ""
    echo "Remove anything you don't want from: $brewfile"
}

_is_breaking() {
    local inst="$1" cur="$2" im cm imn cmn rest
    im="${inst%%.*}"
    cm="${cur%%.*}"
    [[ "$im" != "$cm" ]] && return 0
    # 0.x is unstable: a minor bump there can break, so treat it as breaking.
    if [[ "$im" == "0" ]]; then
        rest="${inst#*.}"; imn="${rest%%.*}"
        rest="${cur#*.}"; cmn="${rest%%.*}"
        [[ "$imn" != "$cmn" ]] && return 0
    fi
    return 1
}

upgrade_apps() {
    if [[ "$OS" != "Darwin" ]]; then
        echo "Homebrew upgrade is macOS-only."
        return
    fi
    if ! command -v brew &>/dev/null; then
        echo "Homebrew is not installed."
        return
    fi
    if ! command -v jq &>/dev/null; then
        echo "Installing jq (needed to read brew version data)..."
        brew install jq
    fi

    echo "=== Safe Homebrew upgrade ==="
    echo "Refreshing metadata..."
    brew update >/dev/null || true

    local outdated
    outdated="$(brew outdated --json=v2 2>/dev/null || true)"

    local safe=() held=() casks=()
    local name inst cur
    while IFS=$'\t' read -r name inst cur; do
        [[ -z "$name" ]] && continue
        if _is_breaking "$inst" "$cur"; then
            held+=("$name ($inst -> $cur)")
        else
            safe+=("$name")
        fi
    done < <(printf '%s' "$outdated" | jq -r '.formulae[] | [.name, (.installed_versions[-1]), .current_version] | @tsv')

    # Casks do not use real version numbers; never auto-upgrade, always surface.
    while IFS=$'\t' read -r name inst cur; do
        [[ -z "$name" ]] && continue
        casks+=("$name ($inst -> $cur)")
    done < <(printf '%s' "$outdated" | jq -r '.casks[] | [.name, (.installed_versions[-1]), .current_version] | @tsv')

    if ((${#safe[@]} > 0)); then
        echo ""
        echo "Upgrading (same major line, treated as non-breaking):"
        printf '  %s\n' "${safe[@]}"
        brew upgrade "${safe[@]}" || echo "  [WARN] one or more upgrades failed; see output above"
    else
        echo ""
        echo "No safe (non-breaking) formula upgrades available."
    fi

    if ((${#held[@]} > 0)); then
        echo ""
        echo "HELD BACK - formula crossing a major version (possible breaking change):"
        printf '  %s\n' "${held[@]}"
    fi
    if ((${#casks[@]} > 0)); then
        echo ""
        echo "HELD BACK - casks (app version strings are not comparable; upgrade manually):"
        printf '  %s\n' "${casks[@]}"
    fi
    if ((${#held[@]} > 0 || ${#casks[@]} > 0)); then
        echo ""
        echo "Upgrade any of these yourself when ready: brew upgrade <name>"
    fi

    pin_node_formula
}

if [[ "$DIFF_APPS" == true ]]; then
    diff_brew_bundle
    exit 0
fi

if [[ "$UPGRADE_APPS" == true ]]; then
    upgrade_apps
    exit 0
fi

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
