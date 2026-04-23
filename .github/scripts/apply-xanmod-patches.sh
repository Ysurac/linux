#!/usr/bin/env bash
set -euo pipefail

KERNEL_SERIES="${1:-7.0.y}"
PATCH_REPO_URL="${2:-https://gitlab.com/xanmod/linux-patches.git}"

repo_root="$(git rev-parse --show-toplevel)"
tmp_dir="$(mktemp -d)"
patch_repo_dir="${tmp_dir}/linux-patches"

cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

echo "Cloning patch repository: ${PATCH_REPO_URL}"
git clone --depth 1 "${PATCH_REPO_URL}" "${patch_repo_dir}"

# Support common naming variants in upstream patch directories.
candidates=(
  "linux-${KERNEL_SERIES}-xanmod"
  "linux.${KERNEL_SERIES}-xanmod"
  "linux-${KERNEL_SERIES}-xanmode"
  "linux.${KERNEL_SERIES}-xanmode"
)

patch_dir=""
for candidate in "${candidates[@]}"; do
  if [[ -d "${patch_repo_dir}/${candidate}" ]]; then
    patch_dir="${patch_repo_dir}/${candidate}"
    break
  fi
done

if [[ -z "${patch_dir}" ]]; then
  echo "Could not find a patch directory for kernel series '${KERNEL_SERIES}'."
  echo "Looked for: ${candidates[*]}"
  echo "Available top-level entries in patch repository:"
  ls -1 "${patch_repo_dir}"
  exit 1
fi

mapfile -t patches < <(find "${patch_dir}" -maxdepth 1 -type f \( -name '*.patch' -o -name '*.diff' \) | sort)

if [[ "${#patches[@]}" -eq 0 ]]; then
  echo "No patch files were found in '${patch_dir}'."
  exit 1
fi

echo "Applying ${#patches[@]} patches from '${patch_dir}'"
git -C "${repo_root}" am --3way "${patches[@]}"

echo "Patch application completed successfully."
