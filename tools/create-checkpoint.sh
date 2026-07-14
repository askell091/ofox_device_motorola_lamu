#!/usr/bin/env bash

set -Eeuo pipefail

if (( $# < 2 || $# > 3 )); then
  echo "Usage: $0 <phase-name> <build-file-or-directory> [backup-root]" >&2
  exit 2
fi

phase="$1"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -e "$2" ]]; then
  echo "Build source does not exist: $2" >&2
  exit 1
fi
build_source="$(realpath "$2")"
backup_root="$(realpath -m "${3:-$(realpath "$repo_root/../../..")/Backups}")"

safe_phase="$(printf '%s' "$phase" | tr -cs 'A-Za-z0-9._-' '-')"
safe_phase="${safe_phase#-}"
safe_phase="${safe_phase%-}"
if [[ -z "$safe_phase" ]]; then
  echo "Phase name must contain at least one letter or number." >&2
  exit 1
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
checkpoint="${timestamp}-${safe_phase}"
tree_destination="$backup_root/Device Tree/$checkpoint"
build_destination="$backup_root/Builds/$checkpoint"

if [[ -e "$tree_destination" || -e "$build_destination" ]]; then
  echo "Checkpoint already exists: $checkpoint" >&2
  exit 1
fi

mkdir -p "$tree_destination" "$build_destination"
rsync -a --exclude=.git --exclude=checkpoint "$repo_root/" "$tree_destination/"

if [[ -d "$build_source" ]]; then
  cp -a "$build_source/." "$build_destination/"
else
  cp -a "$build_source" "$build_destination/"
fi

commit="uncommitted"
if git -C "$repo_root" rev-parse HEAD >/dev/null 2>&1; then
  commit="$(git -C "$repo_root" rev-parse HEAD)"
fi

cat > "$tree_destination/CHECKPOINT.txt" <<EOF
phase=$phase
created_at=$(date --iso-8601=seconds)
device_tree_commit=$commit
build_source=$build_source
EOF

(
  cd "$build_destination"
  find . -type f ! -name SHA256SUMS -print0 \
    | sort -z \
    | xargs -0 -r sha256sum > SHA256SUMS
)

echo "Saved device tree: $tree_destination"
echo "Saved build:       $build_destination"
