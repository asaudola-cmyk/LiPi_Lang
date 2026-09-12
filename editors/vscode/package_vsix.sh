#!/usr/bin/env bash
# ==============================================================================
# 👑 LIPI VS CODE STANDALONE VSIX PACKAGER (editors/vscode/package_vsix.sh)
# ⚡ Standards-Compliant OPC (Open Packaging Conventions) .vsix Builder
# Zero NPM / Zero VSCE Required — 100% Native Automated Packaging
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
STAGE_DIR="/tmp/vsix_stage_lipi_$$"

mkdir -p "${DIST_DIR}"
rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}/extension"

echo "======================================================"
echo "📦 Building Sovereign Lipi VS Code Extension (.vsix)..."
echo "======================================================"

# 1. Generate standard Open Packaging Conventions [Content_Types].xml
cat <<'EOF' > "${STAGE_DIR}/[Content_Types].xml"
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="json" ContentType="application/json" />
  <Default Extension="vsixmanifest" ContentType="text/xml" />
  <Default Extension="js" ContentType="application/javascript" />
  <Default Extension="md" ContentType="text/markdown" />
  <Default Extension="txt" ContentType="text/plain" />
  <Default Extension="png" ContentType="image/png" />
  <Default Extension="svg" ContentType="image/svg+xml" />
  <Default Extension="woff" ContentType="font/woff" />
</Types>
EOF

# 2. Generate standard extension.vsixmanifest
cat <<'EOF' > "${STAGE_DIR}/extension.vsixmanifest"
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Id="lipi-language" Version="2.0.0" Publisher="lipi-lang" />
    <DisplayName>Lipi Sovereign Programming Language</DisplayName>
    <Description>Official Language Support for Lipi 2.0 (Tri-Syntax, Direct Silicon Compiler)</Description>
    <Categories>Programming Languages,Snippets</Categories>
    <Icon>extension/icons/icon.png</Icon>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code" />
  </Installation>
  <Dependencies />
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true" />
    <Asset Type="Microsoft.VisualStudio.Services.Icons.Default" Path="extension/icons/icon.png" Addressable="true" />
  </Assets>
</PackageManifest>
EOF

# 3. Copy extension assets into staged directory
cp "${SCRIPT_DIR}/package.json" "${STAGE_DIR}/extension/"
cp "${SCRIPT_DIR}/language-configuration.json" "${STAGE_DIR}/extension/"
cp "${SCRIPT_DIR}/extension.js" "${STAGE_DIR}/extension/"
cp "${SCRIPT_DIR}/README.md" "${STAGE_DIR}/extension/"
cp "${ROOT_DIR}/LICENSE" "${STAGE_DIR}/extension/"

mkdir -p "${STAGE_DIR}/extension/syntaxes"
cp "${SCRIPT_DIR}/syntaxes/lipi.tmLanguage.json" "${STAGE_DIR}/extension/syntaxes/"

mkdir -p "${STAGE_DIR}/extension/snippets"
cp "${SCRIPT_DIR}/snippets/lipi.json" "${STAGE_DIR}/extension/snippets/"

# Copy icons if present
if [ -d "${SCRIPT_DIR}/icons" ]; then
  cp -r "${SCRIPT_DIR}/icons" "${STAGE_DIR}/extension/"
fi

# 4. Pack into .vsix OPC archive
VSIX_PATH="${DIST_DIR}/lipi-language-2.0.0.vsix"
rm -f "${VSIX_PATH}"

(cd "${STAGE_DIR}" && zip -q -r "${VSIX_PATH}" "[Content_Types].xml" "extension.vsixmanifest" "extension")

# Clean up staging directory
rm -rf "${STAGE_DIR}"

echo "  ✔ Successfully created: ${VSIX_PATH}"
echo "  • Archive size: $(du -h "${VSIX_PATH}" | cut -f1)"
echo "======================================================"
