#!/bin/bash
# ==============================================================================
# Lipi Build Script (build.sh)
# Usage: ./build.sh [test|clean|install]
# ==============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

mkdir -p bin dist

# 1. Bootstrap compiler if needed
if [ ! -x "bin/lipc" ]; then
    echo "🌱 Bootstrapping Stage-3 Compiler from genesis seed..."
    chmod +x src/boot/lipi-seed 2>/dev/null || true
    if [ -f "src/boot/lipi-seed" ]; then
        ./src/boot/lipi-seed src/compiler/driver_cli.lp bin/lipc_stage1
        chmod +x bin/lipc_stage1
        ./bin/lipc_stage1 src/compiler/driver_cli.lp bin/lipc
        chmod +x bin/lipc
        cp -f bin/lipc bin/lipc_bin
        cp -f bin/lipc bin/lipc_micro
        chmod +x bin/lipc_bin bin/lipc_micro
        rm -f bin/lipc_stage1
    elif [ -f "src/boot/seed.b64" ]; then
        (base64 -d src/boot/seed.b64 > bin/lipc_seed 2>/dev/null || \
         base64 --decode src/boot/seed.b64 > bin/lipc_seed 2>/dev/null || \
         base64 -D src/boot/seed.b64 > bin/lipc_seed 2>/dev/null)
        chmod +x bin/lipc_seed
        ./bin/lipc_seed src/compiler/driver_cli.lp bin/lipc
        chmod +x bin/lipc
        cp -f bin/lipc bin/lipc_bin
        cp -f bin/lipc bin/lipc_micro
        chmod +x bin/lipc_bin bin/lipc_micro
        rm -f bin/lipc_seed
    fi
    echo "✔ Compiler bootstrapped: bin/lipc"
fi

# 2. Build core runner and CLI
if [ ! -x "bin/lipi" ]; then
    echo "⚙️ Compiling bin/lipi..."
    ./bin/lipc src/tools/lipi.lp bin/lipi
    chmod +x bin/lipi
fi

if [ "$1" = "test" ]; then
    ./bin/lipi test
elif [ "$1" = "install" ]; then
    ./install.sh
elif [ "$1" = "clean" ]; then
    rm -rf bin/ dist/ build/ *.bin /tmp/lipi_tst_*
    echo "🧹 Cleaned build artifacts."
else
    # Compile core toolchain
    if [ ! -x "bin/aati" ]; then
        ./bin/lipc src/tools/aati.lp bin/aati
        chmod +x bin/aati
        cp -f bin/aati bin/haat
        cp -f bin/aati bin/lipipkg
        chmod +x bin/haat bin/lipipkg
    fi
    [ -x "bin/lipifmt" ] || (./bin/lipc src/tools/lipifmt.lp bin/lipifmt --kavach && chmod +x bin/lipifmt)
    [ -x "bin/lipidoc" ] || (./bin/lipc src/tools/lipidoc.lp bin/lipidoc --kavach && chmod +x bin/lipidoc)
    [ -x "bin/lipi_akhara" ] || (./bin/lipc src/tools/lipi_akhara.lp bin/lipi_akhara --kavach && chmod +x bin/lipi_akhara)
    [ -x "bin/lipi-build" ] || (./bin/lipc build.lp bin/lipi-build && chmod +x bin/lipi-build)
    [ -x "bin/lipi-test" ] || (./bin/lipc tests/run_tests.lp bin/lipi-test && chmod +x bin/lipi-test)
    echo "Native Lipi developer toolchain built in bin/"
fi
