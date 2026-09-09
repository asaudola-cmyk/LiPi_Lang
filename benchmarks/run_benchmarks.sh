#!/usr/bin/env bash
# ==============================================================================
# 👑 GRAND MULTI-LANGUAGE BENCHMARK SUITE (benchmarks/run_benchmarks.sh)
# ⚡ Lipi vs C vs C++ vs Rust vs Zig vs Go vs C# vs Swift vs Bun (TS) vs Node (JS) vs Python
# ==============================================================================

set -euo pipefail

CYAN='\033[38;2;0;255;204m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  👑 LIPI PERFORMANCE BENCHMARK SUITE: SILICON SPEED AUDIT              ║${NC}"
echo -e "${CYAN}║  ⚡ 10,000,000 Arithmetic Loop Showdown Across 11 Major Languages       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

python3 benchmarks/run_all_benchmarks.py
