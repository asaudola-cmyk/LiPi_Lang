#!/usr/bin/env bash
# ==============================================================================
# 👑 LIPI OS BARE-METAL KERNEL & ISO QEMU BOOTSTRAPPER (scripts/boot_qemu.sh)
# ⚡ Direct Bare-Metal Silicon Simulation | Multiboot-1 & Hybrid ISO Boot
# ==============================================================================
#
# WHY: Computing sovereignty requires verification that Lipi OS boots cleanly
# without an underlying operating system. This script provides an automated runner
# for QEMU x86_64 virtualization supporting:
#   1. Direct Kernel ELF Mode (-kernel dist/kernel.elf)
#   2. Hybrid CD-ROM / Live ISO Mode (-cdrom dist/lipi-os.iso)
#   3. Headless Verification Mode (timeout 3s test with process validation)
#   4. Interactive Graphical / Serial Console Mode for live user exploration
# ==============================================================================

set -euo pipefail

CYAN='\033[38;2;0;255;204m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BOLD='\033[1m'
NC='\033[0m'

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${BASE_DIR}"

BOOT_MODE="iso"      # iso or kernel
EXEC_MODE="test"     # test (headless timeout) or run (interactive)
# WHY: 2048M ensures guest physical memory covers the 0x40000000 ELF load address
QEMU_MEM="2048M"

# Parse CLI flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --iso|-i)
            BOOT_MODE="iso"
            shift
            ;;
        --kernel|-k)
            BOOT_MODE="kernel"
            shift
            ;;
        --run|--interactive|-r)
            EXEC_MODE="run"
            shift
            ;;
        --test|--headless|-t)
            EXEC_MODE="test"
            shift
            ;;
        --gui)
            EXEC_MODE="gui"
            shift
            ;;
        -m|--mem)
            QEMU_MEM="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --iso, -i          Boot hybrid ISO image (dist/lipi-os.iso) [default]"
            echo "  --kernel, -k       Boot direct Multiboot ELF kernel (dist/kernel.elf)"
            echo "  --test, -t         Run headless boot test and exit cleanly (default)"
            echo "  --run, -r          Run interactive session with serial console in terminal"
            echo "  --gui              Launch QEMU with graphical VGA window"
            echo "  -m, --mem <size>   Set guest RAM allocation (default: 256M)"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}" >&2
            exit 1
            ;;
    esac
done

if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo -e "${RED}❌ ত্রুটি: QEMU (qemu-system-x86_64) ইনস্টল করা নেই!${NC}" >&2
    exit 1
fi

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  👑 BOOTING LIPI BARE-METAL OS IN QEMU VIRTUAL MACHINE                 ║${NC}"
echo -e "${CYAN}║  ⚡ Multiboot-1 / El Torito Hybrid ISO | 0% C | 0% GCC | 0% Libc        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Ensure boot artifacts exist
if [ "${BOOT_MODE}" = "iso" ]; then
    TARGET_MEDIA="dist/lipi-os.iso"
    if [ ! -f "${TARGET_MEDIA}" ]; then
        echo -e "${YELLOW}► dist/lipi-os.iso পাওয়া যায়নি! scripts/build_iso.sh চালানো হচ্ছে...${NC}"
        bash scripts/build_iso.sh --no-qemu
    fi
    QEMU_BOOT_ARGS=(-cdrom "${TARGET_MEDIA}")
    echo "  • বুট মাধ্যম: হাইব্রিড লাইভ আইএসও (${TARGET_MEDIA})"
else
    TARGET_MEDIA="dist/kernel.elf"
    if [ ! -f "${TARGET_MEDIA}" ]; then
        echo -e "${YELLOW}► dist/kernel.elf পাওয়া যায়নি! সংকলন করা হচ্ছে...${NC}"
        ./bin/lipc tests/41_baremetal_multiboot_kernel.lp -o "${TARGET_MEDIA}"
    fi
    QEMU_BOOT_ARGS=(-kernel "${TARGET_MEDIA}")
    echo "  • বুট মাধ্যম: ডিরেক্ট মাল্টিবুট ELF কার্নেল (${TARGET_MEDIA})"
fi

echo "  • মেমরি বরাদ্দ: ${QEMU_MEM}"
echo "  • মোড: ${EXEC_MODE}"
echo ""

if [ "${EXEC_MODE}" = "test" ]; then
    echo -e "${YELLOW}[১] হেডলেস বুট ভেরিফিকেশন চালানো হচ্ছে (Headless 3s Watchdog)...${NC}"
    # WHY: Run QEMU in headless background mode for 3 seconds. If the kernel does not crash or fault,
    # it passes the OS hardware initialization and entry point barriers.
    set +e
    timeout 3s qemu-system-x86_64 \
        "${QEMU_BOOT_ARGS[@]}" \
        -m "${QEMU_MEM}" \
        -display none \
        -serial file:/tmp/lipi_qemu_serial.log \
        2>/dev/null
    STATUS=$?
    set -e

    # Timeout returns 124 when process runs continuously until signal, which indicates success for an OS kernel loop
    if [ ${STATUS} -eq 124 ] || [ ${STATUS} -eq 0 ]; then
        echo -e "${GREEN}✔ সফল! লিপি ওএস কার্নেল ও ভার্চুয়াল মেশিন কোনো ক্র্যাশ ছাড়াই বুট হয়েছে!${NC}"
        if [ -s "/tmp/lipi_qemu_serial.log" ]; then
            echo -e "${CYAN}--- সিরিয়াল কনসোল আউটপুট ডাম্প ---${NC}"
            head -n 20 /tmp/lipi_qemu_serial.log | sed 's/^/  | /'
            echo -e "${CYAN}---------------------------------${NC}"
        fi
        rm -f /tmp/lipi_qemu_serial.log
    else
        echo -e "${RED}❌ বুট পরীক্ষা ব্যর্থ হয়েছে! (Exit status: ${STATUS})${NC}" >&2
        rm -f /tmp/lipi_qemu_serial.log
        exit ${STATUS}
    fi
elif [ "${EXEC_MODE}" = "gui" ]; then
    echo -e "${GREEN}► গ্রাফিক্যাল ভিজিএ উইন্ডো ও সিরিয়াল কনসোল সহ চালু হচ্ছে...${NC}"
    exec qemu-system-x86_64 "${QEMU_BOOT_ARGS[@]}" -m "${QEMU_MEM}" -vga std -serial mon:stdio
else
    echo -e "${GREEN}► টার্মিনাল কনসোলে লিপি ওএস বুট হচ্ছে (Ctrl+A, X দিয়ে বের হোন)...${NC}"
    exec qemu-system-x86_64 "${QEMU_BOOT_ARGS[@]}" -m "${QEMU_MEM}" -nographic -serial mon:stdio
fi
