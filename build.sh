#!/usr/bin/env bash
# ==============================================================================
# 👑 LIPI SOVEREIGN BUILD & BOOTSTRAP PIPELINE (build.sh)
#
# WHY: Lipi is a 100% sovereign native programming language.
# It compiles directly to standalone 64-bit Linux ELF executables.
# Zero C, Zero GCC, Zero Python, Zero PHP, Zero Libc dependencies.
#
# Stages:
#   [Stage 0] Sovereign Bootstrap Seed Verification (boot/lipi-seed / boot/seed.b64)
#   [Stage 1] Seed Compilation: boot/lipi-seed -> bin/lipc_gen1
#   [Stage 2] Self-Hosting Generation 2: bin/lipc_gen1 -> bin/lipc_gen2
#   [Stage 3] Bit-for-Bit Determinism Verification: bin/lipc_gen2 -> bin/lipc_gen3
#   [Stage 4] Deploy Sovereign Compiler Engine (bin/lipc_bin, bin/lipc, bin/lipi)
#   [Stage 5] Compile Sovereign Native Tools (bin/lipiconvert)
#   [Stage 6] 60/60 Regression Test Suite in Direct ELF Machine Code Mode
#   [Stage 7] Complete Sovereignty Audit (0% C, 0% GCC, 0% Python, 0% PHP)
# ==============================================================================

LIPI_VERSION="প্রথম ১.০"
LIPI_VERSION_ENG="Prothom 1.0"
LIPI_CODENAME="সোভেরিন"

set -euo pipefail

CYAN='\033[38;2;0;255;204m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${BASE_DIR}"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  👑 LIPI SOVEREIGN SELF-HOSTING BOOTSTRAP & BUILD PIPELINE             ║${NC}"
echo -e "${CYAN}║  ⚡ 100% Pure Lipi Machine Code | 0% C | 0% GCC | 0% Python | 0% PHP   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

mkdir -p bin dist

# ------------------------------------------------------------------------------
# [ধাপ ০: সার্বভৌম বুটস্ট্র্যাপ সিড যাচাইকরণ / Bootstrap Seed Verification]
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ধাপ ০] সার্বভৌম বুটস্ট্র্যাপ সিড প্রস্তুতি ও যাচাইকরণ...${NC}"
if [ -f "boot/lipi-seed" ]; then
    echo "  ► Deploying sovereign bootstrap seed from boot/lipi-seed..."
    chmod +x boot/lipi-seed
elif [ -f "boot/seed.b64" ]; then
    echo "  ► Materializing sovereign bootstrap seed from ASCII text (boot/seed.b64)..."
    base64 -d boot/seed.b64 | gzip -d > boot/lipi-seed
    chmod +x boot/lipi-seed
else
    echo -e "${RED}❌ Fatal: No bootstrap seed found in boot/!${NC}"
    exit 1
fi
echo -e "${GREEN}  ✔ সার্বভৌম স্ট্যাটিক সিড ইঞ্জিন প্রস্তুত (boot/lipi-seed - ১০০% স্বাধীন)।${NC}"
echo ""

# ------------------------------------------------------------------------------
# [ধাপ ১: স্টেজ ১ রি-বুটস্ট্র্যাপ / Stage 1 Seed Compilation]
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ধাপ ১] সিড দিয়ে খাঁটি লিপি কম্পাইলার (Gen1) তৈরি...${NC}"
./boot/lipi-seed src/compiler/elf_emitter.lp bin/lipc_gen1 > /dev/null
chmod +x bin/lipc_gen1
echo -e "${GREEN}  ✔ bin/lipc_gen1 সফলভাবে সংকলিত (খাঁটি লিপি ডিরেক্ট মেশিন কোড)।${NC}"
echo ""

# ------------------------------------------------------------------------------
# [ধাপ ২: স্টেজ ২ সেলফ-হোস্টিং / Stage 2 Self-Hosting]
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ধাপ ২] খাঁটি লিপি Gen1 দিয়ে সম্পূর্ণ সেলফ-হোস্টেড Gen2 সংকলন...${NC}"
./bin/lipc_gen1 src/compiler/elf_emitter.lp bin/lipc_gen2 > /dev/null
chmod +x bin/lipc_gen2
echo -e "${GREEN}  ✔ bin/lipc_gen2 সেলফ-হোস্টেড কম্পাইলার প্রস্তুত (100% Statically Linked ELF64)।${NC}"
echo ""

# ------------------------------------------------------------------------------
# [ধাপ ৩: স্টেজ ৩ বিট-ফর-বিট ডিটারমিনিজম ক্লোজার / Stage 3 Determinism Closure]
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ধাপ ৩] সেলফ-হোস্টিং ক্লোজার ও বিট-ফর-বিট ডিটারমিনিজম পরীক্ষা (Gen2 -> Gen3)...${NC}"
./bin/lipc_gen2 src/compiler/elf_emitter.lp bin/lipc_gen3 > /dev/null
chmod +x bin/lipc_gen3

if cmp -s bin/lipc_gen2 bin/lipc_gen3; then
    echo -e "${GREEN}  ✔ সেলফ-হোস্টিং ক্লোজার সফল! Gen2 এবং Gen3 ১০০% বিট-ফর-বিট অভিন্ন (Bit-for-Bit Identical)!${NC}"
    rm -f bin/lipc_gen1 bin/lipc_gen3
else
    echo -e "${RED}  ❌ এরর: বিট-ফর-বিট ডিটারমিনিজম অমিল!${NC}"
    exit 1
fi
echo ""

# ------------------------------------------------------------------------------
# [ধাপ ৪: সার্বভৌমিক কম্পাইলার ইঞ্জিন ডেপ্লয় / Deploy Sovereign Engine]
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ধাপ ৪] সার্বভৌমিক কম্পাইলার ইঞ্জিন ডেপ্লয়মেন্ট...${NC}"
cp bin/lipc_gen2 bin/lipc_bin
chmod +x bin/lipc_bin
rm -f bin/lipc_gen2

# WHY: Lightweight sovereign wrapper script delegating directly to native machine code engine
cat << 'DRIVER' > bin/lipc
#!/usr/bin/env bash
# ==============================================================================
# 👑 LIPI SOVEREIGN COMPILER DRIVER (bin/lipc)
# ⚡ 100% Pure Lipi Machine Code Engine | 0% C | 0% GCC | 0% Libc | 0% Python
# ==============================================================================

set -euo pipefail

LIPI_BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIPC_BINARY="${LIPI_BIN_DIR}/lipc_bin"

if [ ! -x "${LIPC_BINARY}" ]; then
    echo "❌ Error: Sovereign compiler engine ${LIPC_BINARY} not found or not executable." >&2
    exit 1
fi

exec "${LIPC_BINARY}" "$@"
DRIVER
chmod +x bin/lipc bin/lipi
echo -e "${GREEN}  ✔ bin/lipc এবং bin/lipc_bin সফলভাবে স্থাপন করা হয়েছে।${NC}"
echo ""

# ------------------------------------------------------------------------------
# [ধাপ ৫: নেটিভ টুলচেইন সংকলন / Compile Native Tools & Web Router]
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ধাপ ৫] নেটিভ সার্বভৌম টুলচেইন ও ওয়েব রাউটার সংকলন...${NC}"
./bin/lipc_bin src/tools/lipiconvert.lp bin/lipiconvert > /dev/null
chmod +x bin/lipiconvert
echo -e "${GREEN}  ✔ bin/lipiconvert প্রস্তুত।${NC}"

./bin/lipc_bin src/tools/lipirepl.lp bin/lipirepl > /dev/null
chmod +x bin/lipirepl
echo -e "${GREEN}  ✔ bin/lipirepl প্রস্তুত (ইন্টারঅ্যাক্টিভ আরইপিএল)।${NC}"

./bin/lipc_bin src/tools/lipidbg.lp bin/lipidbg > /dev/null
chmod +x bin/lipidbg
echo -e "${GREEN}  ✔ bin/lipidbg প্রস্তুত (নেটিভ সিস্টেম ডিবাগার)।${NC}"

./bin/lipc_bin src/tools/lipilsp.lp bin/lipilsp > /dev/null
chmod +x bin/lipilsp
echo -e "${GREEN}  ✔ bin/lipilsp প্রস্তুত (ল্যাঙ্গুয়েজ সার্ভার প্রোটোকল)।${NC}"

./bin/lipc_bin src/tools/lipipkg.lp bin/lipipkg > /dev/null
chmod +x bin/lipipkg
echo -e "${GREEN}  ✔ bin/lipipkg প্রস্তুত (প্যাকেজ ম্যানেজার ২.০)।${NC}"

./bin/lipc_bin src/tools/lipi.lp bin/lipi > /dev/null
chmod +x bin/lipi
echo -e "${GREEN}  ✔ bin/lipi প্রস্তুত (মাস্টার সিএলআই ড্রাইভার)।${NC}"

./bin/lipc_bin src/tools/lipifmt.lp bin/lipifmt > /dev/null
chmod +x bin/lipifmt
echo -e "${GREEN}  ✔ bin/lipifmt প্রস্তুত (৩-সিনট্যাক্স কোড ফরম্যাটার)।${NC}"

./bin/lipc_bin src/tools/lipidoc.lp bin/lipidoc > /dev/null
chmod +x bin/lipidoc
echo -e "${GREEN}  ✔ bin/lipidoc প্রস্তুত (স্বয়ংক্রিয় ডকুমেন্টার)।${NC}"

./bin/lipc_bin tests/test_web_router.lp /tmp/web_router_build_test > /dev/null
/tmp/web_router_build_test > /dev/null
rm -f /tmp/web_router_build_test
echo -e "${GREEN}  ✔ ওয়েব রাউটার (Standard Web Router) ইন্টিগ্রেশন টেস্ট সফল!${NC}"
echo ""

# ------------------------------------------------------------------------------
# [ধাপ ৬: ৬৯টি রিগ্রেশন টেস্ট রান / Run 69/69 Regression Tests]
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ধাপ ৬] ৬৯টি রিগ্রেশন টেস্ট রান করা হচ্ছে (Direct Machine Code Mode)...${NC}"
bash tests/run_tests.sh --direct-elf
echo ""

# ------------------------------------------------------------------------------
# [ধাপ ৭: সার্বভৌমত্ব অডিট / Complete Sovereignty Audit]
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ধাপ ৭] সার্বভৌমত্ব অডিট: কোডবেসে ০% C, ০% GCC, ০% Python, ০% PHP ও ০% .maya নিশ্চিতকরণ:${NC}"

# WHY: Deep clean unified root tools/ into universe/os/ and src/tools/. Search active sovereign directories.
C_COUNT=$(find src std tests bin apps universe packages \( -name "*.c" -o -name "*.h" \) 2>/dev/null | wc -l)
PY_COUNT=$(find src std tests bin apps universe packages -name "*.py" 2>/dev/null | wc -l)
PHP_COUNT=$(find src std tests bin apps universe packages -name "*.php" 2>/dev/null | wc -l)
MAYA_COUNT=$(find src std tests bin apps universe packages -name "*.maya" 2>/dev/null | wc -l)

if [ "${C_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}  ✔ কোডবেসে কোনো .c বা .h ফাইল নেই! (০% C, ০% হেডার — ১০০% খাঁটি লিপি)${NC}"
else
    echo -e "${RED}  ❌ সতর্কতা: কোডবেসে এখনও ${C_COUNT} টি .c/.h ফাইল রয়েছে!${NC}"
    exit 1
fi

if [ "${PY_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}  ✔ কোডবেসে কোনো .py ফাইল নেই! (০% Python — ১০০% স্বাধীন লিপি)${NC}"
else
    echo -e "${RED}  ❌ সতর্কতা: কোডবেসে এখনও ${PY_COUNT} টি .py ফাইল রয়েছে!${NC}"
    exit 1
fi

if [ "${PHP_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}  ✔ কোডবেসে কোনো .php ফাইল নেই! (০% PHP — ১০০% স্বাধীন লিপি)${NC}"
else
    echo -e "${RED}  ❌ সতর্কতা: কোডবেসে এখনও ${PHP_COUNT} টি .php ফাইল রয়েছে!${NC}"
    exit 1
fi

if [ "${MAYA_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}  ✔ কোডবেসে কোনো .maya ফাইল নেই! (১০০% খাঁটি .lp এবং .lipi — অখণ্ড সার্বভৌম লিপি)${NC}"
else
    echo -e "${RED}  ❌ সতর্কতা: কোডবেসে এখনও ${MAYA_COUNT} টি .maya ফাইল রয়েছে!${NC}"
    exit 1
fi

# WHY: Verify that the compiler executes and generates working binaries even when GCC is completely disabled
FAKE_BIN="$(mktemp -d)"
echo '#!/bin/sh' > "${FAKE_BIN}/gcc"
echo 'echo "CRITICAL: GCC called!" >&2; exit 1' >> "${FAKE_BIN}/gcc"
chmod +x "${FAKE_BIN}/gcc"

TMP_PROBE="/tmp/lipi_no_gcc_audit"
if PATH="${FAKE_BIN}:${PATH}" ./bin/lipc tests/51_minimal_hello.lp -o "${TMP_PROBE}" >/dev/null 2>&1; then
    if "${TMP_PROBE}" >/dev/null 2>&1; then
        echo -e "${GREEN}  ✔ GCC মাস্কিং টেস্ট সফল: ০% GCC নির্ভরতা নিশ্চিত (সম্পূর্ণ স্বয়ংসম্পূর্ণ)!${NC}"
    else
        echo -e "${RED}  ❌ GCC মাস্কিং টেস্ট রানটাইম ব্যর্থ!${NC}"
        rm -rf "${FAKE_BIN}" "${TMP_PROBE}"
        exit 1
    fi
    rm -rf "${FAKE_BIN}" "${TMP_PROBE}"
else
    echo -e "${RED}  ❌ GCC মাস্কিং টেস্ট সংকলন ব্যর্থ!${NC}"
    rm -rf "${FAKE_BIN}"
    exit 1
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🎉 সকল ধাপ ও পরীক্ষা সফল! লিপি এখন ১০০% সার্বভৌম ও আত্মনির্ভর!  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
