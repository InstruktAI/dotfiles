# Helper functions shared by other zsh config snippets.

is_executable() {
  command -v "$1" >/dev/null 2>&1
}

prepend_path() {
  [[ -d "$1" ]] || return 0
  typeset -gU path
  path=("$1" $path)
}

is_supported() {
    if eval "$1" >/dev/null 2>&1; then
        printf '%s\n' true
    else
        printf '%s\n' false
    fi
}
