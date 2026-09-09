#!/usr/bin/env bash
# ==============================================================================
# 👑 VS CODE EXTENSION PACKAGER (editors/vscode-lipi/build_extension.sh)
# ⚡ Bundles VS Code TextMate Grammar & Language Configuration
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/../../dist/extensions"

mkdir -p "${DIST_DIR}"

echo "Building VS Code Lipi Extension Archive..."
tar -czf "${DIST_DIR}/vscode-lipi-v1.0.0.tar.gz" -C "${SCRIPT_DIR}" package.json language-configuration.json README.md syntaxes/

echo "✔ Extension packaged successfully: ${DIST_DIR}/vscode-lipi-v1.0.0.tar.gz"
