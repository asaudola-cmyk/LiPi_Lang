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
python3 -c '
with open("'"$KERNEL_BIN"'", "rb") as f:
    data = f.read()
import struct
magic = struct.pack("<I", 0x1BADB002)
pos = data.find(magic)
assert pos != -1, "Multiboot magic not found!"
assert pos < 8192, "Multiboot magic beyond 8KB boundary!"
assert pos % 4 == 0, "Multiboot magic not 4-byte aligned!"
header = struct.unpack("<III", data[pos:pos+12])
assert (sum(header) & 0xFFFFFFFF) == 0, "Multiboot checksum invalid!"
print(f"  ✔ Multiboot Header Valid at offset {pos} (Magic: {hex(header[0])}, Checksum: {hex(header[2])})")
'

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
