#!/bin/bash
set -euo pipefail

# Aggregate riscv64 wheels from fork repo releases into a central release.
#
# For each package in packages.json:
#   1. Check the fork repo for GitHub Releases with riscv64 wheels
#   2. Download any wheels not already in our central release
#   3. Create or update the central release with all wheels
#
# Requires: gh (authenticated), jq, curl

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="${SCRIPT_DIR}/../packages.json"
WHEELS_DIR="${SCRIPT_DIR}/../wheels"
CENTRAL_REPO="gounthar/riscv64-python-wheels"

# Dependency checks
for cmd in jq gh; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd is required but not installed."
        exit 1
    fi
done

if [ ! -f "$PACKAGES_FILE" ]; then
    echo "Error: packages.json not found at $PACKAGES_FILE"
    exit 1
fi

mkdir -p "$WHEELS_DIR"

# Get existing wheels in the latest central release
echo "Checking existing central release..."
EXISTING_WHEELS=""
LATEST_TAG=$(gh release list --repo "$CENTRAL_REPO" --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null || echo "")

if [ -n "$LATEST_TAG" ]; then
    echo "  Latest release: $LATEST_TAG"
    EXISTING_WHEELS=$(gh release view "$LATEST_TAG" --repo "$CENTRAL_REPO" --json assets --jq '.assets[].name' 2>/dev/null || echo "")
    # Download existing wheels so we have a complete set
    if [ -n "$EXISTING_WHEELS" ]; then
        echo "  Downloading existing wheels..."
        gh release download "$LATEST_TAG" --repo "$CENTRAL_REPO" --dir "$WHEELS_DIR" --pattern "*.whl" 2>/dev/null || true
    fi
else
    echo "  No existing release found."
fi

# Scan each fork repo for new wheels
echo ""
echo "Scanning fork repos for new wheels..."
PACKAGE_COUNT=$(jq '.packages | length' "$PACKAGES_FILE")
NEW_WHEELS=0

for i in $(seq 0 $((PACKAGE_COUNT - 1))); do
    name=$(jq -r ".packages[$i].name" "$PACKAGES_FILE")
    fork=$(jq -r ".packages[$i].fork" "$PACKAGES_FILE")

    if [ -z "$fork" ] || [ "$fork" = "null" ]; then
        continue
    fi

    printf "  %-20s  checking %s..." "$name" "$fork"

    # List releases in the fork
    FORK_RELEASES=$(gh release list --repo "$fork" --json tagName --jq '.[].tagName' 2>/dev/null || echo "")

    if [ -z "$FORK_RELEASES" ]; then
        printf " no releases\n"
        continue
    fi

    FOUND=0
    for tag in $FORK_RELEASES; do
        # Get wheel assets from this release
        ASSETS=$(gh release view "$tag" --repo "$fork" --json assets --jq '.assets[] | select(.name | endswith(".whl")) | .name' 2>/dev/null || echo "")

        for asset_name in $ASSETS; do
            if [ -z "$asset_name" ]; then
                continue
            fi

            # Check if we already have a wheel with this name
            if [ -f "$WHEELS_DIR/$asset_name" ]; then
                # Compare sizes: fork's version wins if different (rebuilt wheel)
                FORK_SIZE=$(gh release view "$tag" --repo "$fork" --json assets \
                    --jq ".assets[] | select(.name == \"$asset_name\") | .size" 2>/dev/null || echo "0")
                LOCAL_SIZE=$(stat -c%s "$WHEELS_DIR/$asset_name" 2>/dev/null || echo "0")
                if [ "$FORK_SIZE" = "$LOCAL_SIZE" ]; then
                    continue
                fi
                echo ""
                printf "    %-20s  size changed (%s -> %s), replacing\n" "$asset_name" "$LOCAL_SIZE" "$FORK_SIZE"
                rm -f "$WHEELS_DIR/$asset_name"
            fi

            # Download the wheel from fork
            gh release download "$tag" --repo "$fork" --dir "$WHEELS_DIR" --pattern "$asset_name" 2>/dev/null || true

            if [ -f "$WHEELS_DIR/$asset_name" ]; then
                FOUND=$((FOUND + 1))
                NEW_WHEELS=$((NEW_WHEELS + 1))
            fi
        done
    done

    if [ "$FOUND" -gt 0 ]; then
        printf " +%d new wheel(s)\n" "$FOUND"
    else
        printf " up to date\n"
    fi
done

echo ""

# Count total wheels
TOTAL=$(find "$WHEELS_DIR" -name "*.whl" 2>/dev/null | wc -l)
echo "Total wheels: $TOTAL ($NEW_WHEELS new)"

if [ "$TOTAL" -eq 0 ]; then
    echo "No wheels found. Nothing to release."
    exit 0
fi

# Generate checksums
cd "$WHEELS_DIR"
sha256sum *.whl > SHA256SUMS 2>/dev/null || true

# Create or update central release
RELEASE_TAG="v$(date -u +%Y.%m.%d)-cp313"
RELEASE_TITLE="riscv64 wheels for CPython 3.13 ($(date -u +%Y-%m-%d))"

echo ""
echo "Creating/updating release: $RELEASE_TAG"

# Build package table for release notes
PACKAGE_TABLE=""
for whl in *.whl; do
    [ "$whl" = "*.whl" ] && continue
    pkg_name=$(echo "$whl" | sed 's/-[0-9].*//' | tr '_' '-')
    pkg_version=$(echo "$whl" | sed 's/^[^-]*-\([^-]*\)-.*/\1/')
    abi=$(echo "$whl" | sed 's/.*-\(cp[^-]*\)-.*riscv64.whl/\1/')
    PACKAGE_TABLE="${PACKAGE_TABLE}| ${pkg_name} | ${pkg_version} | ${abi} |\n"
done

RELEASE_NOTES=$(cat <<NOTES
Prebuilt Python wheels for RISC-V 64-bit (riscv64) Linux.

## Packages

| Package | Version | ABI |
|---------|---------|-----|
$(echo -e "$PACKAGE_TABLE")
## Build hardware

BananaPi F3 (SpacemiT K1, 8x rv64imafdcv @ 1.6 GHz, RVV 1.0 vlen=256, 16 GB RAM)

## Install

\`\`\`bash
pip install PACKAGE --extra-index-url https://gounthar.github.io/riscv64-python-wheels/simple/
\`\`\`

Or install directly from this release:
\`\`\`bash
pip install PACKAGE --find-links https://github.com/gounthar/riscv64-python-wheels/releases/expanded_assets/${RELEASE_TAG}
\`\`\`

## Checksums

See SHA256SUMS file attached to this release.
NOTES
)

# Delete existing release with same tag if it exists
gh release delete "$RELEASE_TAG" --repo "$CENTRAL_REPO" --yes 2>/dev/null || true

# Create release
gh release create "$RELEASE_TAG" \
    --repo "$CENTRAL_REPO" \
    --title "$RELEASE_TITLE" \
    --notes "$RELEASE_NOTES" \
    *.whl SHA256SUMS

echo ""
echo "Release published: https://github.com/$CENTRAL_REPO/releases/tag/$RELEASE_TAG"
