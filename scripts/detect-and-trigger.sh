#!/bin/bash
set -euo pipefail

# Detect new upstream releases on PyPI and trigger builds in fork repos.
#
# Requires:
#   - jq: for JSON parsing
#   - curl: for PyPI API requests
#   - gh: GitHub CLI, authenticated with a token that has repo+workflow scope
#
# Environment:
#   GH_TOKEN: must be set (PAT with repo and workflow permissions)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="${SCRIPT_DIR}/../packages.json"

# Dependency checks
for cmd in jq curl gh; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd is required but not installed."
        case "$cmd" in
            jq)   echo "Install with: sudo apt-get install jq" ;;
            curl) echo "Install with: sudo apt-get install curl" ;;
            gh)   echo "Install with: https://cli.github.com/" ;;
        esac
        exit 1
    fi
done

if [ -z "${GH_TOKEN:-}" ]; then
    echo "Error: GH_TOKEN environment variable must be set."
    echo "Requires a PAT with 'repo' and 'workflow' permissions."
    exit 1
fi

if [ ! -f "$PACKAGES_FILE" ]; then
    echo "Error: packages.json not found at $PACKAGES_FILE"
    exit 1
fi

echo "Checking upstream versions on PyPI..."
echo ""

TRIGGERED=0
UPDATED_JSON=$(cat "$PACKAGES_FILE")

# Read each package entry
PACKAGE_COUNT=$(jq '.packages | length' "$PACKAGES_FILE")

for i in $(seq 0 $((PACKAGE_COUNT - 1))); do
    name=$(jq -r ".packages[$i].name" "$PACKAGES_FILE")
    current_version=$(jq -r ".packages[$i].version" "$PACKAGES_FILE")
    fork=$(jq -r ".packages[$i].fork" "$PACKAGES_FILE")
    status=$(jq -r ".packages[$i].status" "$PACKAGES_FILE")

    # Skip packages that aren't built yet
    if [ "$status" = "pending" ]; then
        printf "  %-20s  SKIPPED (status: pending)\n" "$name"
        continue
    fi

    if [ -z "$fork" ] || [ "$fork" = "null" ]; then
        printf "  %-20s  SKIPPED (no fork configured)\n" "$name"
        continue
    fi

    # Query PyPI for latest version
    pypi_data=$(curl -s "https://pypi.org/pypi/${name}/json" 2>/dev/null || echo "")

    if [ -z "$pypi_data" ] || echo "$pypi_data" | jq -e '.message' &>/dev/null; then
        printf "  %-20s  ERROR: could not fetch from PyPI\n" "$name"
        continue
    fi

    latest=$(echo "$pypi_data" | jq -r '.info.version')

    if [ "$current_version" = "$latest" ]; then
        printf "  %-20s  %-12s  up to date\n" "$name" "$current_version"
        continue
    fi

    printf "  %-20s  local: %-12s  latest: %-12s  TRIGGERING BUILD\n" "$name" "$current_version" "$latest"

    # Trigger build-riscv64.yml in the fork repo
    if gh workflow run build-riscv64.yml \
        --repo "$fork" \
        -f release_tag="v${latest}" 2>/dev/null; then
        printf "  %-20s  dispatched build-riscv64.yml in %s\n" "" "$fork"
        TRIGGERED=$((TRIGGERED + 1))
    else
        printf "  %-20s  WARN: failed to dispatch workflow in %s\n" "" "$fork"
        printf "  %-20s  (workflow may not exist yet or token lacks permissions)\n" ""
    fi

    # Update version in JSON
    UPDATED_JSON=$(echo "$UPDATED_JSON" | jq \
        --arg idx "$i" --arg ver "$latest" \
        '.packages[$idx | tonumber].version = $ver')
done

echo ""
echo "Triggered $TRIGGERED build(s)."

# Write updated versions back to packages.json if anything changed
if [ "$TRIGGERED" -gt 0 ]; then
    echo "$UPDATED_JSON" | jq '.' > "$PACKAGES_FILE"
    echo "Updated packages.json with new versions."
    echo ""
    echo "Note: Remember to commit and push the updated packages.json."
fi
