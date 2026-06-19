#!/bin/bash
# macOS system defaults - curated for modern macOS (Sequoia/Tahoe).
# The installer runs this tracked file directly. Machine-specific overrides
# (locale, etc.) live in macos/defaults.local.sh and are sourced at the end.
# Run once on a new machine, or re-run to reset preferences.
# Idempotent: safe to run multiple times.

set -euo pipefail

echo "Applying macOS defaults..."

# Close System Settings to prevent overrides (renamed from System Preferences
# in macOS Ventura; the old name is kept as a fallback for older systems).
osascript -e 'tell application "System Settings" to quit' 2>/dev/null ||
    osascript -e 'tell application "System Preferences" to quit' 2>/dev/null ||
    true

# Some app preference domains (Safari, Mail, ...) live inside sandboxed app
# containers that modern macOS protects with TCC. Writing them only succeeds
# when the terminal running this script has Full Disk Access. macOS exposes no
# API to self-grant it, so the best we can do is open the exact settings pane,
# name the app to enable, and block until the domain is actually writable.

# Full Disk Access pane in System Settings (Privacy & Security).
FDA_PANE="x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"

# Best-effort name of the app the user must grant Full Disk Access to.
fda_app_name() {
    case "${TERM_PROGRAM:-}" in
        Apple_Terminal) echo "Terminal" ;;
        iTerm.app) echo "iTerm" ;;
        vscode) echo "Visual Studio Code (and Code Helper)" ;;
        WezTerm) echo "WezTerm" ;;
        ghostty) echo "Ghostty" ;;
        tmux) echo "your terminal app (you are running under tmux)" ;;
        "") echo "your terminal app" ;;
        *) echo "$TERM_PROGRAM" ;;
    esac
}

domain_writable() {
    local domain="$1"
    if defaults write "$domain" InstruktDotfilesProbe -bool true 2>/dev/null; then
        defaults delete "$domain" InstruktDotfilesProbe 2>/dev/null || true
        return 0
    fi
    return 1
}

# Block until a sandboxed preference domain is writable. Not optional: the run
# does not continue until Full Disk Access is granted.
require_domain_writable() {
    local domain="$1"
    local app
    app="$(fda_app_name)"

    domain_writable "$domain" && return 0

    echo ""
    echo "  [ACTION REQUIRED] Writing '$domain' needs Full Disk Access for $app."
    echo "  Opening System Settings -> Privacy & Security -> Full Disk Access..."
    open "$FDA_PANE" 2>/dev/null || true
    osascript >/dev/null 2>&1 <<OSA || true
display dialog "Full Disk Access is required to apply '$domain' settings.

In the window that just opened:
  1. Enable (or add with the + button) \"$app\".
  2. Full Disk Access changes usually need the terminal to be quit & reopened.

Click OK after enabling it." buttons {"OK"} default button "OK" with title "Dotfiles setup"
OSA

    local attempts=0
    until domain_writable "$domain"; do
        attempts=$((attempts + 1))
        if ((attempts > 10)); then
            echo "  [STOP] '$domain' still not writable." >&2
            echo "         Full Disk Access changes require quitting and reopening" >&2
            echo "         $app. Do that, then re-run this script." >&2
            exit 1
        fi
        read -r -p "  Press Enter after enabling Full Disk Access (Ctrl-C to abort)... " _ || exit 1
    done
    echo "  [OK] '$domain' is now writable"
}

# =============================================================================
# General UI/UX
# =============================================================================

# Reduce window resize animation to near-instant
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Quit printer app after print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Disable the "Are you sure you want to open this application?" dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Disable auto-termination of inactive apps
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true

# =============================================================================
# Keyboard & Input
# =============================================================================

# Fastest key repeat
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 10

# Disable smart quotes (annoying in terminals/code)
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable smart dashes
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Enable full keyboard access for all controls (Tab through all UI elements)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# =============================================================================
# Trackpad
# =============================================================================

# Enable tap to click (this user and login screen)
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# =============================================================================
# Screen
# =============================================================================

# Require password immediately after sleep or screen saver
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Screenshots: save to ~/Desktop, PNG format, no shadows
defaults write com.apple.screencapture location -string "$HOME/Desktop"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# =============================================================================
# Finder
# =============================================================================

# Allow quitting via Cmd+Q (hides desktop icons)
defaults write com.apple.finder QuitMenuItem -bool true

# Show hidden files by default
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Display full POSIX path in title bar
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable warning when changing file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Enable spring loading for directories
defaults write NSGlobalDomain com.apple.springing.enabled -bool true
defaults write NSGlobalDomain com.apple.springing.delay -float 0

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Use list view in all Finder windows by default
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Disable warning before emptying Trash
defaults write com.apple.finder WarnOnEmptyTrash -bool false

# =============================================================================
# Dock
# =============================================================================

# Set icon size to 48 pixels
defaults write com.apple.dock tilesize -int 48

# Minimize windows into their app icon
defaults write com.apple.dock minimize-to-application -bool true

# Show indicator lights for open apps
defaults write com.apple.dock show-process-indicators -bool true

# Auto-hide the Dock with zero delay
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0

# Don't auto-rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# Make hidden app icons translucent
defaults write com.apple.dock showhidden -bool true

# Hot corner: bottom-left → put display to sleep
defaults write com.apple.dock wvous-bl-corner -int 10
defaults write com.apple.dock wvous-bl-modifier -int 0

# =============================================================================
# Safari (Developer)
# =============================================================================

# Enable Develop menu and Web Inspector (sandboxed domain; needs Full Disk Access)
require_domain_writable com.apple.Safari
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

# Enable context menu item for Web Inspector (global domain, not sandboxed)
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

# =============================================================================
# Mail
# =============================================================================

# Copy addresses as "foo@bar.com" instead of "Foo Bar <foo@bar.com>"
# (sandboxed domain; needs Full Disk Access)
require_domain_writable com.apple.mail
defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false

# =============================================================================
# Time Machine
# =============================================================================

# Don't prompt to use new hard drives as backup volume
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# =============================================================================
# TextEdit
# =============================================================================

# Use plain text mode by default
defaults write com.apple.TextEdit RichText -int 0

# Open and save files as UTF-8
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

# =============================================================================
# Mac App Store
# =============================================================================

# Enable WebKit Developer Tools in Mac App Store
defaults write com.apple.appstore WebKitDeveloperExtras -bool true

# =============================================================================
# Machine-specific overrides
# =============================================================================

MACOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$MACOS_DIR/defaults.local.sh" ]]; then
    echo "Applying machine-specific overrides..."
    # shellcheck source=/dev/null
    source "$MACOS_DIR/defaults.local.sh"
fi

# =============================================================================
# Restart affected applications
# =============================================================================

echo "Restarting affected applications..."
for app in "Finder" "Dock" "Mail" "SystemUIServer"; do
    killall "$app" &>/dev/null || true
done

echo "Done. Some changes require a logout/restart to take effect."
