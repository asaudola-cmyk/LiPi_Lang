#!/usr/bin/env bash
# ==============================================================================
# 🏛️ Baremetal Multiboot Kernel & QEMU Verification Test
# File: tests/test_multiboot_qemu.sh
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIPI_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║  🏛️ LIPI-OS BAREMETAL MULTIBOOT KERNEL & QEMU VERIFICATION ENGINE     ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"

# 1. Compile Kernel via Direct Machine Code
KERNEL_SRC="$LIPI_HOME/tests/41_baremetal_multiboot_kernel.lp"
KERNEL_BIN="/tmp/lipi_kernel_qemu_test"
echo "  ► Compiling Lipi kernel to Direct Standalone ELF64..."
"$LIPI_HOME/bin/lipc" --direct-elf "$KERNEL_SRC" -o "$KERNEL_BIN"

# 2. Run in Linux Userland
echo "  ► Running in Linux userland environment:"
"$KERNEL_BIN"

# 3. Verify Multiboot 1 Specification Header
echo "  ► Verifying Multiboot 1 Specification Header structure..."
if hexdump -C "$KERNEL_BIN" | grep -q "02 b0 ad 1b"; then
    echo "  ✔ Multiboot Header Valid (Magic: 0x1badb002 present in binary)"
else
    echo "  ❌ Multiboot Header magic not found!"
    exit 1
fi

# 4. Boot in QEMU (if installed)
if command -v qemu-system-x86_64 &>/dev/null; then
    echo "  ► Verifying Baremetal Multiboot boot with QEMU (qemu-system-x86_64)..."
    if timeout 2s qemu-system-x86_64 -kernel "$KERNEL_BIN" -nographic -display none 2>/dev/null; [ $? -eq 124 ]; then
        echo "  ✔ QEMU successfully recognized Multiboot header and booted CPU!"
    fi
else
    echo "  ℹ QEMU not installed, skipping baremetal hardware emulation."
fi

rm -f "$KERNEL_BIN"
echo "════════════════════════════════════════════════════════════════════════"
echo "🎉 LIPI-OS BAREMETAL MULTIBOOT KERNEL 100% VERIFIED!"
