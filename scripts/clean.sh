#!/usr/bin/env bash
# ==============================================================================
# 👑 LIPI PROJECT REPOSITORY CLEANUP UTILITY (scripts/clean.sh)
# ⚡ Purges temporary build artifacts, test binaries, and scratch files.
# Preserves canonical source trees, compiler binaries, and release assets.
# ==============================================================================

set -euo pipefail

CYAN='\033[38;2;0;255;204m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${BASE_DIR}"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🧹 LIPI REPOSITORY DEEP CLEANUP & ARTIFACT PURGE ENGINE              ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"

# 1. Clean scratch test binaries and build outputs from dist/ (preserving .gitkeep and release archives)
echo -e "${YELLOW}▶ Purging temporary scratch binaries in dist/...${NC}"
find dist/ -mindepth 1 -not -name ".gitkeep" -not -name "*.vsix" -not -name "*.iso" -delete 2>/dev/null || true
echo -e "${GREEN}  ✔ dist/ directory sanitized (release assets and .gitkeep preserved).${NC}"

# 2. Clean temporary test artifacts from bin/ (preserving core compiler and tools)
echo -e "${YELLOW}▶ Sanitizing bin/ directory...${NC}"
rm -f bin/test_* bin/*.spv 2>/dev/null || true
echo -e "${GREEN}  ✔ bin/ directory sanitized (only canonical compiler & tools retained).${NC}"

# 3. Clean editor swap files, backup files, and temporary buffers
echo -e "${YELLOW}▶ Removing editor temporary and swap files...${NC}"
find . -type f \( -name "*~" -o -name "*.swp" -o -name "*.tmp" -o -name "*.log" \) -not -path "./.git/*" -delete 2>/dev/null || true
echo -e "${GREEN}  ✔ Editor and OS temporary files cleaned.${NC}"

# 4. Clean temporary test IPC and socket files
echo -e "${YELLOW}▶ Cleaning temporary test sockets and shared memory probes...${NC}"
rm -f /tmp/lipi_* /tmp/libtest_* /tmp/test.wasm 2>/dev/null || true
echo -e "${GREEN}  ✔ Temporary system test probes purged.${NC}"

echo ""
echo -e "${GREEN}🎉 LIPI REPOSITORY SANITIZATION COMPLETE! Clean and production-ready.${NC}"
