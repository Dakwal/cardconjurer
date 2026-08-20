#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
site_root="${1:-${repo_root}/dist/client}"

required=(
  .htaccess
  index.html
  css
  data
  img
  js
)

for path in "${required[@]}"; do
  if [[ ! -e "${site_root}/${path}" ]]; then
    echo "Missing required site path: ${path}" >&2
    exit 1
  fi
done

for path in .git .github scripts deploy Dockerfile docker-compose.yml launcher.exe; do
  if [[ -e "${site_root}/${path}" ]]; then
    echo "Non-deployable path leaked into package: ${path}" >&2
    exit 1
  fi
done

if find "${site_root}" -name .DS_Store -print -quit | grep -q .; then
  echo "macOS .DS_Store metadata leaked into the deployable package" >&2
  exit 1
fi

if find "${site_root}" -type l -print -quit | grep -q .; then
  echo "Symlinks are not allowed in the deployable package" >&2
  exit 1
fi

file_count="$(find "${site_root}" -type f | wc -l | tr -d ' ')"
if (( file_count < 100 )); then
  echo "Package unexpectedly contains only ${file_count} files" >&2
  exit 1
fi

echo "Validated ${site_root} (${file_count} files)."
