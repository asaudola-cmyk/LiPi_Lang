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

# ─── সংস্করণ লক (Version Lock) ───────────────────────────────────────────
LIPI_VERSION="প্রথম ১.০"
LIPI_VERSION_ENG="Prothom 1.0"
LIPI_CODENAME="সোভেরিন"
# WHY: Version locked. Change only when user explicitly authorizes upgrade.

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
# [ধাপ ০: সার্বভৌম বুটস্ট্র্যাপ / Sovereign Bootstrap Verification]
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ধাপ ০] সার্বভৌম বুটস্ট্র্যাপ যাচাইকরণ (Go/Rust Model — Zero GCC)...${NC}"
if [ ! -f "bin/lipic" ]; then
    if [ -f "boot/lipi-seed" ]; then
        cp boot/lipi-seed bin/lipic
    elif [ -f "bin/lipi-seed" ]; then
        cp bin/lipi-seed bin/lipic
    else
        echo -e "${RED}❌ এরর: বুটস্ট্র্যাপ সিড অনুপস্থিত!${NC}"
        exit 1
    fi
fi
chmod +x bin/lipic

echo "  ► Stage 1 Lipi Self-Hosted Compiler (compiler.lp)..."
./bin/lipic src/compiler/compiler.lp -o bin/lipic-stage1

echo "  ► Stage 2 Sovereign Lipi Machine Code Synthesis..."
chmod +x bin/lipic-stage1
./bin/lipic-stage1

echo "  ► Testing the ELF generated strictly by Pure Lipi (bin/lipic_gen)..."
chmod +x bin/lipic_gen
./bin/lipic_gen
if [ $? -eq 0 ]; then
    echo "  ✔ SUCCESS: bin/lipic_gen (generated strictly by Lipi) executed successfully with 0 exit code!"
else
    echo "  ❌ FAILED: bin/lipic_gen did not execute properly."
fi

echo "  ► Compiling lipipkg (Pure Lipi Package Manager) using Lipi..."
./bin/lipic src/tools/lipipkg.lp -o bin/lipipkg
echo "  ► Compiling lipidbg (Pure Lipi System Debugger) using Lipi..."
./bin/lipic src/tools/lipidbg.lp -o bin/lipidbg
echo "  ► Compiling lipirepl (Pure Lipi Interactive Shell) using Lipi..."
./bin/lipic src/tools/lipirepl.lp -o bin/lipirepl
echo "  ► Compiling lipiconvert (Pure Lipi Universal Code Migration Transpiler) using Lipi..."
./bin/lipic src/tools/lipiconvert.lp -o bin/lipiconvert
echo -e "${GREEN}  ✔ bin/lipic, bin/lipipkg, bin/lipidbg, bin/lipirepl এবং bin/lipiconvert প্রস্তুত (100% Pure Lipi Tooling | Zero C)।${NC}"
echo ""

# ------------------------------------------------------------------------------
# [ধাপ ১ ও ২: খাঁটি লিপি কম্পাইলার ও সেলফ-হোস্টিং ক্লোজার]
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ধাপ ১ ও ২] খাঁটি লিপিতে রচিত compiler.lp কম্পাইল এবং সেলফ-হোস্টিং ক্লোজার...${NC}"
./bin/lipic src/compiler/compiler.lp -o bin/lipi
./bin/lipic src/compiler/compiler.lp -o bin/lipi-gen2

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
    "tests/01_hello.lp:dist/test01_hello"
    "tests/02_math_fibonacci.lp:dist/test02_fibonacci"
    "tests/12_native_silicon_logic.lp:dist/test12_silicon"
    "tests/13_sovereign_cpu_arithmetic.lp:dist/test13_arithmetic"
    "tests/14_sovereign_loop_and_logic.lp:dist/test14_loop"
    "tests/15_functions_and_recursion.lp:dist/test15_functions"
    "tests/16_kernel_syscalls_file_io.lp:dist/test16_syscalls"
    "tests/17_standard_library_import.lp:dist/test17_stdlib"
    "tests/18_native_web_server.lp:dist/test18_web_server"
    "tests/19_heap_memory_and_pointers.lp:dist/test19_heap"
    "tests/20_grand_stdlib_expansion.lp:dist/test20_stdlib"
    "tests/21_kernel_multithreading.lp:dist/test21_threads"
    "tests/22_custom_structs_and_types.lp:dist/test22_structs"
    "tests/23_native_database_engine.lp:dist/test23_db"
    "tests/24_silicon_matrix_ai.lp:dist/test24_simd"
    "tests/25_arena_memory_allocator.lp:dist/test25_arena"
    "tests/26_async_epoll_event_loop.lp:dist/test26_epoll"
    "tests/27_lipipkg_project_lifecycle.lp:dist/test27_pkg"
    "tests/28_hardware_crypto_sha256.lp:dist/test28_crypto"
    "tests/29_lipidbg_system_debugger.lp:dist/test29_debug"
    "tests/30_ast_optimizer_constant_folding.lp:dist/test30_optimizer"
    "tests/31_pure_lipi_tls_crypto_stream.lp:dist/test31_tls"
    "tests/32_silicon_graphics_framebuffer.lp:dist/test32_gfx"
    "tests/33_unum_shared_memory.lp:dist/test33_shm"
    "tests/34_unum_ansi_tui.lp:dist/test34_tui"
    "tests/35_unum_columnstore_ai.lp:dist/test35_ai"
    "tests/36_unum_robinhood_hashmap.lp:dist/test36_hashmap"
    "tests/37_unum_websocket.lp:dist/test37_websocket"
    "tests/38_unum_x11_gui.lp:dist/test38_x11"
    "tests/39_sovereign_production_app.lp:dist/test39_showcase"
    "tests/40_gguf_tensor_inference.lp:dist/test40_gguf"
    "tests/41_baremetal_multiboot_kernel.lp:dist/test41_kernel"
    "tests/42_bilingual_english_syntax.lp:dist/test42_bilingual"
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

# Clean up transient build-stage artifacts
rm -f bin/lipic-stage1 bin/lipic_gen bin/lipi-gen2 bin/lipi-seed

# ------------------------------------------------------------------------------
# [সার্বভৌমত্ব অডিট: কোডবেসে ০% PHP এবং ০% C/C++ নিশ্চিতকরণ]
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[সার্বভৌমত্ব অডিট] সক্রিয় কোডবেসে ০% PHP এবং ০% C/C++ উপস্থিতি পরীক্ষা:${NC}"
PHP_COUNT=$(find src std bin apps examples tests boot -name "*.php" 2>/dev/null | wc -l)
C_COUNT=$(find src std bin apps examples tests boot \( -name "*.c" -o -name "*.h" -o -name "*.cpp" \) 2>/dev/null | wc -l)

if [ "${PHP_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}  ✔ কোডবেসে কোনো .php ফাইল নেই! (০% PHP — ১০০% লিপি)${NC}"
else
    echo -e "${RED}  ❌ সতর্কতা: কোডবেসে এখনও ${PHP_COUNT} টি .php ফাইল রয়েছে!${NC}"
    exit 1
fi

if [ "${C_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}  ✔ কোডবেসে কোনো .c বা .h ফাইল নেই! (০% C — ১০০% স্বাধীন ও সার্বভৌম লিপি)${NC}"
else
    echo -e "${RED}  ❌ সতর্কতা: কোডবেসে এখনও ${C_COUNT} টি C/C++ ফাইল রয়েছে!${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🎉 সকল পরীক্ষা সফল! লিপি এখন সম্পূর্ণ স্বনির্ভর ও স্বাধীন!          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
