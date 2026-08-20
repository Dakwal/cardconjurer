#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
destination="${1:-${repo_root}/dist/client}"

case "${destination}" in
  "${repo_root}/dist/client"|"${repo_root}/dist/client/"*) ;;
  *)
    echo "Refusing to package outside ${repo_root}/dist/client" >&2
    exit 1
    ;;
esac

mkdir -p "${destination}"

# Card Conjurer is already a static site. Copy it without transforming its
# HTML, CSS, JavaScript, data, assets, or Apache configuration.
rsync -a --delete --delete-excluded \
  --exclude '/.git/' \
  --exclude '/.github/' \
  --exclude '/.gitignore' \
  --exclude '/.dockerignore' \
  --exclude '.DS_Store' \
  --exclude '/dist/' \
  --exclude '/scripts/' \
  --exclude '/deploy/' \
  --exclude '/Dockerfile' \
  --exclude '/Makefile' \
  --exclude '/README.md' \
  --exclude '/app.conf' \
  --exclude '/docker/' \
  --exclude '/docker-compose.yml' \
  --exclude '/docker-compose.override.example.yml' \
  --exclude '/launcher-linux' \
  --exclude '/launcher-macos' \
  --exclude '/launcher.exe' \
  --exclude '/launcher.py' \
  --exclude '/launcher.spec' \
  --exclude '/local_art/.gitignore' \
  "${repo_root}/" "${destination}/"

"${repo_root}/scripts/validate-package.sh" "${destination}"
