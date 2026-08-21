#!/usr/bin/env bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$repo_root/prebuilts/SHA256SUMS"
mode="${1:---check}"

case "$mode" in
  --write)
    (
      cd "$repo_root"
      find prebuilts recovery/root/vendor/firmware \
        -type f ! -name SHA256SUMS -print0 \
        | sort -z \
        | xargs -0 -r sha256sum > "$manifest"
    )
    echo "Wrote $manifest"
    ;;
  --check)
    cd "$repo_root"
    sha256sum --check "${manifest#$repo_root/}"
    ;;
  *)
    echo "Usage: $0 [--check|--write]" >&2
    exit 2
    ;;
esac
