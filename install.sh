#!/bin/bash
# Public dotfiles installer entrypoint.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "$DOTFILES/setup/bootstrap.sh" "$@"
