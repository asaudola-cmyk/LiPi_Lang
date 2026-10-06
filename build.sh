#!/bin/bash
# ==============================================================================
# 👑 LIPI SOVEREIGN BUILD SCRIPT (build.sh)
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
        ./src/boot/lipi-seed src/compiler/driver_cli.lp bin/lipc_bin
        chmod +x bin/lipc_bin
        cp -f bin/lipc_bin bin/lipc
        chmod +x bin/lipc
    elif [ -f "src/boot/seed.b64" ]; then
        (base64 -d src/boot/seed.b64 > bin/lipc 2>/dev/null || \
         base64 --decode src/boot/seed.b64 > bin/lipc 2>/dev/null || \
         base64 -D src/boot/seed.b64 > bin/lipc 2>/dev/null)
        chmod +x bin/lipc
        cp -f bin/lipc bin/lipc_bin
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
    [ -x "bin/lipipkg" ] || (./bin/lipc src/tools/lipipkg.lp bin/lipipkg && chmod +x bin/lipipkg)
    [ -x "bin/lipi-build" ] || (./bin/lipc build.lp bin/lipi-build && chmod +x bin/lipi-build)
    [ -x "bin/lipi-test" ] || (./bin/lipc tests/run_tests.lp bin/lipi-test && chmod +x bin/lipi-test)
    echo "👑 100% Native LiPi Developer Toolchain Ready in bin/!"
fi
