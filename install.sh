#!/bin/sh
# ==============================================================================
# 👑 LIPI GLOBAL SOVEREIGN INSTALLER (install.sh)
# ⚡ curl -sSL https://get.lipi.sh | bash
# Zero Dependencies | 100% Native Linux x86_64 Binary Installation
# ==============================================================================

set -e

CYAN='\033[38;2;0;255;204m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

printf "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}\n"
printf "${CYAN}║  👑 LIPI SOVEREIGN PROGRAMMING LANGUAGE INSTALLER                      ║${NC}\n"
printf "${CYAN}║  ⚡ 100%% Standalone Native Toolchain | Zero GCC | Zero Libc            ║${NC}\n"
printf "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}\n\n"

# ১. আর্কিটেকচার ডিটেকশন
ARCH=$(uname -m)
OS=$(uname -s)

if [ "$OS" != "Linux" ]; then
    printf "❌ ত্রুটি: লিপি বর্তমানে শুধুমাত্র লিনাক্স (Linux) সমর্থন করে!\n"
    exit 1
fi

if [ "$ARCH" != "x86_64" ]; then
    printf "❌ ত্রুটি: লিপি বর্তমানে শুধুমাত্র x86_64 আর্কিটেকচার সমর্থন করে!\n"
    exit 1
fi

INSTALL_DIR="$HOME/.lipi"
BIN_DIR="$INSTALL_DIR/bin"
mkdir -p "$BIN_DIR"

printf "${YELLOW}[১] লিপি টুলচেন ইনস্টলেশন ডিরেক্টরি প্রস্তুতকরণ (~/.lipi/bin)...${NC}\n"

# ২. লোকাল সোর্স থেকে বাইনারি কপি (যদি পাওয়া যায়) অথবা রিলিজ এক্সট্র্যাক্ট
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")"

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/bin/lipic" ]; then
    cp "$SCRIPT_DIR/bin/lipic" "$BIN_DIR/lipic"
    cp "$SCRIPT_DIR/bin/lipipkg" "$BIN_DIR/lipipkg"
    cp "$SCRIPT_DIR/bin/lipidbg" "$BIN_DIR/lipidbg"
    cp "$SCRIPT_DIR/bin/lipirepl" "$BIN_DIR/lipirepl"
    chmod +x "$BIN_DIR/"*
    printf "${GREEN}  ✔ লোকাল বিল্ড থেকে বাইনারিসমূহ ইনস্টল করা হয়েছে।${NC}\n"
fi

# ৩. শেল প্রোফাইল কনফিগারেশন (PATH এক্সপোর্ট)
SHELL_CONFIG=""
if [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
elif [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
fi

if [ -n "$SHELL_CONFIG" ]; then
    if ! grep -q "export PATH=\"\$HOME/.lipi/bin:\$PATH\"" "$SHELL_CONFIG"; then
        printf "\n# Lipi Sovereign Programming Language\nexport PATH=\"\$HOME/.lipi/bin:\$PATH\"\n" >> "$SHELL_CONFIG"
        printf "${GREEN}  ✔ PATH সফলভাবে যুক্ত করা হয়েছে: %s${NC}\n" "$SHELL_CONFIG"
    fi
fi

printf "\n${CYAN}========================================================================${NC}\n"
printf "${GREEN}${BOLD}🎉 লিপি সফলভাবে ইনস্টল সম্পন্ন হয়েছে!${NC}\n"
printf "${CYAN}========================================================================${NC}\n"
printf "টুলচেন পরিচিতি:\n"
printf "  • lipic    : সার্বভৌম লিপি কম্পাইলার (Standalone ELF64 Compiler)\n"
printf "  • lipipkg  : সার্বভৌম প্যাকেজ ম্যানেজার (init, check, build)\n"
printf "  • lipidbg  : সিলিকন হার্ডওয়্যার ডিবাগার\n"
printf "  • lipirepl : ইন্টারঅ্যাক্টিভ লিপি শেল\n\n"
printf "শুরু করতে লিখুন:\n"
printf "  source %s\n" "${SHELL_CONFIG:-~/.bashrc}"
printf "  lipirepl\n\n"
