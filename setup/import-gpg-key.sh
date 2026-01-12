#!/bin/bash
# Import GPG signing key on a new machine
# Run this AFTER transferring the key files to /tmp/

set -e

KEY_ID="BD7513ECB707E3B9B409F9C768707A773E8732A8"
KEY_FILE="${1:-/tmp/gpg-key-private.asc}"

if [[ ! -f "$KEY_FILE" ]]; then
    echo "Error: Key file not found: $KEY_FILE"
    echo "First transfer the key from a machine that has it:"
    echo "  scp /tmp/gpg-key-private.asc user@$(hostname):/tmp/"
    exit 1
fi

# Ensure pinentry-mode loopback for headless systems
if ! grep -q "pinentry-mode loopback" ~/.gnupg/gpg.conf 2>/dev/null; then
    mkdir -p ~/.gnupg
    echo "pinentry-mode loopback" >> ~/.gnupg/gpg.conf
    echo "Added pinentry-mode loopback to ~/.gnupg/gpg.conf"
fi

# Kill any stuck gpg-agent
gpgconf --kill gpg-agent 2>/dev/null || true

echo "Importing GPG key..."
gpg --import "$KEY_FILE"

echo ""
echo "Setting trust level to ultimate..."
echo -e "trust\n5\ny\nquit" | gpg --command-fd 0 --edit-key "$KEY_ID"

echo ""
echo "Configuring git signing..."
git config --global user.signingkey "$KEY_ID"
git config --global commit.gpgsign true

echo ""
echo "Cleaning up..."
rm -f /tmp/gpg-key-private.asc /tmp/gpg-key-public.asc

echo ""
echo "Done! Verifying..."
gpg --list-secret-keys --keyid-format LONG "$KEY_ID"
echo ""
git config --global user.signingkey
git config --global commit.gpgsign
