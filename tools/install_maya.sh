#!/usr/bin/env bash
# ==============================================================================
# Maya Sovereign Toolchain Global Installer
# ==============================================================================
set -euo pipefail

MAYA_HOME="${HOME}/.maya"
INSTALL_BIN_DIR="${HOME}/.local/bin"

echo "================================================================================"
echo "🔮 Installing Maya Sovereign Programming Language Ecosystem"
echo "================================================================================"

mkdir -p "${MAYA_HOME}/bin"
mkdir -p "${MAYA_HOME}/pkg"
mkdir -p "${MAYA_HOME}/cache"
mkdir -p "${INSTALL_BIN_DIR}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "📦 Installing sovereign compiler binaries into ${MAYA_HOME}/bin/..."
cp -f "${SCRIPT_DIR}/bin/maya" "${MAYA_HOME}/bin/maya"
cp -f "${SCRIPT_DIR}/bin/maya_self_hosted" "${MAYA_HOME}/bin/maya_self_hosted"
cp -f "${SCRIPT_DIR}/bin/maya_selfhosted" "${MAYA_HOME}/bin/maya_selfhosted"
cp -f "${SCRIPT_DIR}/bin/maya_univ" "${MAYA_HOME}/bin/maya_univ"
cp -f "${SCRIPT_DIR}/bin/maya_bootstrap" "${MAYA_HOME}/bin/maya_bootstrap"
chmod +x "${MAYA_HOME}/bin/"*

echo "📚 Synchronizing Maya Universe standard library to ${MAYA_HOME}/universe/..."
mkdir -p "${MAYA_HOME}/universe"
cp -r "${SCRIPT_DIR}/universe/"* "${MAYA_HOME}/universe/"

echo "🔗 Linking 'maya' executable into ${INSTALL_BIN_DIR}/maya..."
ln -sf "${MAYA_HOME}/bin/maya" "${INSTALL_BIN_DIR}/maya"

echo "================================================================================"
echo "✅ Maya Sovereign Toolchain successfully installed!"
echo "   Binary Path  : ${INSTALL_BIN_DIR}/maya"
echo "   MAYA_HOME    : ${MAYA_HOME}"
echo "   Architecture : x86_64-unknown-linux-freestanding (Zero-Libc Native ELF64)"
echo "================================================================================"
echo ""
echo "Test your installation:"
echo "  maya version"
echo "  maya run examples/hello_native.maya"
echo "================================================================================"
