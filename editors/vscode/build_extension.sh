#!/usr/bin/env bash
# ==============================================================================
# 👑 VS CODE EXTENSION BUILDER & VALIDATOR (editors/vscode/build_extension.sh)
# ⚡ Validates TextMate Grammars, Snippets, Configuration & Packages Extension
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/../../dist/extensions"

mkdir -p "${DIST_DIR}"

echo "======================================================"
echo "📦 Validating Lipi VS Code Extension Components..."
echo "======================================================"

# 1. Validate all JSON configurations using Node.js
node -e '
const fs = require("fs");
const path = require("path");
const dir = process.argv[1];

const jsonFiles = [
  "package.json",
  "language-configuration.json",
  "syntaxes/lipi.tmLanguage.json",
  "snippets/lipi.json"
];

let failed = false;
for (const relPath of jsonFiles) {
  const fullPath = path.join(dir, relPath);
  try {
    const content = fs.readFileSync(fullPath, "utf8");
    JSON.parse(content);
    console.log(`  ✔ Valid JSON syntax: ${relPath}`);
  } catch (err) {
    console.error(`  ❌ Invalid JSON in ${relPath}: ${err.message}`);
    failed = true;
  }
}

if (failed) {
  process.exit(1);
}
' "${SCRIPT_DIR}"

# 2. Package tar.gz bundle for direct editor installation
ARCHIVE_NAME="vscode-lipi-v1.0.0.tar.gz"
echo ""
echo "📦 Packaging VS Code Lipi Extension Archive (${ARCHIVE_NAME})..."

PACKAGE_ITEMS=(
  "package.json"
  "language-configuration.json"
  "extension.js"
  "README.md"
  "syntaxes"
  "snippets"
)

# Add icons if directory exists
if [ -d "${SCRIPT_DIR}/icons" ]; then
  PACKAGE_ITEMS+=("icons")
fi

tar -czf "${DIST_DIR}/${ARCHIVE_NAME}" -C "${SCRIPT_DIR}" "${PACKAGE_ITEMS[@]}"

echo "  ✔ Extension archive created: ${DIST_DIR}/${ARCHIVE_NAME}"
echo "  • Files included: ${PACKAGE_ITEMS[*]}"

# 3. If vsce is installed, package VSIX
if command -v vsce &>/dev/null; then
  echo ""
  echo "📦 Packaging VSIX with vsce..."
  (cd "${SCRIPT_DIR}" && vsce package --out "${DIST_DIR}/lipi-language-1.0.0.vsix")
  echo "  ✔ VSIX package created: ${DIST_DIR}/lipi-language-1.0.0.vsix"
fi

echo ""
echo "======================================================"
echo "✔ Lipi VS Code Extension built and validated successfully!"
echo "======================================================"
