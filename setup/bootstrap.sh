#!/bin/bash
# Bootstrap dotfiles on a new machine
# Run this AFTER Syncthing has synced ~/Sync/dotfiles/

set -e

DOTFILES="$HOME/Sync/dotfiles"

if [[ ! -d "$DOTFILES" ]]; then
    echo "Error: $DOTFILES not found"
    echo "Set up Syncthing first and sync the dotfiles folder"
    exit 1
fi

echo "Creating symlinks..."

# Zsh config
rm -rf ~/.config/zsh
ln -sf "$DOTFILES/zsh" ~/.config/zsh
echo "  ~/.config/zsh -> $DOTFILES/zsh"

# Tmux
ln -sf "$DOTFILES/tmux.conf" ~/.tmux.conf
echo "  ~/.tmux.conf -> $DOTFILES/tmux.conf"

# Git
ln -sf "$DOTFILES/gitconfig" ~/.gitconfig
ln -sf "$DOTFILES/gitignore_global" ~/.gitignore_global
echo "  ~/.gitconfig -> $DOTFILES/gitconfig"
echo "  ~/.gitignore_global -> $DOTFILES/gitignore_global"

# SSH (careful - don't overwrite keys)
mkdir -p ~/.ssh
if [[ -f ~/.ssh/config && ! -L ~/.ssh/config ]]; then
    mv ~/.ssh/config ~/.ssh/config.backup
    echo "  Backed up existing ~/.ssh/config"
fi
ln -sf "$DOTFILES/ssh/config" ~/.ssh/config
echo "  ~/.ssh/config -> $DOTFILES/ssh/config"

# Shell
ln -sf "$DOTFILES/inputrc" ~/.inputrc
echo "  ~/.inputrc -> $DOTFILES/inputrc"

# Editor
ln -sf "$DOTFILES/editorconfig" ~/.editorconfig
ln -sf "$DOTFILES/vimrc" ~/.vimrc
ln -sf "$DOTFILES/nanorc" ~/.nanorc
echo "  ~/.editorconfig -> $DOTFILES/editorconfig"
echo "  ~/.vimrc -> $DOTFILES/vimrc"
echo "  ~/.nanorc -> $DOTFILES/nanorc"

# CLI tools
mkdir -p ~/.config/gh ~/.config/glow
ln -sf "$DOTFILES/config/gh/config.yml" ~/.config/gh/config.yml
ln -sf "$DOTFILES/config/glow/glow.yml" ~/.config/glow/glow.yml
echo "  ~/.config/gh/config.yml -> $DOTFILES/config/gh/config.yml"
echo "  ~/.config/glow/glow.yml -> $DOTFILES/config/glow/glow.yml"

echo ""
echo "Symlinks created!"
echo ""
echo "Remaining manual steps:"
echo "1. Update ~/.zshrc to source from ~/.config/zsh/ (if not already)"
echo "2. Import GPG key: $DOTFILES/setup/import-gpg-key.sh"
echo "   (First transfer key: scp /tmp/gpg-key-private.asc user@$(hostname):/tmp/)"
