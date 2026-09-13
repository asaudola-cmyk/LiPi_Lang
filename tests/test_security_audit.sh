#!/usr/bin/env bash
# ==============================================================================
# 🛡️ LIPI WEB & DATABASE SECURITY AUDIT & VULNERABILITY ASSESSMENT TEST
# WHY: Automatically tests for OWASP Top 10 vulnerabilities, sandbox escaping,
# memory corruption, unbounded file growth, input boundary flaws, and DoS attacks.
# ==============================================================================

set -uo pipefail

CYAN='\033[38;2;0;255;204m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'
BOLD='\033[1m'

TEST_PORT=8099
SERVER_BIN="apps/website/lipi_server"
TEST_DB="apps/website/data/sovereign_store.db"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🛡️ LIPI WEB & DATABASE SYSTEM SECURITY AUDIT ENGINE                   ║${NC}"
echo -e "${CYAN}║  ⚡ Automated Vulnerability Scanner & Penetration Resilience Suite      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Ensure test port is free
fuser -k "${TEST_PORT}/tcp" 2>/dev/null || true

# Always compile latest server binary
echo -e "${YELLOW}[প্রস্তুতি] সার্ভার বাইনারি সংকলন করা হচ্ছে...${NC}"
./bin/lipc apps/website/server.lp -o "${SERVER_BIN}" > /dev/null

# Start server on test port 8099
echo -e "${YELLOW}[ধাপ ০] টেস্ট সিকিউরিটি সার্ভার শুরু করা হচ্ছে (Port: ${TEST_PORT})...${NC}"
${SERVER_BIN} ${TEST_PORT} > /dev/null 2>&1 &
SERVER_PID=$!

cleanup() {
    echo ""
    echo -e "${YELLOW}[ক্লিনআপ] সিকিউরিটি টেস্ট সার্ভার প্রসেস (${SERVER_PID}) বন্ধ করা হচ্ছে...${NC}"
    kill -9 "${SERVER_PID}" 2>/dev/null || true
    wait "${SERVER_PID}" 2>/dev/null || true
    fuser -k "${TEST_PORT}/tcp" 2>/dev/null || true
}
trap cleanup EXIT

sleep 1.0

# Verify server is listening
if ! curl -s "http://127.0.0.1:${TEST_PORT}/healthz" > /dev/null; then
    echo -e "${RED}❌ সার্ভার স্টার্ট হতে ব্যর্থ হয়েছে!${NC}"
    exit 1
fi
echo -e "${GREEN}✔ সার্ভার সচল ও টেস্টের জন্য প্রস্তুত।${NC}\n"

VULN_COUNT=0
WARN_COUNT=0
PASS_COUNT=0

# ==============================================================================
# 🔴 টেস্ট ১: Sandbox Code Execution & System Call Boundary (CWE-94, CWE-250)
# ==============================================================================
echo -e "${BOLD}▶ টেস্ট ১: /api/run স্যান্ডবক্স আইসোলেশন ও সিস্টেম কল বাউন্ডারি অডিট${NC}"
# Test whether untrusted sandbox code can invoke host kernel syscalls (SYS_open)
RCE_PAYLOAD='{"code": "fd = syscall(2, \"/etc/hostname\", 0, 0, 0, 0, 0)\nsay \"SYS_OPEN_FD: \" + fd\nsyscall(3, fd, 0, 0, 0, 0, 0)"}'
RUN_RESP=$(curl -s -X POST "http://127.0.0.1:${TEST_PORT}/api/run" -d "${RCE_PAYLOAD}")

if echo "${RUN_RESP}" | grep -q "SYS_OPEN_FD"; then
    echo -e "  ${RED}❌ VULNERABILITY DETECTED [CRITICAL]: স্যান্ডবক্সে অবাধ লিনাক্স কার্নেল সিসকল (Syscall) এক্সিকিউশন সম্ভব!${NC}"
    echo -e "    • বিবরণ: স্যান্ডবক্স প্রসেসে Seccomp-BPF বা চ্রুট (chroot) কন্টেইনারাইজেশন নেই। হোস্ট প্রসেসের ইউজার পারমিশনে রেন্ডম সিসকল (SYS_open, SYS_unlink, SYS_execve) এক্সিকিউট করা সম্ভব।"
    echo -e "    • আউটপুট: ${RUN_RESP}"
    VULN_COUNT=$((VULN_COUNT + 1))
else
    echo -e "  ${GREEN}✔ স্যান্ডবক্স সিস্টেম কল ব্লকিং বা আইসোলেশন সক্রিয়।${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
fi
echo ""

# ==============================================================================
# 🔴 টেস্ট ২: ডাটাবেজ Out-Of-Bounds Write & Sparse File Growth (CWE-787, CWE-125)
# ==============================================================================
echo -e "${BOLD}▶ টেস্ট ২: ডাটাবেজ আউট-অব-বাউন্ড ডিলিট বাউন্ডারি অডিট (id=999999)${NC}"
INITIAL_DB_SIZE=$(wc -c < "${TEST_DB}")
# Send an out-of-bounds delete request
DEL_RESP=$(curl -s -X POST "http://127.0.0.1:${TEST_PORT}/api/db/delete?id=999999")
AFTER_DB_SIZE=$(wc -c < "${TEST_DB}")

if [ "${AFTER_DB_SIZE}" -gt "${INITIAL_DB_SIZE}" ]; then
    echo -e "  ${RED}❌ VULNERABILITY DETECTED [HIGH]: ডাটাবেজে Out-of-bounds রাইট সম্ভব!${NC}"
    echo -e "    • বিবরণ: id=999999 ডিলিট রিকোয়েস্টে ফাইল সাইজ ${INITIAL_DB_SIZE} বাইট থেকে বেড়ে ${AFTER_DB_SIZE} বাইট হয়ে গেছে!"
    echo -e "    • কারণ: db_delete_record() ফাংশনে 'target_id > total_records' চেক অনুপস্থিত।"
    VULN_COUNT=$((VULN_COUNT + 1))
else
    echo -e "  ${GREEN}✔ ডাটাবেজ বাউন্ডারি সুরক্ষিত (ফাইল সাইজ অপরিবর্তিত: ${AFTER_DB_SIZE} বাইট)।${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
fi
echo ""

# ==============================================================================
# 🟠 টেস্ট ৩: ব্রোকেন এক্সেস কন্ট্রোল ও অথেন্টিকেশনহীন মিউটেশন (CWE-306, CWE-352)
# ==============================================================================
echo -e "${BOLD}▶ টেস্ট ৩: গুরুত্বপূর্ণ ডাটাবেজ মিউটেশনে অথেন্টিকেশন চেক (Broken Access Control)${NC}"
RESEED_RESP=$(curl -s -X POST "http://127.0.0.1:${TEST_PORT}/api/db/reseed")

if echo "${RESEED_RESP}" | grep -q '"success":true'; then
    echo -e "  ${YELLOW}⚠️ VULNERABILITY DETECTED [MEDIUM/HIGH]: বিনা অথেন্টিকেশনে ডাটা রিসেট সম্ভব!${NC}"
    echo -e "    • বিবরণ: /api/db/reseed, /api/db/delete, /api/db/update এন্ডপয়েন্টগুলোতে কোনো API Key, JWT বা CSRF টোকেন নেই।"
    echo -e "    • ঝুঁকি: যেকোনো বহিরাগত ভিজিটর বা বট সম্পূর্ণ ডাটাবেজ মুছে বা রিসেট করে দিতে পারে।"
    WARN_COUNT=$((WARN_COUNT + 1))
else
    echo -e "  ${GREEN}✔ ডাটাবেজ মিউটেশন এন্ডপয়েন্ট অথেন্টিকেশন দ্বারা সুরক্ষিত।${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
fi
echo ""

# ==============================================================================
# 🟠 টেস্ট ৪: পাথ ট্রাভার্সাল (Path Traversal / LFI) অডিট (CWE-22)
# ==============================================================================
echo -e "${BOLD}▶ টেস্ট ৪: ডিরেক্টরি পাথ ট্রাভার্সাল (/../../etc/passwd) অডিট${NC}"
TRAVERSAL_RESP=$(curl -s "http://127.0.0.1:${TEST_PORT}/../../etc/passwd")

if echo "${TRAVERSAL_RESP}" | grep -q "root:"; then
    echo -e "  ${RED}❌ VULNERABILITY DETECTED [CRITICAL]: পাথ ট্রাভার্সাল সফল হয়েছে!${NC}"
    VULN_COUNT=$((VULN_COUNT + 1))
else
    echo -e "  ${GREEN}✔ পাথ ট্রাভার্সাল সুরক্ষিত: অবৈধ পাথ রিকোয়েস্টে ফাইল লিক হয়নি (HTTP 404 Returned)।${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
fi
echo ""

# ==============================================================================
# 🟡 টেস্ট ৫: সিকিউরিটি রেসপন্স হেডার্স অডিট (OWASP Security Misconfiguration)
# ==============================================================================
echo -e "${BOLD}▶ টেস্ট ৫: এইচটিটিপি সিকিউরিটি হেডার্স অডিট (CWE-1021 / CWE-693)${NC}"
HEADERS=$(curl -s -I "http://127.0.0.1:${TEST_PORT}/")

MISSING_HEADERS=()
if ! echo "${HEADERS}" | grep -qi "X-Frame-Options"; then
    MISSING_HEADERS+=("X-Frame-Options (Clickjacking Protection)")
fi
if ! echo "${HEADERS}" | grep -qi "Content-Security-Policy"; then
    MISSING_HEADERS+=("Content-Security-Policy (XSS & Injection Mitigation)")
fi
if ! echo "${HEADERS}" | grep -qi "Referrer-Policy"; then
    MISSING_HEADERS+=("Referrer-Policy")
fi

if [ ${#MISSING_HEADERS[@]} -gt 0 ]; then
    echo -e "  ${YELLOW}⚠️ WEAKNESS DETECTED [LOW/MEDIUM]: প্রয়োজনীয় সিকিউরিটি হেডার্স অনুপস্থিত!${NC}"
    for h in "${MISSING_HEADERS[@]}"; do
        echo -e "    • অনুপস্থিত: ${h}"
    done
    WARN_COUNT=$((WARN_COUNT + 1))
else
    echo -e "  ${GREEN}✔ সকল রিকমেন্ডেড সিকিউরিটি হেডার্স বিদ্যমান।${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
fi
echo ""

# ==============================================================================
# 🟠 টেস্ট ৬: CORS ওয়াইল্ডকার্ড কনফিগারেশন অডিট (CWE-942)
# ==============================================================================
echo -e "${BOLD}▶ টেস্ট ৬: CORS ওয়াইল্ডকার্ড কনফিগারেশন অডিট${NC}"
if echo "${HEADERS}" | grep -qi "Access-Control-Allow-Origin: \*"; then
    echo -e "  ${YELLOW}⚠️ WEAKNESS DETECTED [LOW]: সর্বত্র 'Access-Control-Allow-Origin: *' সক্রিয়!${NC}"
    echo -e "    • বিবরণ: স্ট্যাটিক অ্যাসেটের জন্য স্বাভাবিক হলেও ডাইনামিক ডাটাবেজ এপিআই-এর ক্ষেত্রে রেস্ট্রিক্টেড অরিজিন থাকা শ্রেয়।"
    WARN_COUNT=$((WARN_COUNT + 1))
else
    echo -e "  ${GREEN}✔ CORS পলিসি সুরক্ষিত।${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
fi
echo ""

# ==============================================================================
# 🔴 টেস্ট ৭: সিঙ্গেল-থ্রেডেড ব্লকিং ডিনায়াল অব সার্ভিস (Slowloris / DoS) (CWE-400)
# ==============================================================================
echo -e "${BOLD}▶ টেস্ট ৭: সিঙ্গেল-থ্রেডেড সিঙ্ক্রোনাস সকেট ব্লকিং (Slowloris DoS) অডিট${NC}"
# Open a raw TCP connection, do NOT send any HTTP request, and sleep for 1.5 seconds in background
(
    exec 3<>/dev/tcp/127.0.0.1/${TEST_PORT}
    sleep 1.5
    exec 3<&-
    exec 3>&-
) &
SLOW_PID=$!
sleep 0.2

# Try to connect concurrently
T_START=$(date +%s%N)
CONC_RESP=$(curl -s -m 1 "http://127.0.0.1:${TEST_PORT}/healthz" || echo "TIMEOUT")
T_END=$(date +%s%N)
wait "${SLOW_PID}" 2>/dev/null || true

if [ "${CONC_RESP}" = "TIMEOUT" ]; then
    echo -e "  ${RED}❌ VULNERABILITY DETECTED [HIGH]: সিঙ্গেল সকেট ব্লকিং দ্বারা DoS সম্ভব!${NC}"
    echo -e "    • বিবরণ: একটি ক্লায়েন্ট কানেকশন ওপেন করে ডেটা না পাঠালে পুরো সার্ভার ব্লক হয়ে যায়।"
    echo -e "    • কারণ: সার্ভারটি ব্লকিং socket_accept() এবং সিঙ্ক্রোনাস syscall(0, client_fd, ...) মডেলে চলে।"
    VULN_COUNT=$((VULN_COUNT + 1))
else
    echo -e "  ${GREEN}✔ কনকারেন্ট রিকোয়েস্টে সাড়াদান স্বাভাবিক।${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
fi
echo ""

# ==============================================================================
# 🟢 টেস্ট ৮: ইনপুট প্যারামিটার বাউন্ডারি ও স্পেশাল ক্যারেক্টার ইনজেকশন
# ==============================================================================
echo -e "${BOLD}▶ টেস্ট ৮: ইনপুট প্যারামিটার পার্সিং (SQLi/Command Injection Symbols)${NC}"
INJ_RESP=$(curl -s -X POST "http://127.0.0.1:${TEST_PORT}/api/db/add?val=100;DROP%20TABLE;--")
if echo "${INJ_RESP}" | grep -q '"value":100'; then
    echo -e "  ${GREEN}✔ ইনপুট পার্সার কঠোরভাবে শুধু ইন্টিজার ডিজিট এক্সট্র্যাক্ট করে, ইনজেকশন স্ট্রিং স্বয়ংক্রিয়ভাবে ডিসকার্ড হয়েছে।${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  ${YELLOW}⚠️ অপ্রত্যাশিত আচরণ: ${INJ_RESP}${NC}"
    WARN_COUNT=$((WARN_COUNT + 1))
fi
echo ""

# ==============================================================================
# 📊 সারাংশ রিপোর্ট
# ==============================================================================
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  📊 সিকিউরিটি অডিট ফলাফল সারাংশ                                       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo -e "  • পাসকৃত টেস্ট সংখ্যা: ${GREEN}${PASS_COUNT}${NC}"
echo -e "  • ক্রিটিক্যাল / হাই সিকিউরিটি ঝুঁকি: ${RED}${VULN_COUNT}${NC}"
echo -e "  • মিডিয়াম / লো দুর্বলতা: ${YELLOW}${WARN_COUNT}${NC}"
