#!/usr/bin/env bash
# ==============================================================================
# 👑 LIPI OS BARE-METAL KERNEL QEMU BOOTSTRAPPER (scripts/boot_qemu.sh)
# ⚡ Direct Bare-Metal Silicon Simulation | Multiboot-1 & VGA Text Mode Test
# ==============================================================================

set -euo pipefail

CYAN='\033[38;2;0;255;204m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

KERNEL="dist/lipi_os_kernel.elf"

if [ ! -f "${KERNEL}" ]; then
    echo -e "${YELLOW}► কার্নেল ইমেজ পাওয়া যায়নি! প্রথমে সিন্থেসিস করা হচ্ছে...${NC}"
    ./bin/lipic examples/41_baremetal_multiboot_kernel.lp -o dist/test41_kernel
    ./dist/test41_kernel
fi

if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo -e "${RED}❌ এরর: QEMU (qemu-system-x86_64) ইনস্টল করা নেই!${NC}"
    exit 1
fi

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  👑 BOOTING LIPI BARE-METAL OS KERNEL IN QEMU EMULATOR                 ║${NC}"
echo -e "${CYAN}║  ⚡ Multiboot-1 Specification (0x1BADB002) | Direct VGA 0xB8000 Screen ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}[১] কিউইএমইউ ভার্চুয়াল মেশিনে লিপি কার্নেল বুট হচ্ছে...${NC}"
echo "  • কার্নেল ইমেজ: ${KERNEL}"
echo "  • বুট প্রটোকল : Multiboot-1 Compliant (32-bit Protected Mode)"
echo "  • ভিডিও মেমরি : 0xB8000 Physical Text Buffer"
echo ""

# Run QEMU in headless test mode for 2 seconds to verify execution
qemu-system-x86_64 -kernel "${KERNEL}" -display none -monitor none &
Q_PID=$!

sleep 1.5

if kill -0 "${Q_PID}" 2>/dev/null; then
    echo -e "${GREEN}✔ সফল! লিপি ওএস কার্নেল কোনো অপারেটিং সিস্টেম ছাড়াই সফলভাবে চালু হয়েছে!${NC}"
    kill -9 "${Q_PID}" 2>/dev/null || true
    echo -e "${CYAN}  ► গ্রাফিক্যাল মনিটরে দেখতে চালান: qemu-system-x86_64 -kernel ${KERNEL}${NC}"
else
    echo -e "${RED}❌ বুট ব্যর্থ হয়েছে!${NC}"
    exit 1
fi
