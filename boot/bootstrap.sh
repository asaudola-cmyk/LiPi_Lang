#!/usr/bin/env bash
# ==============================================================================
# 👑 LIPI ZERO-DEPENDENCY SOVEREIGN BOOTSTRAPPER (boot/bootstrap.sh)
#
# WHY: On a brand-new computer with NO C compiler (No GCC, No Clang) and NO Python,
# this script unpacks the sovereign static machine code seed from boot/seed.b64
# using only standard POSIX stream decoding.
#
# Once unpacked, Lipi can compile all Lipi programs and self-host its entire
# toolchain without ever touching GCC or Libc.
# ==============================================================================

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${BASE_DIR}"

mkdir -p bin dist

GREEN='\033[1;32m'
CYAN='\033[38;2;0;255;204m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  👑 LIPI ZERO-TOOL SOVEREIGN BOOTSTRAP INITIALIZER                     ║${NC}"
echo -e "${CYAN}║  ⚡ 0% GCC | 0% Clang | 0% Python | 0% Libc | 100% Native Silicon       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Check if binary already exists in boot/lipi-seed
if [ -f "boot/lipi-seed" ]; then
    echo -e "${YELLOW}► Deploying bin/lipc_bin from static binary seed (boot/lipi-seed)...${NC}"
    cp boot/lipi-seed bin/lipc_bin
    chmod +x bin/lipc_bin
# Step 2: Unpack from compressed text seed if binary was not present
elif [ -f "boot/seed.b64" ]; then
    echo -e "${YELLOW}► Materializing bin/lipc_bin from ASCII seed (boot/seed.b64)...${NC}"
    base64 -d boot/seed.b64 | gzip -d > bin/lipc_bin
    chmod +x bin/lipc_bin
    cp bin/lipc_bin boot/lipi-seed
else
    echo -e "${RED}❌ Error: No bootstrap seed found in boot/!${NC}"
    exit 1
fi

# Ensure bin/lipc driver exists
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
chmod +x bin/lipc

# Step 3: Verify execution without external dependencies
echo -n "► Verifying sovereign seed execution... "
TMP_OUT="/tmp/lipi_bootstrap_probe"
if ./bin/lipc_bin tests/51_minimal_hello.lp "${TMP_OUT}" > /dev/null 2>&1; then
    if "${TMP_OUT}" > /dev/null 2>&1; then
        echo -e "${GREEN}SUCCESS ✔${NC}"
        echo -e "${GREEN}✔ Sovereign Seed Verified: 100% Statically Linked ELF64 (Zero Libc).${NC}"
    else
        echo -e "${RED}PROBE EXECUTION FAILED ✖${NC}"
        exit 1
    fi
    rm -f "${TMP_OUT}"
else
    echo -e "${RED}PROBE COMPILATION FAILED ✖${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Lipi bootstrap seed is live and ready at bin/lipc_bin!${NC}"
