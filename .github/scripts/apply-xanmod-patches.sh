#!/usr/bin/env bash
set -euo pipefail

KERNEL_SERIES="${1:-7.0.y}"
PATCH_REPO_URL="${2:-https://gitlab.com/xanmod/linux-patches.git}"
EXCLUDE_DIRS_CSV="${3:-}"
SKIP_FAILED_PATCHES="${4:-1}"

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

readarray -t exclude_dirs < <(printf '%s' "${EXCLUDE_DIRS_CSV}" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sed '/^$/d')

# XanMod groups patches in nested folders (xanmod/, zen/, net/, ...).
# Discover patch files recursively and apply them in lexical path order.
mapfile -t all_patches < <(find "${patch_dir}" -type f \( -name '*.patch' -o -name '*.diff' \) | sort)
patches=()
for patch in "${all_patches[@]}"; do
  skip=0
  for excluded in "${exclude_dirs[@]}"; do
    if [[ "${patch}" == *"/${excluded}/"* ]]; then
      skip=1
      break
    fi
  done
  if [[ "${skip}" -eq 0 ]]; then
    patches+=("${patch}")
  fi
done

if [[ "${#patches[@]}" -eq 0 ]]; then
  echo "No patch files were found in '${patch_dir}'."
  exit 1
fi

# git am creates commits and needs committer identity.
if ! git -C "${repo_root}" config --get user.name >/dev/null; then
  git -C "${repo_root}" config user.name "github-actions[bot]"
fi

if ! git -C "${repo_root}" config --get user.email >/dev/null; then
  git -C "${repo_root}" config user.email "github-actions[bot]@users.noreply.github.com"
fi

echo "Applying ${#patches[@]} patches from '${patch_dir}'"
if [[ "${#exclude_dirs[@]}" -gt 0 ]]; then
  echo "Excluded patch directories: ${exclude_dirs[*]}"
fi

applied_count=0
failed_count=0
for patch in "${patches[@]}"; do
  echo "Applying: $(basename "${patch}")"
  if git -C "${repo_root}" am --3way "${patch}"; then
    applied_count=$((applied_count + 1))
    continue
  fi

  failed_count=$((failed_count + 1))
  git -C "${repo_root}" am --abort || true

  if [[ "${SKIP_FAILED_PATCHES}" == "1" || "${SKIP_FAILED_PATCHES}" == "true" || "${SKIP_FAILED_PATCHES}" == "yes" ]]; then
    echo "Skipping failed patch: ${patch}"
    continue
  fi

  echo "Patch apply failed and skip mode is disabled."
  echo "Set skip_failed_patches=true in workflow inputs to continue on incompatible patches."
  exit 1
done

if [[ "${applied_count}" -eq 0 ]]; then
  echo "No patches were applied successfully."
  exit 1
fi

echo "Patch summary: applied=${applied_count}, failed=${failed_count}"

echo "Patch application completed successfully."
