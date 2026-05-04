#!/usr/bin/env bash
set -euo pipefail

# Fetch XanMod kernel config from an upstream URL.
# arm64 builds use the x86_64 XanMod config as a base and apply arch fixes.

KERNEL_ARCH="${1:-x86_64}"
OUTPUT_CONFIG="${2:-.config}"
CONFIG_URL="${3:-https://gitlab.com/xanmod/linux/-/raw/6.18/CONFIGS/x86_64/config}"

tmp_config="$(mktemp)"
cleanup() {
  rm -f "${tmp_config}"
}
trap cleanup EXIT

echo "Fetching XanMod config for ${KERNEL_ARCH}"

echo "Config URL: ${CONFIG_URL}"
curl -fL "${CONFIG_URL}" -o "${tmp_config}"
cp "${tmp_config}" "${OUTPUT_CONFIG}"
echo "Config downloaded to: ${OUTPUT_CONFIG}"

case "${KERNEL_ARCH}" in
  x86_64)
    ;;
  arm64)
    echo "Adapting x86_64 config for arm64"

    # Drop x86-only toggles from the imported base config.
    sed -i -E \
      -e '/^CONFIG_(X86|X86_|IA32|PARAVIRT|KVM_INTEL|KVM_AMD|EFI_MIXED|MICROCODE_INTEL|MICROCODE_AMD|AMD_NUMA|INTEL_[A-Z0-9_]+|XEN|ACPI_HOTPLUG_MEMORY|DMI|I8K|MTRR|SMP_X86)/d' \
      -e '/^# CONFIG_(X86|IA32|PARAVIRT|KVM_INTEL|KVM_AMD|EFI_MIXED|XEN).* is not set/d' \
      "${OUTPUT_CONFIG}"

    # Ensure arm64 architecture markers are set before olddefconfig normalizes options.
    {
      echo "CONFIG_ARM64=y"
      echo "# CONFIG_X86 is not set"
      echo "CONFIG_64BIT=y"
      echo "CONFIG_ARM64_4K_PAGES=y"
      echo "CONFIG_ARM64_VA_BITS=48"
      echo "CONFIG_ARM64_VA_BITS_48=y"
    } >> "${OUTPUT_CONFIG}"
    ;;
  *)
    echo "Error: unsupported architecture ${KERNEL_ARCH}"
    exit 1
    ;;
esac

echo "Config prepared successfully."
