#!/usr/bin/env sh
# axon installer
# Usage (Linux / macOS):
#   curl -fsSL https://raw.githubusercontent.com/suphakin-th/axon/main/install.sh | sudo sh
#
# Or without sudo (installs to ~/bin):
#   curl -fsSL https://raw.githubusercontent.com/suphakin-th/axon/main/install.sh | sh

set -e

VERSION="1.0.0"
REPO="suphakin-th/axon"
BIN_URL="https://raw.githubusercontent.com/${REPO}/main/bin/axon"

# Determine install directory
if [ "$(id -u)" -eq 0 ]; then
    INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
else
    INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
    mkdir -p "$INSTALL_DIR"
fi

INSTALL_PATH="${INSTALL_DIR}/axon"

echo "Installing axon v${VERSION} to ${INSTALL_PATH} ..."

# Download binary
if command -v curl > /dev/null 2>&1; then
    curl -fsSL "$BIN_URL" -o "$INSTALL_PATH"
elif command -v wget > /dev/null 2>&1; then
    wget -qO "$INSTALL_PATH" "$BIN_URL"
else
    echo "Error: curl or wget is required." >&2
    exit 1
fi

chmod +x "$INSTALL_PATH"

echo "axon v${VERSION} installed."
echo ""

# Remind non-root users to check PATH
if [ "$(id -u)" -ne 0 ]; then
    echo "Make sure ${INSTALL_DIR} is in your PATH:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    echo "Add the line above to ~/.bashrc or ~/.zshrc to make it permanent."
    echo ""
fi

echo "Run 'axon help' to get started."
