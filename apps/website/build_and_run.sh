#!/usr/bin/env bash
# ==============================================================================
# 👑 LIPI SOVEREIGN WEB SERVER BUILD & RUN LAUNCHER (build_and_run.sh)
# WHY: Easily compile and run the official Lipi dynamic web server on port 8080.
# ==============================================================================

set -euo pipefail

CYAN='\033[38;2;0;255;204m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  👑 LIPI SOVEREIGN DYNAMIC WEB SERVER BUILD & RUNNER                   ║${NC}"
echo -e "${CYAN}║  ⚡ 100% Native Silicon Machine Code | Direct Kernel Sockets | 0% PHP   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

echo -e "${YELLOW}[১] খাঁটি লিপি কম্পাইলার দিয়ে server.lp সংকলন করা হচ্ছে...${NC}"
./bin/lipic apps/website/server.lp -o apps/website/lipi_server

echo -e "${GREEN}  ✔ বাইনারি তৈরি সম্পন্ন: apps/website/lipi_server${NC}"
echo ""

echo -e "${YELLOW}[২] লিপি সার্বভৌম ওয়েব সার্ভার চালু করা হচ্ছে (Port 8080)...${NC}"
echo -e "${CYAN}  👉 ব্রাউজারে খুলুন: http://localhost:8080/ অথবা http://127.0.0.1:8080/${NC}"
echo -e "${YELLOW}  (বন্ধ করতে কীবোর্ডে Ctrl+C চাপুন)${NC}"
echo ""

exec ./apps/website/lipi_server
