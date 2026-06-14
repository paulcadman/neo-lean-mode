#!/usr/bin/env bash
#
# Update data/abbreviations.json from its canonical upstream, the VS Code
# Lean 4 extension (leanprover/vscode-lean4, Apache-2.0).
#
# Usage:
#   data/update-abbreviations.sh [REF]
#
# REF is a branch, tag, or commit to pull from (default: master). Example:
#   data/update-abbreviations.sh v0.0.200
#
# The fetched file is validated as a non-empty JSON object before it
# replaces the vendored copy, so a transient/garbled download cannot clobber
# the good file.

set -euo pipefail

REF="${1:-master}"
REPO="leanprover/vscode-lean4"
SRC_PATH="lean4-unicode-input/src/abbreviations.json"
URL="https://raw.githubusercontent.com/${REPO}/${REF}/${SRC_PATH}"

# The script lives next to the data file it maintains.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${DIR}/abbreviations.json"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

echo "Fetching ${URL}"
curl -fsSL "$URL" -o "$tmp"

# Validate: must be a non-empty JSON object.
if command -v jq >/dev/null 2>&1; then
  jq -e 'type == "object" and length > 0' "$tmp" >/dev/null \
    || { echo "error: not a non-empty JSON object" >&2; exit 1; }
  echo "Validated: $(jq 'length' "$tmp") entries."
elif command -v python3 >/dev/null 2>&1; then
  python3 -c 'import json,sys
d = json.load(open(sys.argv[1]))
assert isinstance(d, dict) and d, "not a non-empty JSON object"
print(f"Validated: {len(d)} entries.")' "$tmp"
else
  [ -s "$tmp" ] || { echo "error: empty download" >&2; exit 1; }
  echo "warning: install jq or python3 to validate JSON content" >&2
fi

if [ -f "$DEST" ] && cmp -s "$tmp" "$DEST"; then
  echo "Up to date: $(basename "$DEST") unchanged."
else
  mv "$tmp" "$DEST"
  trap - EXIT
  echo "Updated: $(basename "$DEST")"
fi
