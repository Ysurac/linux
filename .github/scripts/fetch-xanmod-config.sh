#!/usr/bin/env bash
set -euo pipefail

# Fetch XanMod kernel config from upstream repo
# Supports x86_64 and arm64 (uses x86_64 base with arm64 adaptations)

KERNEL_ARCH="${1:-x86_64}"
OUTPUT_CONFIG="${2:-.config}"
CONFIG_REPO_URL="${3:-https://gitlab.com/xanmod/linux/-/raw/master/CONFIGS/x86_64}"

echo "Fetching XanMod config for ${KERNEL_ARCH}"

case "${KERNEL_ARCH}" in
  x86_64)
    config_url="${CONFIG_REPO_URL}/.config"
    ;;
  arm64)
    # arm64 uses x86_64 base adapted
    config_url="${CONFIG_REPO_URL/.../x86_64}/.config"
    ;;
  *)
    echo "Error: unsupported architecture ${KERNEL_ARCH}"
    exit 1
    ;;
esac

echo "Config URL: ${config_url}"
if curl -fL "${config_url}" -o "${OUTPUT_CONFIG}"; then
  echo "Config downloaded to: ${OUTPUT_CONFIG}"
  
  # Basic arm64-specific adaptations if building for arm64
  if [[ "${KERNEL_ARCH}" == "arm64" ]]; then
    echo "Applying arm64 adaptations to config"
    # Remove x86-specific options and set arm64-specific defaults
    sed -i '/^CONFIG_X86/d; /^CONFIG_IA32/d; /^CONFIG_PARAVIRT/d; /^CONFIG_CRYPTO_TWOFISH_AVX/d;' "${OUTPUT_CONFIG}"
    # Ensure critical arm64 configs are present
    {
      echo "CONFIG_ARM64=y"
      echo "CONFIG_ARM64_VA_BITS=48"
      echo "CONFIG_ARM64_VA_BITS_DEFAULT=48"
    } >> "${OUTPUT_CONFIG}"
  fi
  
  echo "Config prepared successfully."
else
  echo "Failed to download config from ${config_url}"
  exit 1
fi
