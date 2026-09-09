#!/usr/bin/env bash
# ==============================================================================
# 👑 LIPI DYNAMIC WEB SERVER VERIFICATION TEST SUITE (test_web.sh)
# WHY: Verifies that apps/website/server.lp compiles and serves the modern
# official Lipi homepage and dynamic JSON API endpoints over Linux TCP socket.
# ==============================================================================

set -euo pipefail

CYAN='\033[38;2;0;255;204m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  👑 LIPI SOVEREIGN DYNAMIC WEB SERVER END-TO-END TEST SUITE            ║${NC}"
echo -e "${CYAN}║  ⚡ 100% Native Silicon CPU Machine Code | Zero Libc | Zero PHP         ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ১. কম্পাইলেশন পরীক্ষা
echo -e "${YELLOW}[ধাপ ১] খাঁটি লিপি কম্পাইলার দিয়ে server.lp সংকলন...${NC}"
./bin/lipic apps/website/server.lp -o apps/website/lipi_server > /dev/null
echo -e "${GREEN}  ✔ apps/website/lipi_server সফলভাবে তৈরি হয়েছে।${NC}"

# ২. ডিপেন্ডেন্সি ও স্বাধীনতা অডিট
echo -e "${YELLOW}[ধাপ ২] বাইনারি স্বাধীনতা অডিট...${NC}"
if (ldd apps/website/lipi_server 2>&1 || true) | grep -q "not a dynamic executable"; then
    echo -e "${GREEN}  ✔ স্ট্যাটিক লিনাক্স ELF ৬৪-বিট (not a dynamic executable: ০% Libc, ০% GCC)${NC}"
else
    echo -e "${RED}  ❌ এরর: বাইনারি স্ট্যাটিক নয়!${NC}"
    exit 1
fi

# ৩. ব্যাকগ্রাউন্ডে সার্ভার শুরু
echo -e "${YELLOW}[ধাপ ৩] লিপি নেটিভ ওয়েব সার্ভার ব্যাকগ্রাউন্ডে চালু করা হচ্ছে...${NC}"
./apps/website/lipi_server &
SERVER_PID=$!

# ট্র্যাপ দিয়ে সার্ভার বন্ধ করার ব্যবস্থা
cleanup() {
    echo ""
    echo -e "${YELLOW}[সমাপ্তি] টেস্ট সার্ভার প্রসেস (${SERVER_PID}) বন্ধ করা হচ্ছে...${NC}"
    kill -9 "${SERVER_PID}" 2>/dev/null || true
}
trap cleanup EXIT

# সার্ভার সকেটের জন্য অপেক্ষা
sleep 0.5

# ৪. HTTP রিকোয়েস্ট যাচাই (GET /)
echo -e "${YELLOW}[ধাপ ৪] HTTP রিকোয়েস্ট ১: GET / (অফিশিয়াল হোমপেজ)...${NC}"
HTTP_CODE=$(curl -s -o /tmp/lipi_home.html -w "%{http_code}" http://127.0.0.1:8080/)
if [ "${HTTP_CODE}" -eq 200 ] && grep -q "LIPI" /tmp/lipi_home.html; then
    echo -e "${GREEN}  ✔ GET / সফল! HTTP 200 OK — হোমপেজ নিখুঁতভাবে রিসিভ হয়েছে।${NC}"
    echo -e "    • ফাইলের সাইজ: $(wc -c < /tmp/lipi_home.html) বাইট"
else
    echo -e "${RED}  ❌ এরর: GET / ব্যর্থ (Code: ${HTTP_CODE})!${NC}"
    exit 1
fi

# ৫. HTTP রিকোয়েস্ট যাচাই (GET /style.css)
echo -e "${YELLOW}[ধাপ ৫] HTTP রিকোয়েস্ট ২: GET /style.css (ডিজাইন সিস্টেম)...${NC}"
HTTP_CODE_CSS=$(curl -s -o /tmp/lipi_style.css -w "%{http_code}" http://127.0.0.1:8080/style.css)
if [ "${HTTP_CODE_CSS}" -eq 200 ] && grep -q "neon-cyan" /tmp/lipi_style.css; then
    echo -e "${GREEN}  ✔ GET /style.css সফল! HTTP 200 OK — সিএসএস ডেটা প্রাপ্ত।${NC}"
else
    echo -e "${RED}  ❌ এরর: GET /style.css ব্যর্থ (Code: ${HTTP_CODE_CSS})!${NC}"
    exit 1
fi

# ৬. HTTP রিকোয়েস্ট যাচাই (GET /app.js)
echo -e "${YELLOW}[ধাপ ৬] HTTP রিকোয়েস্ট ৩: GET /app.js (ইন্টারঅ্যাক্টিভ ইঞ্জিন)...${NC}"
HTTP_CODE_JS=$(curl -s -o /tmp/lipi_app.js -w "%{http_code}" http://127.0.0.1:8080/app.js)
if [ "${HTTP_CODE_JS}" -eq 200 ] && grep -q "initTelemetryPolling" /tmp/lipi_app.js; then
    echo -e "${GREEN}  ✔ GET /app.js সফল! HTTP 200 OK — জাভাস্ক্রিপ্ট ক্লায়েন্ট ইঞ্জিন প্রস্তুত।${NC}"
else
    echo -e "${RED}  ❌ এরর: GET /app.js ব্যর্থ (Code: ${HTTP_CODE_JS})!${NC}"
    exit 1
fi

# ৭. HTTP রিকোয়েস্ট যাচাই (GET /favicon.svg)
echo -e "${YELLOW}[ধাপ ৭] HTTP রিকোয়েস্ট ৪: GET /favicon.svg (লিপি ক্রাউন লোগো)...${NC}"
HTTP_CODE_SVG=$(curl -s -o /tmp/lipi_fav.svg -w "%{http_code}" http://127.0.0.1:8080/favicon.svg)
if [ "${HTTP_CODE_SVG}" -eq 200 ] && grep -q "svg" /tmp/lipi_fav.svg; then
    echo -e "${GREEN}  ✔ GET /favicon.svg সফল! HTTP 200 OK — এসভিজি লোগো প্রাপ্ত।${NC}"
else
    echo -e "${RED}  ❌ এরর: GET /favicon.svg ব্যর্থ (Code: ${HTTP_CODE_SVG})!${NC}"
    exit 1
fi

# ৮. HTTP রিকোয়েস্ট যাচাই (GET /api/status - Dynamic Telemetry)
echo -e "${YELLOW}[ধাপ ৮] HTTP রিকোয়েস্ট ৫: GET /api/status (ডাইনামিক সিলিকন মেট্রিক্স JSON)...${NC}"
STATUS_JSON=$(curl -s http://127.0.0.1:8080/api/status)
echo -e "  • প্রাপ্ত ডাইনামিক JSON: ${CYAN}${STATUS_JSON}${NC}"
if echo "${STATUS_JSON}" | grep -q "sovereign_online"; then
    echo -e "${GREEN}  ✔ ডাইনামিক এপিআই সফল! লাইভ সিপিইউ সাইকেল ও সার্ভার কাউন্টার সক্রিয়।${NC}"
else
    echo -e "${RED}  ❌ এরর: ডাইনামিক এপিআই ব্যর্থ!${NC}"
    exit 1
fi

# ৯. সক্রিয় কোডবেস পিএইচপি অডিট
echo -e "${YELLOW}[ধাপ ৯] কোডবেস ০% PHP সার্বভৌমত্ব অডিট...${NC}"
PHP_COUNT=$(find apps/website -name "*.php" | wc -l)
if [ "${PHP_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}  ✔ apps/website এ কোনো PHP ফাইল নেই (০% PHP, ১০০% লিপি)!${NC}"
else
    echo -e "${RED}  ❌ সতর্কতা: apps/website এ PHP ফাইল রয়েছে!${NC}"
    exit 1
fi

rm -f /tmp/lipi_home.html /tmp/lipi_style.css /tmp/lipi_app.js /tmp/lipi_fav.svg

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🎉 সকল পরীক্ষা সফল! লিপি অফিশিয়াল হোমপেজ ও ডাইনামিক সার্ভার ১০০% প্রস্তুত! ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
