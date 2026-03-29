# Helper functions shared by other zsh config snippets.

is_executable() {
  command -v "$1" >/dev/null 2>&1
}

append_path() {
  [[ -d "$1" ]] || return 0
  typeset -gU path
  path=($path "$1")
}

is_supported() {
    if eval "$1" >/dev/null 2>&1; then
        printf '%s\n' true
    else
        printf '%s\n' false
    fi
}
