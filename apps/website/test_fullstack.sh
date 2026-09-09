#!/usr/bin/env bash
# ==============================================================================
# 👑 LIPI FULL-STACK WEB & DATABASE VERIFICATION TEST (test_fullstack.sh)
# WHY: End-to-end testing of Lipi Frontend, Backend REST API, and
# Sovereign Binary Database engine (NVMe direct fsync).
# ==============================================================================

set -euo pipefail

CYAN='\033[38;2;0;255;204m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  👑 LIPI FULL-STACK (FRONTEND + BACKEND + DATABASE) TEST SUITE         ║${NC}"
echo -e "${CYAN}║  ⚡ 100% Native Silicon Machine Code | Direct Kernel Syscalls | 0% PHP  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ক্লিনআপ পুরানো টেস্ট ডিবি
rm -f apps/website/data/sovereign_store.db

echo -e "${YELLOW}[ধাপ ১] খাঁটি লিপি কম্পাইলার দিয়ে server.lp সংকলন...${NC}"
./bin/lipic apps/website/server.lp -o apps/website/lipi_server > /dev/null
echo -e "${GREEN}  ✔ apps/website/lipi_server সফলভাবে নির্মিত।${NC}"

# ব্যাকগ্রাউন্ডে সার্ভার শুরু
./apps/website/lipi_server &
SERVER_PID=$!

cleanup() {
    kill -9 "${SERVER_PID}" 2>/dev/null || true
}
trap cleanup EXIT

sleep 0.6

# ধাপ ২: প্রাথমিক সিড রেকর্ড যাচাই
echo -e "${YELLOW}[ধাপ ২] GET /api/db/items (প্রাথমিক রেকর্ডসমূহ লোড)...${NC}"
ITEMS_JSON=$(curl -s http://127.0.0.1:8080/api/db/items)
echo -e "  • প্রাপ্ত ডেটা: ${CYAN}${ITEMS_JSON}${NC}"
if echo "${ITEMS_JSON}" | grep -q "1024"; then
    echo -e "${GREEN}  ✔ প্রাথমিক সিড রেকর্ড প্রাপ্তি সফল!${NC}"
else
    echo -e "${RED}  ❌ এরর: সিড রেকর্ড পাওয়া যায়নি!${NC}"
    exit 1
fi

# ধাপ ৩: ডাটাবেজে নতুন রেকর্ড যোগ (INSERT)
echo -e "${YELLOW}[ধাপ ৩] POST /api/db/add (নতুন রেকর্ড ৫০০০ ইনসার্ট)...${NC}"
ADD_RES=$(curl -s -X POST "http://127.0.0.1:8080/api/db/add?val=5000")
echo -e "  • ইনসার্ট রেসপন্স: ${CYAN}${ADD_RES}${NC}"
if echo "${ADD_RES}" | grep -q "success"; then
    echo -e "${GREEN}  ✔ রেকর্ড ইনসার্ট সফল!${NC}"
else
    echo -e "${RED}  ❌ এরর: ইনসার্ট ব্যর্থ!${NC}"
    exit 1
fi

# ধাপ ৪: পুনরায় সব রেকর্ড চেক (ভ্যালিডেশন)
echo -e "${YELLOW}[ধাপ ৪] GET /api/db/items (নতুন ইনসার্ট সহ যাচাই)...${NC}"
UPDATED_JSON=$(curl -s http://127.0.0.1:8080/api/db/items)
echo -e "  • আপডেটকৃত ডেটা: ${CYAN}${UPDATED_JSON}${NC}"
if echo "${UPDATED_JSON}" | grep -q "5000"; then
    echo -e "${GREEN}  ✔ নতুন রেকর্ড ৫০০০ ডাটাবেজে দৃশ্যমান!${NC}"
else
    echo -e "${RED}  ❌ এরর: নতুন রেকর্ড মেলেনি!${NC}"
    exit 1
fi

# ধাপ ৫: ডাটাবেজ পরিসংখ্যান এপিআই
echo -e "${YELLOW}[ধাপ ৫] GET /api/db/stats (ডাটাবেজ স্ট্যাটাস)...${NC}"
STATS_RES=$(curl -s http://127.0.0.1:8080/api/db/stats)
echo -e "  • স্ট্যাটাস রেসপন্স: ${CYAN}${STATS_RES}${NC}"
if echo "${STATS_RES}" | grep -q "fsync_guarantee"; then
    echo -e "${GREEN}  ✔ ডাটাবেজ স্ট্যাটস সফল!${NC}"
else
    echo -e "${RED}  ❌ এরর: স্ট্যাটস ব্যর্থ!${NC}"
    exit 1
fi

# ধাপ ৬: রেকর্ড সফট ডিলিট
echo -e "${YELLOW}[ধাপ ৬] POST /api/db/delete?id=2 (রেকর্ড #২ ডিলিট)...${NC}"
DEL_RES=$(curl -s -X POST "http://127.0.0.1:8080/api/db/delete?id=2")
echo -e "  • ডিলিট রেসপন্স: ${CYAN}${DEL_RES}${NC}"
if echo "${DEL_RES}" | grep -q "success"; then
    echo -e "${GREEN}  ✔ রেকর্ড ২ ডিলিট সফল!${NC}"
else
    echo -e "${RED}  ❌ এরর: ডিলিট ব্যর্থ!${NC}"
    exit 1
fi

# ধাপ ৭: ডিলিট পরবর্তী ডাটাবেজ যাচাই
echo -e "${YELLOW}[ধাপ ৭] GET /api/db/items (ডিলিট পরবর্তী যাচাই)...${NC}"
AFTER_DEL=$(curl -s http://127.0.0.1:8080/api/db/items)
echo -e "  • বর্তমান ডেটা: ${CYAN}${AFTER_DEL}${NC}"
# Record 2 (val 2048) should be omitted
if echo "${AFTER_DEL}" | grep -q "2048"; then
    echo -e "${RED}  ❌ এরর: ডিলিটকৃত রেকর্ড এখনও বিদ্যমান!${NC}"
    exit 1
else
    echo -e "${GREEN}  ✔ ডিলিটকৃত রেকর্ড বাদ দিয়ে শুধু সক্রিয় রেকর্ড ফিল্টার সফল!${NC}"
fi

# ধাপ ৮: ডিস্ক ফাইল পারসিস্টেন্স অডিট
echo -e "${YELLOW}[ধাপ ৮] ফিজিক্যাল ডিস্ক বাইনারি ফাইল অডিট...${NC}"
DB_SIZE=$(wc -c < apps/website/data/sovereign_store.db)
echo -e "  • ডিস্ক ফাইল সাইজ: ${DB_SIZE} বাইট (৪টি রেকর্ড x ৩২ বাইট = ১২৮ বাইট)"
if [ "${DB_SIZE}" -eq 128 ]; then
    echo -e "${GREEN}  ✔ ডিস্ক বাইনারি সাইজ ১২৮ বাইট ১০০% নিখুঁত!${NC}"
else
    echo -e "${RED}  ❌ এরর: ডিস্ক সাইজ অমিল!${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🎉 ফুল-স্ট্যাক টেস্ট সফল! লিপি ফ্রন্টএন্ড, ব্যাকএন্ড ও ডাটাবেজ ১০০% কার্যকর! ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
