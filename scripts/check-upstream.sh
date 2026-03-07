#!/bin/bash
set -euo pipefail

# Check for new upstream versions of tracked packages

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="${SCRIPT_DIR}/../packages.json"

if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed."
    echo "Install with: sudo apt-get install jq"
    exit 1
fi

if ! command -v curl &>/dev/null; then
    echo "Error: curl is required but not installed."
    echo "Install with: sudo apt-get install curl"
    exit 1
fi

if [ ! -f "$PACKAGES_FILE" ]; then
    echo "Error: packages.json not found at $PACKAGES_FILE"
    exit 1
fi

echo "Checking upstream versions on PyPI..."
echo ""

UPDATES=0
PACKAGES=$(jq -r '.packages[] | "\(.name)|\(.version)"' "$PACKAGES_FILE")

while IFS='|' read -r name current_version; do
    pypi_data=$(curl -s "https://pypi.org/pypi/${name}/json" 2>/dev/null || echo "")

    if [ -z "$pypi_data" ] || echo "$pypi_data" | jq -e '.message' &>/dev/null; then
        printf "  %-20s  ERROR: could not fetch from PyPI\n" "$name"
        continue
    fi

    latest=$(echo "$pypi_data" | jq -r '.info.version')

    if [ "$current_version" = "null" ] || [ -z "$current_version" ]; then
        printf "  %-20s  latest: %-12s  (no local version set)\n" "$name" "$latest"
        UPDATES=$((UPDATES + 1))
    elif [ "$current_version" != "$latest" ]; then
        printf "  %-20s  local: %-12s  latest: %-12s  UPDATE AVAILABLE\n" "$name" "$current_version" "$latest"
        UPDATES=$((UPDATES + 1))
    else
        printf "  %-20s  %-12s  up to date\n" "$name" "$current_version"
    fi
done <<< "$PACKAGES"

echo ""
if [ "$UPDATES" -gt 0 ]; then
    echo "$UPDATES package(s) have updates available or need version pinning."
    echo ""
    echo "To build an updated wheel:"
    echo "  ./scripts/build-from-source.sh PACKAGE_NAME"
else
    echo "All packages are up to date."
fi
