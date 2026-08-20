#!/usr/bin/env bash
set -euo pipefail

mode="${1:-audit}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
site_root="${repo_root}/dist/client"
preserve_file="${repo_root}/deploy/bluehost-preserve.txt"

: "${BLUEHOST_HOST:?Set BLUEHOST_HOST}"
: "${BLUEHOST_USER:?Set BLUEHOST_USER}"
: "${BLUEHOST_PATH:?Set BLUEHOST_PATH to the remote document root}"

if [[ "${BLUEHOST_PATH}" != /* || "${BLUEHOST_PATH}" == "/" ]]; then
  echo "BLUEHOST_PATH must be an absolute path other than /" >&2
  exit 1
fi

case "${mode}" in audit|upload|delete) ;; *)
  echo "Usage: $0 [audit|upload|delete]" >&2
  exit 2
esac

ssh_target="${BLUEHOST_USER}@${BLUEHOST_HOST}"
ssh_options=(-o BatchMode=yes -o StrictHostKeyChecking=yes)
if [[ -n "${BLUEHOST_SSH_KEY:-}" ]]; then
  ssh_options+=(-i "${BLUEHOST_SSH_KEY}")
fi

"${repo_root}/scripts/package-site.sh" "${site_root}"

mkdir -p "${repo_root}/dist/deploy-audit"
inventory="${repo_root}/dist/deploy-audit/remote-inventory.txt"
preview="${repo_root}/dist/deploy-audit/rsync-preview.txt"

ssh "${ssh_options[@]}" "${ssh_target}" \
  "cd '${BLUEHOST_PATH}' && find . -type f -print0 | sort -z | xargs -0 sha256sum" \
  > "${inventory}"
inventory_sha="$(sha256sum "${inventory}" | awk '{print $1}')"
echo "Remote inventory SHA-256: ${inventory_sha}"

rsync_args=(-az --itemize-changes --checksum)
while IFS= read -r path; do
  [[ -z "${path}" || "${path}" == \#* ]] && continue
  rsync_args+=(--filter="P /${path}")
done < "${preserve_file}"

if [[ "${mode}" == "delete" ]]; then
  : "${BLUEHOST_RECONCILED_INVENTORY_SHA256:?Set BLUEHOST_RECONCILED_INVENTORY_SHA256 after reviewing the audit artifact}"
  if [[ "${BLUEHOST_RECONCILED_INVENTORY_SHA256}" != "${inventory_sha}" ]]; then
    echo "Remote content changed since reconciliation; refusing --delete." >&2
    exit 1
  fi
  rsync_args+=(--delete --delete-delay)
fi

rsync -n "${rsync_args[@]}" -e "ssh ${ssh_options[*]}" \
  "${site_root}/" "${ssh_target}:${BLUEHOST_PATH}/" | tee "${preview}"

if [[ "${mode}" == "audit" ]]; then
  echo "Audit only; no remote files changed."
  exit 0
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_path="${BLUEHOST_PATH%/}.backup-${timestamp}.tar.gz"
ssh "${ssh_options[@]}" "${ssh_target}" \
  "tar -czf '${backup_path}' -C '${BLUEHOST_PATH}' ."
echo "Created remote backup: ${backup_path}"

rsync "${rsync_args[@]}" -e "ssh ${ssh_options[*]}" \
  "${site_root}/" "${ssh_target}:${BLUEHOST_PATH}/"
