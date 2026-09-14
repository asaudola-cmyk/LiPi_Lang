#!/bin/bash
# =============================================================================
# Lipi Programming Language — Install Script
# GitHub: https://github.com/asaudola-cmyk/LiPi_Lang
# Usage:  curl -sSL https://raw.githubusercontent.com/asaudola-cmyk/LiPi_Lang/main/install.sh | bash
# =============================================================================

set -e

LIPI_VERSION="First 1.0.0 (প্রথম ১.০.০)"
LIPI_REPO="https://github.com/asaudola-cmyk/LiPi_Lang.git"
LIPI_INSTALL_DIR="$HOME/.lipi"
LIPI_BIN_DIR="$HOME/.local/bin"
LIPI_COLOR_GREEN="\033[32m"
LIPI_COLOR_CYAN="\033[36m"
LIPI_COLOR_YELLOW="\033[33m"
LIPI_COLOR_RED="\033[31m"
LIPI_COLOR_BOLD="\033[1m"
LIPI_COLOR_RESET="\033[0m"

header() {
    echo ""
    echo -e "${LIPI_COLOR_BOLD}${LIPI_COLOR_CYAN}"
    echo "  ██╗     ██╗██████╗ ██╗"
    echo "  ██║     ██║██╔══██╗██║"
    echo "  ██║     ██║██████╔╝██║"
    echo "  ██║     ██║██╔═══╝ ██║"
    echo "  ███████╗██║██║     ██║"
    echo "  ╚══════╝╚═╝╚═╝     ╚═╝"
    echo -e "${LIPI_COLOR_RESET}"
    echo -e "  ${LIPI_COLOR_BOLD}Lipi Programming Language${LIPI_COLOR_RESET} — ${LIPI_COLOR_YELLOW}${LIPI_VERSION}${LIPI_COLOR_RESET}"
    echo "  The world's first globally-ready language with Unicode identifiers"
    echo ""
}

ok()   { echo -e "  ${LIPI_COLOR_GREEN}✔${LIPI_COLOR_RESET} $1"; }
fail() { echo -e "  ${LIPI_COLOR_RED}✘ Error: $1${LIPI_COLOR_RESET}"; exit 1; }
info() { echo -e "  ${LIPI_COLOR_CYAN}→${LIPI_COLOR_RESET} $1"; }
warn() { echo -e "  ${LIPI_COLOR_YELLOW}⚠${LIPI_COLOR_RESET} $1"; }

# ─── Check Toolchain ─────────────────────────────────────────────────────────
# WHY: Lipi is 100% Sovereign (Zero Python, Zero Libc, Zero GCC).
# Pre-compiled standalone binaries run directly on bare Linux kernel.
# C compiler (gcc/clang) is only an optional secondary backend.
check_toolchain() {
    info "Checking toolchain (100% Sovereign Native Engine)..."
    CC_CMD=""
    
    # Check optional native C compiler for secondary C codegen backend
    for c_cmd in gcc clang cc; do
        if command -v "$c_cmd" &>/dev/null; then
            CC_CMD="$c_cmd"
            ok "Secondary native C compiler found: $c_cmd"
            break
        fi
    done

    if [ -z "$CC_CMD" ]; then
        info "Standalone direct ELF machine code engine will be used (0% GCC, 0% Libc) 👑"
    fi
}

# ─── Check Git ───────────────────────────────────────────────────────────────
check_git() {
    info "Checking git..."
    if ! command -v git &>/dev/null; then
        fail "git is required but not found.
  
  Install git:
    Ubuntu/Debian:  sudo apt install git
    macOS:          brew install git"
    fi
    ok "git found"
}

# ─── Install ─────────────────────────────────────────────────────────────────
install_lipi() {
    info "Installing to $LIPI_INSTALL_DIR ..."
    
    # Remove old install
    if [ -d "$LIPI_INSTALL_DIR" ]; then
        warn "Existing install found. Updating..."
        git -C "$LIPI_INSTALL_DIR" pull --quiet 2>/dev/null || {
            rm -rf "$LIPI_INSTALL_DIR"
            git clone --quiet --depth=1 "$LIPI_REPO" "$LIPI_INSTALL_DIR"
        }
    else
        git clone --quiet --depth=1 "$LIPI_REPO" "$LIPI_INSTALL_DIR"
    fi
    ok "Lipi repository ready"
}

# ─── Create lipi and lipc commands ──────────────────────────────────────────
create_command() {
    info "Setting up native standalone toolchain in $LIPI_BIN_DIR..."
    mkdir -p "$LIPI_BIN_DIR"
    
    # Ensure canonical compiler binary exists from bootstrap seed
    if [ ! -x "$LIPI_INSTALL_DIR/bin/lipc_bin" ]; then
        if [ -f "$LIPI_INSTALL_DIR/boot/lipi-seed" ]; then
            cp "$LIPI_INSTALL_DIR/boot/lipi-seed" "$LIPI_INSTALL_DIR/bin/lipc_bin"
            chmod +x "$LIPI_INSTALL_DIR/bin/lipc_bin"
        elif [ -f "$LIPI_INSTALL_DIR/boot/seed.b64" ]; then
            base64 -d "$LIPI_INSTALL_DIR/boot/seed.b64" | gzip -d > "$LIPI_INSTALL_DIR/bin/lipc_bin"
            chmod +x "$LIPI_INSTALL_DIR/bin/lipc_bin"
        fi
    fi
    
    # 1. Native CLI driver and runner
    ln -sf "$LIPI_INSTALL_DIR/bin/lipi" "$LIPI_BIN_DIR/lipi"
    ok "Linked: $LIPI_BIN_DIR/lipi (Sovereign CLI Driver & Runner)"

    # 2. Native direct ELF machine code compiler
    ln -sf "$LIPI_INSTALL_DIR/bin/lipc" "$LIPI_BIN_DIR/lipc"
    ln -sf "$LIPI_INSTALL_DIR/bin/lipc_bin" "$LIPI_BIN_DIR/lipc_bin"
    ok "Linked: $LIPI_BIN_DIR/lipc & lipc_bin (Direct Silicon Machine Code Compiler)"

    # 3. Sovereign package manager
    ln -sf "$LIPI_INSTALL_DIR/bin/lipipkg" "$LIPI_BIN_DIR/lipipkg"
    ok "Linked: $LIPI_BIN_DIR/lipipkg (Ed25519 Cryptographic Package Manager)"

    # 4. Language Server Protocol daemon
    ln -sf "$LIPI_INSTALL_DIR/bin/lipilsp" "$LIPI_BIN_DIR/lipilsp"
    ln -sf "$LIPI_INSTALL_DIR/bin/lipilsp" "$LIPI_BIN_DIR/lipils"
    ok "Linked: $LIPI_BIN_DIR/lipilsp & lipils (LSP IDE Engine)"

    # 5. Canonical code formatter
    ln -sf "$LIPI_INSTALL_DIR/bin/lipifmt" "$LIPI_BIN_DIR/lipifmt"
    ok "Linked: $LIPI_BIN_DIR/lipifmt (Canonical Code Formatter)"

    # 6. System debugger
    ln -sf "$LIPI_INSTALL_DIR/bin/lipidbg" "$LIPI_BIN_DIR/lipidbg"
    ok "Linked: $LIPI_BIN_DIR/lipidbg (Native System Debugger)"

    # 7. Legacy code converter
    ln -sf "$LIPI_INSTALL_DIR/bin/lipiconvert" "$LIPI_BIN_DIR/lipiconvert"
    ok "Linked: $LIPI_BIN_DIR/lipiconvert (Universal Legacy Transpiler)"

    # 8. Markdown documentation generator
    ln -sf "$LIPI_INSTALL_DIR/bin/lipidoc" "$LIPI_BIN_DIR/lipidoc"
    ok "Linked: $LIPI_BIN_DIR/lipidoc (Markdown Documentation Engine)"

    # 9. Standalone engines
    ln -sf "$LIPI_INSTALL_DIR/bin/lipi-test" "$LIPI_BIN_DIR/lipi-test"
    ln -sf "$LIPI_INSTALL_DIR/bin/lipi-build" "$LIPI_BIN_DIR/lipi-build"
    ln -sf "$LIPI_INSTALL_DIR/bin/lipirepl" "$LIPI_BIN_DIR/lipirepl"
    ok "Linked: $LIPI_BIN_DIR/lipi-test, lipi-build, lipirepl (Native Engines)"
}

# ─── Add to PATH ─────────────────────────────────────────────────────────────
setup_path() {
    local added=0
    
    # Detect shell config file
    local shell_configs=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.bash_profile")
    
    for cfg in "${shell_configs[@]}"; do
        if [ -f "$cfg" ]; then
            if ! grep -q 'LIPI_PATH_ADDED' "$cfg" 2>/dev/null; then
                echo "" >> "$cfg"
                echo "# Lipi Programming Language — LIPI_PATH_ADDED" >> "$cfg"
                echo "export PATH=\"\$PATH:$LIPI_BIN_DIR\"" >> "$cfg"
                added=1
            fi
        fi
    done
    
    # Also export for current session
    export PATH="$PATH:$LIPI_BIN_DIR"
    
    if [ "$added" -eq 1 ]; then
        ok "Added $LIPI_BIN_DIR to PATH in shell config"
    else
        ok "$LIPI_BIN_DIR already in PATH config"
    fi
}

# ─── Verify ──────────────────────────────────────────────────────────────────
# WHY: Verify native execution directly without any external runtime.
verify_install() {
    info "Verifying sovereign installation..."
    
    if "$LIPI_BIN_DIR/lipi" version &>/dev/null; then
        ok "Lipi sovereign toolchain works!"
    elif "$LIPI_BIN_DIR/lipi" clean &>/dev/null; then
        ok "Lipi native runner works!"
    else
        warn "Verification check had non-zero status — binaries are installed in $LIPI_BIN_DIR"
    fi
}

# ─── Print success ───────────────────────────────────────────────────────────
print_success() {
    echo ""
    echo -e "  ${LIPI_COLOR_BOLD}${LIPI_COLOR_GREEN}✔ Lipi installed successfully!${LIPI_COLOR_RESET}"
    echo ""
    echo "  Get started with modern Lipi CLI:"
    echo ""
    echo -e "    ${LIPI_COLOR_CYAN}lipi run <file.lp>${LIPI_COLOR_RESET}     → Run program in-memory (0% disk overhead)"
    echo -e "    ${LIPI_COLOR_CYAN}lipi build <file.lp>${LIPI_COLOR_RESET}   → Compile standalone native executable"
    echo -e "    ${LIPI_COLOR_CYAN}lipi repl${LIPI_COLOR_RESET}              → Start interactive REPL"
    echo -e "    ${LIPI_COLOR_CYAN}lipi test${LIPI_COLOR_RESET}              → Run autonomous test suites"
    echo -e "    ${LIPI_COLOR_CYAN}lipi clean${LIPI_COLOR_RESET}             → Clean scratch artifacts (0% shell)"
    echo -e "    ${LIPI_COLOR_CYAN}lipi version${LIPI_COLOR_RESET}           → Show version & platform architecture"
    echo ""
    echo "  Quick test:"
    echo -e "    ${LIPI_COLOR_YELLOW}lipi run examples/01_hello.lp${LIPI_COLOR_RESET}"
    echo ""
    echo "  Documentation:"
    echo "    https://github.com/asaudola-cmyk/LiPi_Lang"
    echo ""
    echo "  ⚠  Restart your terminal (or run: source ~/.bashrc)"
    echo ""
}

# ─── Setup Desktop MIME & Icons ──────────────────────────────────────────────
# WHY: Automatically register *.lp, *.lipi MIME types and install file manager
# icons so Linux desktop file managers (Thunar, Nautilus, Dolphin) render Lipi icons.
setup_desktop_mime() {
    info "Setting up Linux desktop MIME types and file manager icons..."
    local mime_dir="$HOME/.local/share/mime/packages"
    local icons_dir="$HOME/.local/share/icons/hicolor/scalable/mimetypes"
    mkdir -p "$mime_dir" "$icons_dir"
    if [ -f "$LIPI_INSTALL_DIR/assets/branding/lipi-mime.xml" ]; then
        cp -f "$LIPI_INSTALL_DIR/assets/branding/lipi-mime.xml" "$mime_dir/lipi.xml"
        if command -v update-mime-database &>/dev/null; then
            update-mime-database "$HOME/.local/share/mime" &>/dev/null || true
        fi
    fi
    if [ -f "$LIPI_INSTALL_DIR/assets/branding/lipi_logo_bold.svg" ]; then
        cp -f "$LIPI_INSTALL_DIR/assets/branding/lipi_logo_bold.svg" "$icons_dir/text-x-lipi.svg"
        if command -v gtk-update-icon-cache &>/dev/null; then
            gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" &>/dev/null || true
        fi
    fi
    ok "Desktop MIME and vector icon integration registered"
}

# ─── Uninstall ───────────────────────────────────────────────────────────────
uninstall() {
    echo "Uninstalling Lipi..."
    rm -f "$LIPI_BIN_DIR/lipi"
    rm -f "$LIPI_BIN_DIR/lipc"
    rm -f "$LIPI_BIN_DIR/lipipkg"
    rm -f "$LIPI_BIN_DIR/lipils"
    rm -f "$LIPI_BIN_DIR/lipilsp"
    rm -f "$LIPI_BIN_DIR/lipifmt"
    rm -f "$LIPI_BIN_DIR/lipidbg"
    rm -f "$LIPI_BIN_DIR/lipidb_server"
    rm -rf "$LIPI_INSTALL_DIR"
    echo "Lipi uninstalled."
    exit 0
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
    header
    
    if [ "${1:-}" = "--uninstall" ]; then
        uninstall
    fi
    
    check_toolchain
    check_git
    install_lipi
    create_command
    setup_path
    setup_desktop_mime
    verify_install
    print_success
}

main "$@"
