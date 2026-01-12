#!/bin/bash
# Export GPG signing key to transfer to another machine
# Run this on a machine that already has the key

set -e

KEY_ID="BD7513ECB707E3B9B409F9C768707A773E8732A8"
EXPORT_DIR="${1:-/tmp}"

echo "Exporting GPG key ${KEY_ID}..."
gpg --export-secret-keys --armor "$KEY_ID" > "${EXPORT_DIR}/gpg-key-private.asc"
gpg --export --armor "$KEY_ID" > "${EXPORT_DIR}/gpg-key-public.asc"

echo ""
echo "Keys exported to:"
echo "  ${EXPORT_DIR}/gpg-key-private.asc"
echo "  ${EXPORT_DIR}/gpg-key-public.asc"
echo ""
echo "Transfer to target machine:"
echo "  scp ${EXPORT_DIR}/gpg-key-*.asc user@hostname:/tmp/"
echo ""
echo "Then run on target: ~/Sync/dotfiles/setup/import-gpg-key.sh"
