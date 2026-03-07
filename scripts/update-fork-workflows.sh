#!/bin/bash
set -euo pipefail

# Update build-riscv64.yml in all fork repos to add a dispatch callback
# that triggers index regeneration in the central repo after publishing.
#
# This adds a final job that sends a repository_dispatch event to
# gounthar/riscv64-python-wheels so the PEP 503 index gets updated
# immediately after a new wheel is published.
#
# Requires: gh (authenticated with DISPATCH_TOKEN or equivalent PAT)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="${SCRIPT_DIR}/../packages.json"
BRANCH="ci/add-index-callback"

if [ ! -f "$PACKAGES_FILE" ]; then
    echo "Error: packages.json not found"
    exit 1
fi

# Dependency check
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed."
    echo "Install with: sudo apt-get install jq"
    exit 1
fi

# Read fork repos from packages.json
FORKS=$(jq -r '.packages[].fork' "$PACKAGES_FILE" | sort -u | grep -v '^null$')

CALLBACK_JOB='
  notify-index:
    needs: release
    runs-on: ubuntu-latest
    if: success()
    steps:
      - name: Trigger index update
        continue-on-error: true
        env:
          GH_TOKEN: ${{ secrets.DISPATCH_TOKEN }}
        run: |
          gh api repos/gounthar/riscv64-python-wheels/dispatches \
            -f event_type=fork-release-published \
            -f "client_payload[repo]=${{ github.repository }}" \
            -f "client_payload[tag]=${{ github.ref_name }}"'

echo "Adding index callback to fork workflows..."
echo ""

for fork in $FORKS; do
    repo_name=$(basename "$fork")
    printf "%-25s " "$repo_name"

    # Check if workflow exists
    WORKFLOW=$(gh api "repos/$fork/contents/.github/workflows/build-riscv64.yml" 2>/dev/null || echo "")
    if [ -z "$WORKFLOW" ] || echo "$WORKFLOW" | jq -e '.message' &>/dev/null; then
        echo "SKIP (no workflow)"
        continue
    fi

    # Get current content
    CONTENT=$(echo "$WORKFLOW" | jq -r '.content' | tr -d '\n' | base64 -d)
    SHA=$(echo "$WORKFLOW" | jq -r '.sha')

    # Check if callback already exists
    if echo "$CONTENT" | grep -q "notify-index"; then
        echo "already has callback"
        continue
    fi

    # Append the callback job
    UPDATED="${CONTENT}${CALLBACK_JOB}
"

    # Get default branch
    DEFAULT_BRANCH=$(gh api "repos/$fork" --jq '.default_branch' 2>/dev/null)

    # Get the SHA of the default branch head
    BRANCH_SHA=$(gh api "repos/$fork/git/ref/heads/$DEFAULT_BRANCH" --jq '.object.sha' 2>/dev/null)

    # Check if our branch exists, delete if so
    gh api -X DELETE "repos/$fork/git/refs/heads/$BRANCH" 2>/dev/null || true

    # Create branch
    gh api "repos/$fork/git/refs" \
        -f ref="refs/heads/$BRANCH" \
        -f sha="$BRANCH_SHA" > /dev/null 2>&1

    # Update file on branch
    ENCODED=$(echo "$UPDATED" | base64 -w0)
    gh api "repos/$fork/contents/.github/workflows/build-riscv64.yml" \
        -X PUT \
        -f message="ci: add index update callback after release" \
        -f content="$ENCODED" \
        -f sha="$SHA" \
        -f branch="$BRANCH" > /dev/null 2>&1

    # Create PR
    PR_URL=$(gh pr create --repo "$fork" \
        --head "$BRANCH" \
        --base "$DEFAULT_BRANCH" \
        --title "ci: notify central index after wheel release" \
        --body "$(cat <<'PREOF'
## Summary

Add a `notify-index` job to the riscv64 build workflow that triggers
index regeneration in `gounthar/riscv64-python-wheels` after a new
wheel release is published.

This ensures the PEP 503 package index at
https://gounthar.github.io/riscv64-python-wheels/simple/ is updated
immediately when new wheels become available, rather than waiting for
the daily cron.

## Changes

- Add `notify-index` job that sends `repository_dispatch` to the
  central wheels repo after the `release` job succeeds
PREOF
)" 2>&1)

    echo "PR: $PR_URL"
done

echo ""
echo "Done. Review and merge the PRs to enable automatic index updates."
