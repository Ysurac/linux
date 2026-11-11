#!/usr/bin/env bash
set -euo pipefail

PATCH_URL="${1:?patch URL required}"
PATCH_LABEL="${2:?patch label required}"

normalize_url() {
  local url="$1"
  if [[ "${url}" == *"github.com"*"/blob/"* ]]; then
    echo "${url}" | sed -E 's#https://github.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)#https://raw.githubusercontent.com/\1/\2/\3/\4#'
    return
  fi
  echo "${url}"
}

if ! git config --get user.name >/dev/null; then
  git config user.name "github-actions[bot]"
fi

if ! git config --get user.email >/dev/null; then
  git config user.email "github-actions[bot]@users.noreply.github.com"
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

patch_file="${tmp_dir}/patch"
curl -fL "$(normalize_url "${PATCH_URL}")" -o "${patch_file}"
if [[ "${PATCH_URL}" == *.xz ]]; then
  mv "${patch_file}" "${patch_file}.xz"
  unxz "${patch_file}.xz"
fi

echo "Applying ${PATCH_LABEL}"

if git am --3way "${patch_file}"; then
  exit 0
fi

git am --abort || true

if git apply --check "${patch_file}"; then
  git apply "${patch_file}"
  git add -A
  git commit -m "Apply ${PATCH_LABEL}"
  exit 0
fi

if patch -p1 --forward --no-backup-if-mismatch < "${patch_file}"; then
  git add -A
  git commit -m "Apply ${PATCH_LABEL}"
  exit 0
fi

echo "Failed to apply ${PATCH_LABEL}"
exit 1
