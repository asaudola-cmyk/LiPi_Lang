#!/usr/bin/env bash
# ==============================================================================
# 👑 LIPI AUTOMATED REGRESSION TEST RUNNER (tests/run_tests.sh)
# ⚡ Verifies all 42 silicon hardware test cases across all horizons
# ==============================================================================

set -euo pipefail

CYAN='\033[38;2;0;255;204m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${BASE_DIR}"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🧪 LIPI SUITE REGRESSION TEST ENGINE                                  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"

mkdir -p dist

PASSED=0
FAILED=0

EXTRA_FLAG=""
KEEP_BINARIES=0
INCLUDE_MAYA=0
for arg in "$@"; do
    if [[ "${arg}" == "--direct-elf" || "${arg}" == "--baremetal" ]]; then
        EXTRA_FLAG="--direct-elf"
        echo -e "${CYAN}⚡ Running in DIRECT MACHINE CODE (Zero-GCC) Mode 👑${NC}"
    elif [[ "${arg}" == "--keep-binaries" ]]; then
        KEEP_BINARIES=1
    elif [[ "${arg}" == "--with-maya" || "${arg}" == "--all" ]]; then
        INCLUDE_MAYA=1
        echo -e "${CYAN}🌌 Including Maya Sovereign Heritage Test Suite (${NC}"
    fi
done

# WHY: Collect all regression test files dynamically in sorted order (including test_web_router)
mapfile -t TESTS < <(find tests -maxdepth 1 -name "*.lp" | sort)
if [[ "${INCLUDE_MAYA}" -eq 1 ]]; then
    mapfile -t MAYA_TESTS < <(find tests/maya_suite -maxdepth 1 -name "*.lp" | sort)
    TESTS+=("${MAYA_TESTS[@]}")
fi

for test_file in "${TESTS[@]}"; do
    name="$(basename "${test_file}" .lp)"
    out="dist/test_${name}"
    echo -n "  • Testing ${name}... "
    if ./bin/lipc ${EXTRA_FLAG} "${test_file}" -o "${out}" > /dev/null 2>&1; then
        if ./"${out}" > /dev/null 2>&1; then
            echo -e "${GREEN}PASS ✔${NC}"
            PASSED=$((PASSED + 1))
        else
            echo -e "${RED}RUNTIME FAIL ✖${NC}"
            FAILED=$((FAILED + 1))
        fi
    else
        echo -e "${RED}COMPILE FAIL ✖${NC}"
        FAILED=$((FAILED + 1))
    fi
    # WHY: Keep dist/ clean from 60+ generated binary artifacts unless explicitly requested
    if [[ "${KEEP_BINARIES}" -eq 0 ]]; then
        rm -f "${out}"
    fi
done

echo ""
echo -e "${CYAN}========================================================================${NC}"
echo -e "Total Tests: $((PASSED + FAILED)) | ${GREEN}Passed: ${PASSED}${NC} | ${RED}Failed: ${FAILED}${NC}"
echo -e "${CYAN}========================================================================${NC}"

if [ "${FAILED}" -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL ${PASSED} REGRESSION TESTS PASSED!${NC}"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED!${NC}"
    exit 1
fi
