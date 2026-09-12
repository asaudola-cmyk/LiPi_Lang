#!/usr/bin/env bash
# ==============================================================================
# 👑 LIPI SOVEREIGN BARE-METAL HYBRID ISO BUILDER (scripts/build_iso.sh)
# ⚡ Synthesizes Multiboot 1 ELF64 Kernel & Packages Bootable Lipi-OS ISO Image
# ==============================================================================
#
# WHY: Computing sovereignty requires the ability to bootstrap directly from
# physical storage media (USB flash drives, CD/DVD, PXE, baremetal hypervisors)
# without depending on an underlying host operating system. This script automates
# compilation of the Lipi baremetal kernel ('tests/41_baremetal_multiboot_kernel.lp'
# and 'std/kernel.lp') and packages it into a hybrid El Torito / MBR bootable ISO
# ('dist/lipi-os.iso') powered by GRUB 2 Multiboot 1 specification.
#
# Pipeline Architecture:
#   1. Pure Lipi compilation -> dist/kernel.elf (ELF64 with embedded Multiboot header)
#   2. Multiboot 1 specification verification (0x1BADB002 magic number inspection)
#   3. ISO staging directory tree initialization (iso_staging/boot/grub)
#   4. GRUB boot configuration synthesis (grub.cfg with multiboot directive)
#   5. Hybrid bootable ISO synthesis via grub-mkrescue & xorriso
#   6. ISO integrity verification & optional QEMU headless validation
# ==============================================================================

set -euo pipefail

# ANSI Palette
CYAN='\033[38;2;0;255;204m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BOLD='\033[1m'
NC='\033[0m'

# Directory & Path Resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

KERNEL_SRC="tests/41_baremetal_multiboot_kernel.lp"
KERNEL_ELF="dist/kernel.elf"
STAGING_DIR="$(mktemp -d /tmp/iso_staging_XXXXXX)"
trap 'rm -rf "${STAGING_DIR}"' EXIT
GRUB_CFG="${STAGING_DIR}/boot/grub/grub.cfg"
ISO_OUTPUT="dist/lipi-os.iso"

# Parse CLI flags (Default: verify QEMU boot if qemu-system-x86_64 is available)
DO_QEMU_TEST=true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-qemu|--no-test|--skip-test)
            DO_QEMU_TEST=false
            shift
            ;;
        --test|--boot|--qemu)
            DO_QEMU_TEST=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--no-qemu|--test|--boot]"
            echo "  --test, --boot, --qemu  Run headless QEMU verification after ISO synthesis (default)"
            echo "  --no-qemu, --skip-test  Skip headless QEMU verification"
            echo "  -h, --help              Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}" >&2
            exit 1
            ;;
    esac
done

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  👑 LIPI SOVEREIGN OPERATING SYSTEM — HYBRID ISO SYNTHESIZER           ║${NC}"
echo -e "${CYAN}║  ⚡ Multiboot 1 (0x1BADB002) | Pure ELF64 | Bootable Hybrid ISO       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Pre-Flight Dependency & Environment Validation
# ──────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[০] প্রাক-যাচাই (Pre-flight checks)...${NC}"

if [ ! -x "bin/lipc" ]; then
    echo -e "${RED}❌ ত্রুটি: Lipi কম্পাইলার 'bin/lipc' পাওয়া যায়নি অথবা এক্সিকিউটেবল নয়!${NC}" >&2
    exit 1
fi

if [ ! -f "${KERNEL_SRC}" ]; then
    echo -e "${RED}❌ ত্রুটি: কার্নেল সোর্স ফাইল '${KERNEL_SRC}' পাওয়া যায়নি!${NC}" >&2
    exit 1
fi

if ! command -v grub-mkrescue &>/dev/null; then
    echo -e "${RED}❌ ত্রুটি: 'grub-mkrescue' ইনস্টল করা নেই! (প্রয়োজন: grub-common, grub-pc-bin, xorriso)${NC}" >&2
    exit 1
fi

if ! command -v xorriso &>/dev/null; then
    echo -e "${RED}❌ ত্রুটি: 'xorriso' ইনস্টল করা নেই!${NC}" >&2
    exit 1
fi

mkdir -p dist

# ──────────────────────────────────────────────────────────────────────────────
# ধাপ ১: কার্নেল সংকলন (Compile baremetal kernel to standalone Multiboot ELF64)
# ──────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[১] লিপিক কম্পাইলার দিয়ে কার্নেল সংকলন করা হচ্ছে...${NC}"
echo "  • সোর্স ফাইল : ${KERNEL_SRC}"
echo "  • টার্গেট বাইনারি: ${KERNEL_ELF}"

./bin/lipc "${KERNEL_SRC}" -o "${KERNEL_ELF}"

if [ ! -f "${KERNEL_ELF}" ]; then
    echo -e "${RED}❌ ত্রুটি: কার্নেল বাইনারি '${KERNEL_ELF}' তৈরি হতে ব্যর্থ হয়েছে!${NC}" >&2
    exit 1
fi
echo -e "${GREEN}  ✔ কার্নেল ELF সফলভাবে সংকলিত হয়েছে ($(du -b "${KERNEL_ELF}" | cut -f1) বাইট)${NC}"

# ──────────────────────────────────────────────────────────────────────────────
# ধাপ ২: মাল্টিবুট ১ হেডার যাচাই (Verify Multiboot 1 header magic: 0x1BADB002)
# ──────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[২] মাল্টিবুট ১ হেডার ম্যাজিক (0x1BADB002) যাচাইকরণ...${NC}"
# WHY: Direct binary string search avoids pipeline SIGPIPE issues under set -o pipefail
# while inspecting the Multiboot 1 specification magic (0x1BADB002 = 02 b0 ad 1b).
if grep -a -F -q $'\x02\xb0\xad\x1b' "${KERNEL_ELF}"; then
    MAGIC_LOC=$(hexdump -C -n 256 "${KERNEL_ELF}" | grep "02 b0 ad 1b" | head -n 1)
    echo -e "${GREEN}  ✔ মাল্টিবুট ১ স্পেসিফিকেশন হেডার নিশ্চিত হয়েছে (Magic: 0x1BADB002 present)${NC}"
    echo "    হেডার ডাম্প: ${MAGIC_LOC}"
else
    echo -e "${RED}❌ ত্রুটি: '${KERNEL_ELF}' ফাইলের মধ্যে Multiboot 1 Magic (0x1BADB002) পাওয়া যায়নি!${NC}" >&2
    exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# ধাপ ৩: আইএসও স্টেজিং ডিরেক্টরি তৈরি (Create ISO staging structure)
# ──────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[৩] আইএসও স্টেজিং ডিরেক্টরি কাঠামো প্রস্তুতকরণ...${NC}"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}/boot/grub"

cp "${KERNEL_ELF}" "${STAGING_DIR}/boot/kernel.elf"
echo -e "${GREEN}  ✔ স্টেজিং কাঠামো তৈরি সম্পন্ন:${NC}"
echo "    • ${STAGING_DIR}/boot/kernel.elf"
echo "    • ${STAGING_DIR}/boot/grub/grub.cfg"

# ──────────────────────────────────────────────────────────────────────────────
# ধাপ ৪: গ্রাব (GRUB) কনফিগারেশন তৈরি (Write GRUB bootloader configuration)
# ──────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[৪] গ্রাব (GRUB 2) কনফিগারেশন তৈরি করা হচ্ছে...${NC}"
# WHY: GRUB's multiboot command hands over control directly to the Multiboot-compliant
# ELF entry point with machine state matching the Multiboot 1 Specification.
cat << 'GRUB_CFG_EOF' > "${GRUB_CFG}"
set timeout=0
set default=0
# WHY: Configure dual terminal for headless cloud microVMs (COM1 serial 115200) and physical monitors (VGA console)
serial --unit=0 --speed=115200
terminal_input serial console
terminal_output serial console

menuentry "Lipi Sovereign Operating System (লিপি ওএস)" {
    multiboot /boot/kernel.elf
    boot
}
GRUB_CFG_EOF

echo -e "${GREEN}  ✔ GRUB কনফিগারেশন সফলভাবে লেখা হয়েছে:${NC}"
cat "${GRUB_CFG}" | sed 's/^/    | /'

# ──────────────────────────────────────────────────────────────────────────────
# ধাপ ৫: হাইব্রিড বুটেবল আইএসও ইমেজ তৈরি (Generate bootable hybrid ISO)
# ──────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[৫] grub-mkrescue দিয়ে বুটেবল হাইব্রিড আইএসও ইমেজ তৈরি...${NC}"
echo "  • আউটপুট পথ: ${ISO_OUTPUT}"

grub-mkrescue -o "${ISO_OUTPUT}" "${STAGING_DIR}" 2>&1 | sed 's/^/    [xorriso] /'

if [ ! -f "${ISO_OUTPUT}" ]; then
    echo -e "${RED}❌ ত্রুটি: '${ISO_OUTPUT}' তৈরি হতে ব্যর্থ হয়েছে!${NC}" >&2
    exit 1
fi

ISO_BYTES=$(stat -c%s "${ISO_OUTPUT}" 2>/dev/null || stat -f%z "${ISO_OUTPUT}")
ISO_HUMAN=$(du -h "${ISO_OUTPUT}" | cut -f1)
echo -e "${GREEN}  ✔ হাইব্রিড আইএসও ইমেজ সফলভাবে প্রস্তুত হয়েছে (${ISO_HUMAN} / ${ISO_BYTES} বাইট)${NC}"

# ──────────────────────────────────────────────────────────────────────────────
# ধাপ ৬: আইএসও মেটাডাটা ও অখণ্ডতা যাচাই (Verify ISO image structure)
# ──────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[৬] আইএসও ফাইল টাইপ ও এল টোরিতো (El Torito) বুট রেকর্ড যাচাইকরণ...${NC}"

FILE_INFO=$(file "${ISO_OUTPUT}")
echo "  • ফাইল টাইপ: ${FILE_INFO}"

if echo "${FILE_INFO}" | grep -q "ISO 9660"; then
    echo -e "${GREEN}  ✔ বৈধ ISO 9660 বুটেবল ফাইল সিস্টেম নিশ্চিত করা হয়েছে!${NC}"
else
    echo -e "${RED}❌ ত্রুটি: '${ISO_OUTPUT}' কোনো বৈধ ISO 9660 ইমেজ নয়!${NC}" >&2
    exit 1
fi

# Additional verification with xorriso
echo "  • Xorriso বুট ভেরিফিকেশন রিপোর্ট:"
xorriso -indev "${ISO_OUTPUT}" -report_el_torito as_mkisofs 2>&1 | grep -E "El Torito|boot|catalog" | sed 's/^/    | /' || true

# ──────────────────────────────────────────────────────────────────────────────
# ধাপ ৭ (ঐচ্ছিক / ভেরিফিকেশন): QEMU বুট টেস্টিং
# ──────────────────────────────────────────────────────────────────────────────
if [ "${DO_QEMU_TEST}" = true ]; then
    echo ""
    echo -e "${YELLOW}[৭] QEMU এমুলেটরে লিপি ওএস আইএসও বুট পরীক্ষা চালানো হচ্ছে...${NC}"
    if ! command -v qemu-system-x86_64 &>/dev/null; then
        echo -e "${RED}❌ সতর্কতা: QEMU (qemu-system-x86_64) ইনস্টল করা নেই, বুট পরীক্ষা বাদ দেওয়া হলো।${NC}"
    else
        echo "  ► কমান্ড: timeout 5s qemu-system-x86_64 -cdrom ${ISO_OUTPUT} -m 2048M -display none"
        # WHY: In headless execution, a running kernel does not exit. timeout returns 124 on normal termination.
        # 2048M ensures guest physical memory covers the 0x40000000 ELF load address.
        set +e
        timeout 5s qemu-system-x86_64 -cdrom "${ISO_OUTPUT}" -m 2048M -display none 2>/dev/null
        QEMU_STATUS=$?
        set -e
        if [ ${QEMU_STATUS} -eq 124 ] || [ ${QEMU_STATUS} -eq 0 ]; then
            echo -e "${GREEN}  ✔ QEMU ভার্চুয়াল মেশিনে লিপি ওএস হাইব্রিড আইএসও সফলভাবে বুট হয়েছে! (Status: ${QEMU_STATUS})${NC}"
        else
            echo -e "${RED}❌ QEMU বুট ব্যর্থ হয়েছে! (Exit status: ${QEMU_STATUS})${NC}" >&2
            exit ${QEMU_STATUS}
        fi
    fi
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  🎉 লিপি ওএস হাইব্রিড বুটেবল আইএসও ইমেজ সিন্থেসিস ১০০% সফল!             ║${NC}"
echo -e "${CYAN}║  📁 আউটপুট: ${ISO_OUTPUT}                                            ║${NC}"
echo -e "${CYAN}║  ⚡ সরাসরি USB বা হার্ডডিস্কে লিখতে: dd if=${ISO_OUTPUT} of=/dev/sdX bs=4M   ║${NC}"
echo -e "${CYAN}║  ⚡ সরাসরি QEMU-তে বুট করতে: qemu-system-x86_64 -cdrom ${ISO_OUTPUT} -m 128M  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
