# Helper functions shared by other zsh config snippets.

is_executable() {
  command -v "$1" >/dev/null 2>&1
}

append_path() {
  [[ -d "$1" ]] || return 0
  typeset -gU path
  path=($path "$1")
}

# Queues a directory to be placed ahead of whatever PATH the shell already
# has (the OS/distro default), so it wins consistently in every shell —
# interactive or not. Call flush_prepend_path once after the last call; call
# order is priority order (first call = highest).
prepend_path() {
  [[ -d "$1" ]] || return 0
  typeset -ga _prepend_path_queue
  _prepend_path_queue+=("$1")
}

flush_prepend_path() {
  typeset -gU path
  path=($_prepend_path_queue $path)
  unset _prepend_path_queue
}

is_supported() {
    if eval "$1" >/dev/null 2>&1; then
        printf '%s\n' true
    else
        printf '%s\n' false
    fi
}
