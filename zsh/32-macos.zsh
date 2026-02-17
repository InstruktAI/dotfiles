# macOS-specific aliases and functions.
[[ "$OSTYPE" == darwin* ]] || return

# DNS
alias flushdns="sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"

# Lock screen / screensaver
alias afk="open /System/Library/CoreServices/ScreenSaver.engine"

# Desktop icons
alias desktopshow="defaults write com.apple.finder CreateDesktop -bool true && killfinder"
alias desktophide="defaults write com.apple.finder CreateDesktop -bool false && killfinder"

# Cleanup
alias emptytrash="sudo rm -rfv /Volumes/*/.Trashes; sudo rm -rfv ~/.Trash; sudo rm -rfv /private/var/log/asl/*.asl"
alias lscleanup="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killfinder"

# Open man page as PDF in Preview
manpdf() { man -t "$@" | open -f -a Preview; }

# Reveal file(s) in Finder
show() {
    osascript -e 'tell app "Finder" to set frontmost to true'
    open -R "${@:-.}"
}
