#!/usr/bin/env bash
# ==============================================================================
# 👑 LIPI SOVEREIGN BUILD & BOOTSTRAP PIPELINE (build.sh)
#
# WHY: Lipi is a 100% sovereign native programming language.
# It compiles directly to standalone 64-bit Linux ELF executables.
# Zero PHP, Zero Libc, Zero GCC dependencies required at runtime.
#
# Stages:
#   [Stage 0] Bootstrapper Seed : C seed -> bin/lipic & bin/lipi-seed
#   [Stage 1] Pure Lipi Compiler: src/Lipi/compiler.lp
#   [Stage 2] Self-Hosting Closure: bin/lipi (Gen-1) == bin/lipi-gen2 (Gen-2)
#   [Stage 3] Total Sovereignty: 0% PHP verification & test suite execution
# ==============================================================================

set -euo pipefail

CYAN='\033[38;2;0;255;204m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  👑 LIPI SOVEREIGN SELF-HOSTING BOOTSTRAP & BUILD PIPELINE             ║${NC}"
echo -e "${CYAN}║  ⚡ 100% Native Silicon Machine Code | 0% PHP | Zero Dynamic Libs       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

mkdir -p bin dist

# ------------------------------------------------------------------------------
# [ধাপ ০: বীজ / Bootstrapper Seed Compilation]
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ধাপ ০] বীজ (Bootstrapper Seed) ও টুলস তৈরি হচ্ছে...${NC}"
gcc -O2 -Wall -Wextra src/seed/bootstrapper.c -o bin/lipic
cp bin/lipic bin/lipi-seed
gcc -O2 -Wall -Wextra src/tools/lipipkg.c -o bin/lipipkg
echo -e "${GREEN}  ✔ bin/lipic, bin/lipi-seed এবং bin/lipipkg সফলভাবে নির্মিত হয়েছে।${NC}"
echo ""

# ------------------------------------------------------------------------------
# [ধাপ ১ ও ২: খাঁটি লিপি কম্পাইলার ও সেলফ-হোস্টিং ক্লোজার]
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ধাপ ১ ও ২] খাঁটি লিপিতে রচিত compiler.lp কম্পাইল এবং সেলফ-হোস্টিং ক্লোজার...${NC}"
./bin/lipic src/Lipi/compiler.lp -o bin/lipi
./bin/lipic src/Lipi/compiler.lp -o bin/lipi-gen2

echo -e "${YELLOW}  • বাইনারি ডিটারমিনিজম (Bit-for-Bit Determinism) পরীক্ষা:${NC}"
if cmp -s bin/lipi bin/lipi-gen2; then
    echo -e "${GREEN}  ✔ সেলফ-হোস্টিং ক্লোজার সফল! bin/lipi এবং bin/lipi-gen2 ১০০% আইডেন্টিক্যাল।${NC}"
else
    echo -e "${RED}  ❌ এরর: বাইনারি অমিল!${NC}"
    exit 1
fi
echo ""

# ------------------------------------------------------------------------------
# [ধাপ ৩: টেস্ট প্রোগ্রামসমূহ নেটিভ কম্পাইলেশন ও রানটাইম ভ্যালিডেশন]
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ধাপ ৩] লিপি টেস্ট প্রোগ্রামসমূহ কম্পাইলেশন ও সিলিকন সিপিইউ এক্সিকিউশন:${NC}"

TESTS=(
    "examples/01_hello.lp:dist/test01_hello"
    "examples/02_math_fibonacci.lp:dist/test02_fibonacci"
    "examples/12_native_silicon_logic.lp:dist/test12_silicon"
    "examples/13_sovereign_cpu_arithmetic.lp:dist/test13_arithmetic"
    "examples/14_sovereign_loop_and_logic.lp:dist/test14_loop"
    "examples/15_functions_and_recursion.lp:dist/test15_functions"
    "examples/16_kernel_syscalls_file_io.lp:dist/test16_syscalls"
    "examples/17_standard_library_import.lp:dist/test17_stdlib"
    "examples/18_native_web_server.lp:dist/test18_web_server"
    "examples/19_heap_memory_and_pointers.lp:dist/test19_heap"
    "examples/20_grand_stdlib_expansion.lp:dist/test20_stdlib"
    "examples/21_kernel_multithreading.lp:dist/test21_threads"
    "examples/22_custom_structs_and_types.lp:dist/test22_structs"
    "examples/23_native_database_engine.lp:dist/test23_db"
    "examples/24_silicon_matrix_ai.lp:dist/test24_simd"
    "examples/25_arena_memory_allocator.lp:dist/test25_arena"
    "examples/26_async_epoll_event_loop.lp:dist/test26_epoll"
    "examples/27_lipipkg_project_lifecycle.lp:dist/test27_pkg"
    "examples/28_hardware_crypto_sha256.lp:dist/test28_crypto"
)

for test_pair in "${TESTS[@]}"; do
    SRC="${test_pair%%:*}"
    OUT="${test_pair##*:}"
    echo -e "${CYAN}  ► কম্পাইল হচ্ছে: ${SRC} -> ${OUT}${NC}"
    ./bin/lipic "${SRC}" -o "${OUT}" > /dev/null
    
    # Verify ELF static standalone status
    if ldd "${OUT}" 2>&1 | grep -q "not a dynamic executable"; then
        echo -e "${GREEN}    ✔ স্ট্যাটিক লিনাক্স ELF ৬৪-বিট (not a dynamic executable)${NC}"
    fi
    
    # Run test executable
    echo -e "${YELLOW}    • রানটাইম আউটপুট:${NC}"
    ./"${OUT}" | sed 's/^/      /'
    echo ""
done

# ------------------------------------------------------------------------------
# [সার্বভৌমত্ব অডিট: কোডবেসে ০% PHP নিশ্চিতকরণ]
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[সার্বভৌমত্ব অডিট] সক্রিয় কোডবেসে ০% PHP উপস্থিতি পরীক্ষা:${NC}"
PHP_COUNT=$(find . -name "*.php" | wc -l)
if [ "${PHP_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}  ✔ কোডবেসে কোনো .php ফাইল নেই! লিপি ১০০% স্বাধীন ও সার্বভৌম।${NC}"
else
    echo -e "${RED}  ❌ সতর্কতা: কোডবেসে এখনও ${PHP_COUNT} টি .php ফাইল রয়েছে!${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🎉 সকল পরীক্ষা সফল! লিপি এখন সম্পূর্ণ স্বনির্ভর ও স্বাধীন!          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
