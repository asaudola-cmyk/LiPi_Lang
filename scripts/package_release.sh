#!/usr/bin/env bash
# ==============================================================================
# 👑 LIPI SOVEREIGN RELEASE PACKAGER (scripts/package_release.sh)
# ⚡ Bundles Standalone Binaries, Standard Library & Checksums for GitHub Releases
# ==============================================================================

set -euo pipefail

CYAN='\033[38;2;0;255;204m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

LIPI_VERSION_BENGALI="প্রথম ১.০.০"
VERSION="1.0.0"  # SemVer for filenames
LIPI_CODENAME="সোভেরিন"
# WHY: Version permanently locked at First 1.0.0 (প্রথম ১.০.০) per user directive
ARCH="linux-x86_64"
RELEASE_NAME="lipi-v${VERSION}-${ARCH}"
RELEASE_DIR="dist/${RELEASE_NAME}"
TARBALL="dist/${RELEASE_NAME}.tar.gz"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  👑 PACKAGING LIPI SOVEREIGN RELEASE TARBALL (${RELEASE_NAME})       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ১. বিল্ড ডিরেক্টরি তৈরি
rm -rf "${RELEASE_DIR}" "${TARBALL}"
mkdir -p "${RELEASE_DIR}/bin" "${RELEASE_DIR}/universe" "${RELEASE_DIR}/docs"

# ২. মূল বাইনারিসমূহ কপি (100% Pure Lipi Sovereign Binaries)
echo -e "${YELLOW}[১] সার্বভৌম বাইনারিসমূহ প্যাকেজ করা হচ্ছে...${NC}"
cp bin/lipc "${RELEASE_DIR}/bin/"
cp bin/lipc_bin "${RELEASE_DIR}/bin/"
cp bin/lipi "${RELEASE_DIR}/bin/"
cp bin/lipipkg "${RELEASE_DIR}/bin/"
cp bin/lipidbg "${RELEASE_DIR}/bin/"
cp bin/lipirepl "${RELEASE_DIR}/bin/"
cp bin/lipifmt "${RELEASE_DIR}/bin/"
cp bin/lipilsp "${RELEASE_DIR}/bin/"
cp bin/lipiconvert "${RELEASE_DIR}/bin/"
chmod +x "${RELEASE_DIR}/bin/"*

# ৩. স্ট্যান্ডার্ড লাইব্রেরি ও ইউনিভার্স মডিউল কপি
echo -e "${YELLOW}[২] স্ট্যান্ডার্ড লাইব্রেরি ও ইউনিভার্স কপি করা হচ্ছে...${NC}"
cp -r universe/* "${RELEASE_DIR}/universe/"
cp -r docs/* "${RELEASE_DIR}/docs/"

# ৪. লাইসেন্স, ইনস্টলার ও রিডমি
cp README.md LICENSE install.sh "${RELEASE_DIR}/"

# ৫. টারবল কম্প্রেস
echo -e "${YELLOW}[৩] gzip টারবল তৈরি করা হচ্ছে...${NC}"
tar -czf "${TARBALL}" -C dist "${RELEASE_NAME}"

# ৬. SHA256 চেকসাম তৈরি
cd dist
sha256sum "${RELEASE_NAME}.tar.gz" > "${RELEASE_NAME}.tar.gz.sha256"
cd ..

echo -e "${GREEN}✔ সফলভাবে রিলিজ টারবল তৈরি হয়েছে!${NC}"
echo "  • রিলিজ প্যাকেজ : ${TARBALL} ($(du -h "${TARBALL}" | cut -f1))"
echo "  • SHA256 চেকসাম: dist/${RELEASE_NAME}.tar.gz.sha256"
cat "dist/${RELEASE_NAME}.tar.gz.sha256"
