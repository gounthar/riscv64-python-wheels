#!/bin/bash
set -euo pipefail

# Extract riscv64 wheels from pip cache

TARGET_DIR="${1:-$HOME/wheels}"

if ! command -v pip &>/dev/null; then
    echo "Error: pip is required but not installed."
    echo "Install with: sudo apt-get install python3-pip"
    exit 1
fi

mkdir -p "$TARGET_DIR"

echo "Searching pip cache for riscv64 wheels..."
WHEELS=$(pip cache list --format=abspath 2>/dev/null | grep linux_riscv64 || true)

if [ -z "$WHEELS" ]; then
    echo "No riscv64 wheels found in pip cache."
    echo ""
    echo "To build wheels from source, use:"
    echo "  ./scripts/build-from-source.sh PACKAGE_NAME"
    echo ""
    echo "Or install a package and wheels will appear in cache:"
    echo "  pip install --no-binary :all: PACKAGE_NAME"
    exit 0
fi

COUNT=0
while IFS= read -r wheel; do
    cp "$wheel" "$TARGET_DIR/"
    echo "  Copied: $(basename "$wheel")"
    COUNT=$((COUNT + 1))
done <<< "$WHEELS"

echo ""
echo "Copied $COUNT wheel(s) to $TARGET_DIR"

echo ""
echo "Generating SHA256SUMS..."
cd "$TARGET_DIR"
sha256sum *.whl > SHA256SUMS 2>/dev/null || echo "No .whl files to checksum"
echo "Done. SHA256SUMS written to $TARGET_DIR/SHA256SUMS"
