#!/usr/bin/env bash
set -euo pipefail

repoRoot="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workspaceRoot="$(dirname "$repoRoot")"
sourceRoot="${repoRoot}/.build/sources"

# CI passes explicit checkout paths and refs. Local builds default to sibling
# checkouts and archive their current HEAD unless these env vars are overridden.
apiSource="${KNOWHERE_API_SOURCE:-${workspaceRoot}/knowhere-api}"
apiRef="${KNOWHERE_API_REF:-HEAD}"
dashboardSource="${KNOWHERE_DASHBOARD_SOURCE:-${workspaceRoot}/knowhere-api-dashboard}"
dashboardRef="${KNOWHERE_DASHBOARD_REF:-HEAD}"

copySource() {
  local sourcePath="$1"
  local sourceRef="$2"
  local targetPath="$3"
  local label="$4"

  if [ ! -d "$sourcePath" ]; then
    echo "Missing ${label} source directory: ${sourcePath}" >&2
    exit 1
  fi

  rm -rf "$targetPath"
  mkdir -p "$targetPath"

  if git -C "$sourcePath" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$sourcePath" archive --format=tar "$sourceRef" | tar -xf - -C "$targetPath"
    return
  fi

  tar \
    --exclude='.git' \
    --exclude='.venv' \
    --exclude='node_modules' \
    --exclude='.next' \
    --exclude='coverage' \
    --exclude='dist' \
    -C "$sourcePath" \
    -cf - . | tar -xf - -C "$targetPath"
}

mkdir -p "$sourceRoot"
copySource "$apiSource" "$apiRef" "${sourceRoot}/knowhere-api" "Knowhere API"
copySource "$dashboardSource" "$dashboardRef" "${sourceRoot}/knowhere-api-dashboard" "Knowhere dashboard"

echo "Prepared sources:"
echo "  API:       ${apiSource} @ ${apiRef}"
echo "  Dashboard: ${dashboardSource} @ ${dashboardRef}"
