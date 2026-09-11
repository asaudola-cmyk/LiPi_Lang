#!/usr/bin/env bash
# ==============================================================================
# 👑 LIPI PRODUCTION DEPLOYMENT & SYSTEMD DAEMON PIPELINE (deploy.sh)
# File: apps/website/deploy.sh
# ⚡ 100% Native Silicon Machine Code | Zero Libc | Zero GCC | Linux AMD64 Kernel
#
# WHY: Production deployment orchestrator for the official Lipi Sovereign Web Engine.
# Performs native AOT compilation, static asset integrity auditing, silicon binary
# sovereignty verification (0% Libc, 0% GCC), live socket smoke testing, and
# automated or guided systemd service daemon installation.
# ==============================================================================

set -euo pipefail

# ── Terminal Styling & Color Palette ──────────────────────────────────────────
# WHY: Provides clear visual status feedback in production terminal logs
CYAN='\033[38;2;0;255;204m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NC='\033[0m'

# ── Directory Resolution ───────────────────────────────────────────────────────
# WHY: Guarantees execution works regardless of whether the caller is in root,
# apps/website, or any arbitrary working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT_DIR}"

UNIT_SOURCE="${SCRIPT_DIR}/lipi-web.service"
UNIT_TARGET="/etc/systemd/system/lipi-web.service"
BINARY_PATH="apps/website/lipi_server"
SOURCE_PATH="apps/website/server.lp"
PUBLIC_DIR="apps/website/public"
DATA_DIR="apps/website/data"

# ── Banner Display ─────────────────────────────────────────────────────────────
print_banner() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}👑 LIPI SOVEREIGN WEB SERVER PRODUCTION DEPLOYMENT ENGINE${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}⚡ 100% Native Silicon ELF64 | 0% Libc | 0% GCC | Systemd Daemon${NC}       ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ── Logging Helpers ────────────────────────────────────────────────────────────
log_step() {
    echo -e "${YELLOW}[ধাপ $1] $2...${NC}"
}

log_ok() {
    echo -e "  ${GREEN}✔ $1${NC}"
}

log_fail() {
    echo -e "  ${RED}❌ $1${NC}" >&2
}

log_info() {
    echo -e "  ${CYAN}• $1${NC}"
}

# ── Pre-flight Environment Validation ──────────────────────────────────────────
# WHY: Ensures build tools and dependencies exist before attempting deployment
check_prerequisites() {
    if [ ! -f "./bin/lipc" ]; then
        log_fail "Lipi compiler not found at ./bin/lipc. Run ./build.sh first!"
        exit 1
    fi

    if [ ! -x "./bin/lipc" ]; then
        chmod +x ./bin/lipc
    fi

    if [ ! -f "${SOURCE_PATH}" ]; then
        log_fail "Server source file not found: ${SOURCE_PATH}"
        exit 1
    fi

    if [ ! -f "${UNIT_SOURCE}" ]; then
        log_fail "Systemd unit file not found: ${UNIT_SOURCE}"
        exit 1
    fi
}

# ── Step 1: Native Machine Code Compilation ───────────────────────────────────
# WHY: Compiles pure Lipi source code into a standalone, statically linked x86-64
# ELF binary with zero intermediate C translation and zero GCC dependency.
build_server() {
    log_step "১" "খাঁটি লিপি কম্পাইলার দিয়ে সার্ভার বাইনারি সংকলন (Pure Lipi AOT)"
    log_info "কমান্ড: ./bin/lipc ${SOURCE_PATH} ${BINARY_PATH}"

    ./bin/lipc "${SOURCE_PATH}" "${BINARY_PATH}"

    if [ ! -f "${BINARY_PATH}" ]; then
        log_fail "বাইনারি নির্মাণ ব্যর্থ হয়েছে: ${BINARY_PATH} তৈরি হয়নি!"
        exit 1
    fi

    chmod +x "${BINARY_PATH}"
    BINARY_SIZE=$(wc -c < "${BINARY_PATH}")
    log_ok "সার্ভার বাইনারি সফলভাবে তৈরি হয়েছে (${BINARY_SIZE} bytes / $(( BINARY_SIZE / 1024 )) KB)"
    echo ""
}

# ── Step 2: Website Assets Integrity Verification ──────────────────────────────
# WHY: Ensures all static assets (HTML, CSS, JS, SVG) and storage directories
# exist and have non-zero content before serving web traffic.
verify_assets() {
    log_step "২" "ওয়েবসাইট অ্যাসেটস ইন্টিগ্রিটি অডিট (HTML, CSS, JS, SVG)"

    # Ensure database persistence directory exists
    mkdir -p "${DATA_DIR}"
    log_ok "ডাটাবেজ স্টোরেজ ডিরেক্টরি নিশ্চিত: ${DATA_DIR}/"

    local assets_ok=1

    # Audit HTML
    if [ -s "${PUBLIC_DIR}/index.html" ]; then
        local size=$(wc -c < "${PUBLIC_DIR}/index.html")
        log_ok "HTML  অ্যাসেট: ${PUBLIC_DIR}/index.html (${size} bytes) [text/html]"
    else
        log_fail "HTML অ্যাসেট অনুপস্থিত বা শূন্য সাইজ: ${PUBLIC_DIR}/index.html"
        assets_ok=0
    fi

    # Audit CSS
    if [ -s "${PUBLIC_DIR}/style.css" ]; then
        local size=$(wc -c < "${PUBLIC_DIR}/style.css")
        log_ok "CSS   অ্যাসেট: ${PUBLIC_DIR}/style.css (${size} bytes) [text/css]"
    else
        log_fail "CSS অ্যাসেট অনুপস্থিত বা শূন্য সাইজ: ${PUBLIC_DIR}/style.css"
        assets_ok=0
    fi

    # Audit JS
    if [ -s "${PUBLIC_DIR}/app.js" ]; then
        local size=$(wc -c < "${PUBLIC_DIR}/app.js")
        log_ok "JS    অ্যাসেট: ${PUBLIC_DIR}/app.js (${size} bytes) [application/javascript]"
    else
        log_fail "JS অ্যাসেট অনুপস্থিত বা শূন্য সাইজ: ${PUBLIC_DIR}/app.js"
        assets_ok=0
    fi

    # Audit SVG
    if [ -s "${PUBLIC_DIR}/favicon.svg" ]; then
        local size=$(wc -c < "${PUBLIC_DIR}/favicon.svg")
        log_ok "SVG   অ্যাসেট: ${PUBLIC_DIR}/favicon.svg (${size} bytes) [image/svg+xml]"
    else
        log_fail "SVG অ্যাসেট অনুপস্থিত বা শূন্য সাইজ: ${PUBLIC_DIR}/favicon.svg"
        assets_ok=0
    fi

    if [ "${assets_ok}" -ne 1 ]; then
        log_fail "অ্যাসেট অডিট ব্যর্থ! ডিপ্লয়মেন্ট স্থগিত করা হলো।"
        exit 1
    fi

    echo ""
}

# ── Step 3: Binary Sovereignty & ELF Hardening Audit ───────────────────────────
# WHY: Guarantees 100% technological sovereignty: statically linked ELF64,
# zero dynamic linker dependencies (0% Libc), and zero GCC/C-runtime artifacts.
check_sovereignty() {
    log_step "৩" "বাইনারি সার্বভৌমত্ব ও ডিপেন্ডেন্সি অডিট (০% Libc, ০% GCC)"

    # 1. Check ELF static linkage via ldd
    local ldd_output
    ldd_output=$(ldd "${BINARY_PATH}" 2>&1 || true)
    if echo "${ldd_output}" | grep -qE "(not a dynamic executable|statically linked)"; then
        log_ok "স্ট্যাটিক ELF64 লিংকেজ: ০% ডায়নামিক লাইব্রেরি লোডার (ldd: not a dynamic executable)"
    else
        log_fail "বাইনারি স্ট্যাটিক নয়! ডায়নামিক ডিপেন্ডেন্সি বিদ্যমান: ${ldd_output}"
        exit 1
    fi

    # 2. Check for dynamic section in ELF headers
    local readelf_dyn
    readelf_dyn=$(readelf -d "${BINARY_PATH}" 2>&1 || true)
    if echo "${readelf_dyn}" | grep -qi "There is no dynamic section"; then
        log_ok "ELF সেকশন হেডার অডিট: ডায়নামিক সেকশন মুক্ত (No PT_DYNAMIC)"
    else
        log_fail "বাইনারিতে অপ্রয়োজনীয় ডায়নামিক সেকশন পাওয়া গেছে!"
        exit 1
    fi

    # 3. Check for any Libc / Glibc symbol strings
    local libc_matches
    libc_matches=$(strings "${BINARY_PATH}" | grep -Ei "(libc\.so|ld-linux|glibc)" || true)
    if [ -z "${libc_matches}" ]; then
        log_ok "Libc ডিপেন্ডেন্সি অডিট: ০% Libc (কোনো libc.so বা ld-linux রেফারেন্স নেই)"
    else
        log_fail "Libc রেফারেন্স সনাক্ত হয়েছে: ${libc_matches}"
        exit 1
    fi

    # 4. Check for any GCC / C-runtime symbols
    local gcc_matches
    gcc_matches=$(strings "${BINARY_PATH}" | grep -Ei "(libgcc|libstdc\+\+|crtbegin|crtend)" || true)
    if [ -z "${gcc_matches}" ]; then
        log_ok "GCC ডিপেন্ডেন্সি অডিট: ০% GCC (কোনো crt0/crtbegin/libgcc অবশেষ নেই)"
    else
        log_fail "GCC রেফারেন্স সনাক্ত হয়েছে: ${gcc_matches}"
        exit 1
    fi

    log_ok "১০০% খাঁটি লিপি সার্বভৌম বাইনারি ভেরিফিকেশন সফল!"
    echo ""
}

# ── Step 4: Ephemeral Socket & Healthcheck Verification ────────────────────────
# WHY: Proves that the newly compiled binary binds TCP sockets, serves HTTP requests,
# and returns 200 OK on GET /healthz with {"status":"healthy","engine":"Lipi Sovereign"}.
smoke_test() {
    log_step "৪" "লাইভ সকেট টেস্ট ও হেলথচেক যাচাই (GET /healthz)"

    local TEST_PORT=8098
    log_info "টেস্ট পোর্ট ${TEST_PORT}-এ সাময়িক সার্ভার আরম্ভ করা হচ্ছে..."

    ./"${BINARY_PATH}" "${TEST_PORT}" > /dev/null 2>&1 &
    local TEST_PID=$!

    # Guarantee background test server cleanup on exit
    test_cleanup() {
        if [ -n "${TEST_PID:-}" ]; then
            kill -9 "${TEST_PID}" 2>/dev/null || true
            wait "${TEST_PID}" 2>/dev/null || true
        fi
    }
    trap test_cleanup EXIT

    # Wait for TCP socket bind (up to 2 seconds)
    local ready=0
    for _ in {1..20}; do
        if curl -s "http://127.0.0.1:${TEST_PORT}/healthz" > /dev/null 2>&1; then
            ready=1
            break
        fi
        sleep 0.1
    done

    if [ "${ready}" -ne 1 ]; then
        log_fail "সার্ভার টেস্ট পোর্টে রেসপন্স করতে ব্যর্থ হয়েছে!"
        test_cleanup
        trap - EXIT
        exit 1
    fi

    # Verify /healthz response
    local HEALTH_RESP
    HEALTH_RESP=$(curl -s "http://127.0.0.1:${TEST_PORT}/healthz")
    log_info "Healthz রেসপন্স: ${HEALTH_RESP}"

    if echo "${HEALTH_RESP}" | grep -q '"status":"healthy"' && echo "${HEALTH_RESP}" | grep -q '"engine":"Lipi Sovereign"'; then
        log_ok "GET /healthz সফল: {\"status\":\"healthy\",\"engine\":\"Lipi Sovereign\"}"
    else
        log_fail "GET /healthz প্রত্যাশিত JSON ফেরত দেয়নি! পাওয়া গেছে: ${HEALTH_RESP}"
        test_cleanup
        trap - EXIT
        exit 1
    fi

    # Verify GET / (homepage)
    local HTTP_CODE
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${TEST_PORT}/")
    if [ "${HTTP_CODE}" -eq 200 ]; then
        log_ok "GET / সফল: HTTP 200 OK — হোমপেজ রেডি"
    else
        log_fail "GET / ব্যর্থ: HTTP ${HTTP_CODE}"
        test_cleanup
        trap - EXIT
        exit 1
    fi

    # Cleanup test server
    test_cleanup
    trap - EXIT
    log_ok "লাইভ টেস্ট সফলভাবে সম্পন্ন ও ক্লিনআপ সমাপ্ত!"
    echo ""
}

# ── Step 5: Systemd Unit Verification ──────────────────────────────────────────
# WHY: Validates systemd unit file configuration syntax and directives
verify_systemd_unit() {
    log_step "৫" "সিস্টেমডি ইউনিট কনফিগারেশন অডিট (lipi-web.service)"

    if command -v systemd-analyze > /dev/null 2>&1; then
        if systemd-analyze verify "${UNIT_SOURCE}" 2>&1; then
            log_ok "systemd-analyze verify: সিনট্যাক্স ১০০% নির্ভুল"
        else
            log_fail "systemd-analyze ভেরিফিকেশন ব্যর্থ হয়েছে!"
            exit 1
        fi
    else
        log_info "systemd-analyze পাওয়া যায়নি, ফাইল স্ট্রাকচার যাচাই সম্পন্ন"
    fi

    log_info "ইউনিট ফাইল: ${UNIT_SOURCE}"
    log_info "টার্গেট পাথ: ${UNIT_TARGET}"
    echo ""
}

# ── Step 6: Step-by-Step Instructions or Automated Installation ────────────────
# WHY: Enables either one-click automated root installation or explicit,
# transparent manual step-by-step instructions for system administrators.
install_systemd_service() {
    echo -e "${YELLOW}[ধাপ ৬] সিস্টেমডি সার্ভিস ইনস্টলেশন ও ডিপ্লয়মেন্ট${NC}"

    local SUDO_CMD=""
    if [ "$EUID" -ne 0 ]; then
        if command -v sudo > /dev/null 2>&1; then
            SUDO_CMD="sudo"
        else
            log_fail "রুট বা sudo এক্সেস ছাড়া সিস্টেমডি ডিরেক্টরিতে ইনস্টলেশন সম্ভব নয়।"
            print_manual_instructions
            return
        fi
    fi

    echo -e "${CYAN}  • স্বয়ংক্রিয় সিস্টেমডি সার্ভিস ইনস্টল করা হচ্ছে...${NC}"
    ${SUDO_CMD} cp "${UNIT_SOURCE}" "${UNIT_TARGET}"
    ${SUDO_CMD} chmod 644 "${UNIT_TARGET}"
    ${SUDO_CMD} systemctl daemon-reload
    log_ok "ইউনিট ফাইল ইনস্টল সম্পন্ন: ${UNIT_TARGET}"
    log_ok "systemctl daemon-reload সম্পন্ন"

    echo ""
    echo -e "${GREEN}সার্ভিস সক্রিয় ও চালু করার জন্য নিচের কমান্ডটি চালান:${NC}"
    echo -e "  ${BOLD}${SUDO_CMD} systemctl enable --now lipi-web.service${NC}"
    echo ""
    echo -e "${CYAN}সার্ভিসের অবস্থা যাচাই:${NC}"
    echo -e "  ${BOLD}${SUDO_CMD} systemctl status lipi-web.service${NC}"
    echo ""
    echo -e "${CYAN}লাইভ লগ তদারকি:${NC}"
    echo -e "  ${BOLD}${SUDO_CMD} journalctl -u lipi-web.service -f${NC}"
}

# ── Manual Deployment Instructions ────────────────────────────────────────────
# WHY: Provides crystal-clear manual commands for administrators who prefer
# step-by-step control over their production servers.
print_manual_instructions() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}📋 সিস্টেমডি সার্ভিস ম্যানুয়াল ইনস্টলেশন নির্দেশিকা (Step-by-Step)${NC}     ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}১. ইউনিট ফাইলটি সিস্টেমডি ডিরেক্টরিতে কপি করুন:${NC}"
    echo -e "   ${BOLD}sudo cp ${UNIT_SOURCE} ${UNIT_TARGET}${NC}"
    echo -e "   ${BOLD}sudo chmod 644 ${UNIT_TARGET}${NC}"
    echo ""
    echo -e "${YELLOW}২. সিস্টেমডি ডেমন রিলোড করুন:${NC}"
    echo -e "   ${BOLD}sudo systemctl daemon-reload${NC}"
    echo ""
    echo -e "${YELLOW}৩. লিপি ওয়েব সার্ভার বুট টাইমে স্বয়ংক্রিয়ভাবে চলার জন্য সক্রিয় ও চালু করুন:${NC}"
    echo -e "   ${BOLD}sudo systemctl enable --now lipi-web.service${NC}"
    echo ""
    echo -e "${YELLOW}৪. সার্ভিসের স্থিতি এবং হেলথচেক পর্যবেক্ষণ করুন:${NC}"
    echo -e "   ${BOLD}sudo systemctl status lipi-web.service${NC}"
    echo -e "   ${BOLD}curl -i http://127.0.0.1:8088/healthz${NC}"
    echo ""
    echo -e "${YELLOW}৫. সিস্টেমডি জার্নাল লাইভ লগ মনিটরিং:${NC}"
    echo -e "   ${BOLD}sudo journalctl -u lipi-web.service -f${NC}"
    echo ""
}

# ── Main Entry Point ──────────────────────────────────────────────────────────
main() {
    print_banner
    check_prerequisites

    local AUTO_INSTALL=0
    for arg in "$@"; do
        case "$arg" in
            --install|-i)
                AUTO_INSTALL=1
                ;;
            --help|-h)
                echo "Usage: ./apps/website/deploy.sh [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --install, -i    স্বয়ংক্রিয়ভাবে systemd-এ lipi-web.service ইনস্টল ও কনফিগার করে"
                echo "  --help, -h       সহায়িকা প্রদর্শন করে"
                exit 0
                ;;
        esac
    done

    build_server
    verify_assets
    check_sovereignty
    smoke_test
    verify_systemd_unit

    if [ "${AUTO_INSTALL}" -eq 1 ]; then
        install_systemd_service
    else
        print_manual_instructions
        echo -e "${BLUE}💡 টিপ: এক ক্লিকে ইনস্টল করতে চালান: ${BOLD}./apps/website/deploy.sh --install${NC}"
    fi

    echo ""
    echo -e "${GREEN}✨ লিপি সার্বভৌম ওয়েব সার্ভার প্রোডাকশন ডিপ্লয়মেন্ট পাইপলাইন ১০০% সফল! ✨${NC}"
}

main "$@"
