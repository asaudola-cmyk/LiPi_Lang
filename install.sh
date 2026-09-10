#!/bin/bash
# =============================================================================
# Lipi Programming Language — Install Script
# GitHub: https://github.com/asaudola-cmyk/LiPi_Lang
# Usage:  curl -sSL https://raw.githubusercontent.com/asaudola-cmyk/LiPi_Lang/main/install.sh | bash
# =============================================================================

set -e

LIPI_VERSION="First 1.0 (Sovereign)"
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
check_toolchain() {
    info "Checking toolchain (C compiler or Python)..."
    
    # Check C compiler for 100% native build
    for c_cmd in gcc clang cc; do
        if command -v "$c_cmd" &>/dev/null; then
            CC_CMD="$c_cmd"
            ok "Native C compiler found: $c_cmd"
            break
        fi
    done

    # Check Python optional fallback
    for cmd in python3 python; do
        if command -v "$cmd" &>/dev/null; then
            version=$("$cmd" --version 2>&1 | grep -oP '\d+\.\d+' | head -1)
            major=$(echo "$version" | cut -d. -f1)
            minor=$(echo "$version" | cut -d. -f2)
            
            if [ "$major" -ge 3 ] && [ "$minor" -ge 8 ]; then
                PYTHON_CMD="$cmd"
                ok "Python $version found ($cmd)"
                break
            fi
        fi
    done
    
    if [ -z "$CC_CMD" ] && [ -z "$PYTHON_CMD" ]; then
        fail "Neither a C compiler (gcc/clang) nor Python 3.8+ was found.
  
  Please install gcc or clang:
    Ubuntu/Debian:  sudo apt install build-essential
    Fedora/RHEL:    sudo dnf groupinstall \"Development Tools\"
    macOS:          xcode-select --install"
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
    info "Creating 'lipi' and 'lipc' commands..."
    mkdir -p "$LIPI_BIN_DIR"
    
    # 1. Native runner and REPL command
    cp "$LIPI_INSTALL_DIR/bin/lipi" "$LIPI_BIN_DIR/lipi"
    chmod +x "$LIPI_BIN_DIR/lipi"
    ok "Created: $LIPI_BIN_DIR/lipi (Native Runner & REPL)"

    # 2. Build native compiler and native REPL if C compiler available
    local cc_cmd=""
    for c_compiler in gcc clang cc; do
        if command -v "$c_compiler" &>/dev/null; then
            cc_cmd="$c_compiler"
            break
        fi
    done

    if [ -n "$cc_cmd" ]; then
        # Build native compiler
        if [ -f "$LIPI_INSTALL_DIR/src/compiler/c_codegen.c" ]; then
            info "Building native compiler with $cc_cmd..."
            if $cc_cmd -O2 "$LIPI_INSTALL_DIR/src/compiler/c_codegen.c" \
                -I "$LIPI_INSTALL_DIR/src/compiler" \
                -lm -o "$LIPI_INSTALL_DIR/bin/lipc_bin" 2>/dev/null; then
                chmod +x "$LIPI_INSTALL_DIR/bin/lipc_bin"
                ok "Built native compiler: $LIPI_INSTALL_DIR/bin/lipc_bin"
            else
                warn "Native binary compilation skipped"
            fi
        fi

        # Build native REPL
        if [ -f "$LIPI_INSTALL_DIR/src/runtime/native_repl.c" ]; then
            info "Building native REPL with $cc_cmd..."
            if $cc_cmd -O2 "$LIPI_INSTALL_DIR/src/runtime/native_repl.c" \
                -o "$LIPI_INSTALL_DIR/bin/lipirepl_bin" 2>/dev/null; then
                chmod +x "$LIPI_INSTALL_DIR/bin/lipirepl_bin"
                ok "Built native REPL: $LIPI_INSTALL_DIR/bin/lipirepl_bin"
            fi
        fi

        # Build native direct ELF compiler (Zero GCC, Zero Libc runtime, Zero Python) 👑
        if [ -f "$LIPI_INSTALL_DIR/src/compiler/native_elf_compiler.c" ]; then
            info "Building native direct ELF compiler with $cc_cmd..."
            if $cc_cmd -O2 "$LIPI_INSTALL_DIR/src/compiler/native_elf_compiler.c" \
                -o "$LIPI_INSTALL_DIR/bin/lipc_native_elf" 2>/dev/null; then
                chmod +x "$LIPI_INSTALL_DIR/bin/lipc_native_elf"
                ok "Built native direct ELF compiler: $LIPI_INSTALL_DIR/bin/lipc_native_elf 👑"
            fi
        fi
    fi

    # 3. Native compiler command wrapper
    cat > "$LIPI_BIN_DIR/lipc" << COMPILER_WRAPPER
#!/bin/bash
# Lipi Programming Language — Native Compiler Wrapper
# Generated by install.sh — Do not edit manually
LIPI_HOME="$LIPI_INSTALL_DIR"
exec "$LIPI_INSTALL_DIR/bin/lipc" "\$@"
COMPILER_WRAPPER

    chmod +x "$LIPI_BIN_DIR/lipc"
    ok "Created: $LIPI_BIN_DIR/lipc (Native Binary Compiler)"
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
verify_install() {
    info "Verifying installation..."
    
    if "$LIPI_BIN_DIR/lipi" --version &>/dev/null; then
        ok "Lipi works!"
    else
        # Try direct test
        output=$(cd "$LIPI_INSTALL_DIR" && $PYTHON_CMD -m src.runtime -e 'say "install ok"' 2>&1)
        if echo "$output" | grep -q "install ok"; then
            ok "Lipi runtime works!"
        else
            warn "Verification failed — but Lipi should still work from $LIPI_BIN_DIR/lipi"
        fi
    fi
}

# ─── Print success ───────────────────────────────────────────────────────────
print_success() {
    echo ""
    echo -e "  ${LIPI_COLOR_BOLD}${LIPI_COLOR_GREEN}✔ Lipi installed successfully!${LIPI_COLOR_RESET}"
    echo ""
    echo "  Get started:"
    echo ""
    echo -e "    ${LIPI_COLOR_CYAN}lipi${LIPI_COLOR_RESET}                 → Start interactive REPL"
    echo -e "    ${LIPI_COLOR_CYAN}lipi hello.lp${LIPI_COLOR_RESET}        → Run interpreted (.lp file)"
    echo -e "    ${LIPI_COLOR_CYAN}lipc hello.lp${LIPI_COLOR_RESET}        → Compile to native executable (./hello)"
    echo -e "    ${LIPI_COLOR_CYAN}lipc hello.lp -o app${LIPI_COLOR_RESET} → Compile with custom binary name"
    echo -e "    ${LIPI_COLOR_CYAN}lipi --version${LIPI_COLOR_RESET}       → Show version"
    echo -e "    ${LIPI_COLOR_CYAN}lipi --help${LIPI_COLOR_RESET}          → Show help"
    echo ""
    echo "  Quick test:"
    echo -e "    ${LIPI_COLOR_YELLOW}echo 'say \"Hello, World!\"' | lipi${LIPI_COLOR_RESET}"
    echo ""
    echo "  Documentation:"
    echo "    https://github.com/asaudola-cmyk/LiPi_Lang"
    echo ""
    echo "  ⚠  Restart your terminal (or run: source ~/.bashrc)"
    echo ""
}

# ─── Uninstall ───────────────────────────────────────────────────────────────
uninstall() {
    echo "Uninstalling Lipi..."
    rm -f "$LIPI_BIN_DIR/lipi"
    rm -f "$LIPI_BIN_DIR/lipc"
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
    verify_install
    print_success
}

main "$@"
