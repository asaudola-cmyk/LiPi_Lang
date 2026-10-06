#!/bin/sh
# =============================================================================
# Lipi Programming Language — Install Script
# GitHub: https://github.com/asaudola-cmyk/LiPi_Lang
# Usage:  curl -fsSL https://raw.githubusercontent.com/asaudola-cmyk/LiPi_Lang/main/install.sh | bash
#         or: curl -fsSL https://raw.githubusercontent.com/asaudola-cmyk/LiPi_Lang/main/install.sh | sh
# =============================================================================

set -e

LIPI_VERSION="First 1.0.0 (প্রথম ১.০.০)"
LIPI_REPO="https://github.com/asaudola-cmyk/LiPi_Lang.git"
LIPI_INSTALL_DIR="${LIPI_INSTALL_DIR:-$HOME/.lipi}"
LIPI_BIN_DIR="${LIPI_BIN_DIR:-$HOME/.local/bin}"
LIPI_COLOR_GREEN="\033[32m"
LIPI_COLOR_CYAN="\033[36m"
LIPI_COLOR_YELLOW="\033[33m"
LIPI_COLOR_RED="\033[31m"
LIPI_COLOR_BOLD="\033[1m"
LIPI_COLOR_RESET="\033[0m"

ok()   { printf "  %b✔%b %s\n" "${LIPI_COLOR_GREEN}" "${LIPI_COLOR_RESET}" "$1"; }
fail() { printf "  %b✘ Error: %s%b\n" "${LIPI_COLOR_RED}" "$1" "${LIPI_COLOR_RESET}" >&2; exit 1; }
info() { printf "  %b→%b %s\n" "${LIPI_COLOR_CYAN}" "${LIPI_COLOR_RESET}" "$1"; }
warn() { printf "  %b⚠%b %s\n" "${LIPI_COLOR_YELLOW}" "${LIPI_COLOR_RESET}" "$1"; }

header() {
    printf "\n"
    printf "%b%b" "${LIPI_COLOR_BOLD}" "${LIPI_COLOR_CYAN}"
    printf "  ██╗     ██╗██████╗ ██╗\n"
    printf "  ██║     ██║██╔══██╗██║\n"
    printf "  ██║     ██║██████╔╝██║\n"
    printf "  ██║     ██║██╔═══╝ ██║\n"
    printf "  ███████╗██║██║     ██║\n"
    printf "  ╚══════╝╚═╝╚═╝     ╚═╝\n"
    printf "%b" "${LIPI_COLOR_RESET}"
    printf "  %bLipi Programming Language%b — %b%s%b\n" "${LIPI_COLOR_BOLD}" "${LIPI_COLOR_RESET}" "${LIPI_COLOR_YELLOW}" "${LIPI_VERSION}" "${LIPI_COLOR_RESET}"
    printf "  The world's first globally-ready language with Unicode identifiers\n\n"
}

# ─── Check Architecture & Operating System ──────────────────────────────────
check_system() {
    OS="$(uname -s 2>/dev/null || echo "Linux")"
    ARCH="$(uname -m 2>/dev/null || echo "x86_64")"

    if [ "$OS" = "Darwin" ]; then
        warn "Detected macOS ($ARCH). LiPi silicon compiler directly emits Linux x86_64 ELF binaries."
        warn "To run LiPi on macOS, use Docker, OrbStack, or a Linux VM (Lima / Multipass)."
    elif [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "amd64" ]; then
        warn "Detected architecture: $ARCH. LiPi direct silicon engine targets x86_64."
        warn "Running on $ARCH requires qemu-user-static emulation or secondary C codegen backend."
    fi
}

# ─── Check Toolchain ─────────────────────────────────────────────────────────
check_toolchain() {
    info "Checking toolchain (100% Sovereign Native Engine)..."
    CC_CMD=""
    
    for c_cmd in gcc clang cc; do
        if command -v "$c_cmd" >/dev/null 2>&1; then
            CC_CMD="$c_cmd"
            ok "Secondary native C compiler found: $c_cmd"
            break
        fi
    done

    if [ -z "$CC_CMD" ]; then
        info "Standalone direct ELF machine code engine will be used (0% GCC, 0% Libc) 👑"
    fi
}

# ─── Install Repository ──────────────────────────────────────────────────────
install_lipi() {
    # 1. If already running inside an existing LiPi repository, use current directory directly
    if [ -f "./src/compiler/driver_cli.lp" ] && [ -f "./src/boot/lipi-seed" ]; then
        LIPI_INSTALL_DIR="$(pwd)"
        ok "Running inside local LiPi repository: $LIPI_INSTALL_DIR"
        return 0
    fi

    # 2. Check if existing target directory is valid
    if [ -f "$LIPI_INSTALL_DIR/src/compiler/driver_cli.lp" ]; then
        if [ -d "$LIPI_INSTALL_DIR/.git" ] && command -v git >/dev/null 2>&1; then
            info "Updating existing installation in $LIPI_INSTALL_DIR..."
            git -C "$LIPI_INSTALL_DIR" pull --quiet 2>/dev/null || true
        fi
        ok "Valid LiPi installation directory ready: $LIPI_INSTALL_DIR"
        return 0
    fi

    info "Installing to $LIPI_INSTALL_DIR ..."
    mkdir -p "$LIPI_INSTALL_DIR"

    # Strategy 1: Git clone
    if command -v git >/dev/null 2>&1; then
        rm -rf "$LIPI_INSTALL_DIR"
        git clone --quiet --depth=1 "$LIPI_REPO" "$LIPI_INSTALL_DIR"
    # Strategy 2: Curl + Tar fallback (ideal for minimal docker containers)
    elif command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
        info "git not found — downloading source archive via curl..."
        curl -sSL "https://github.com/asaudola-cmyk/LiPi_Lang/archive/refs/heads/main.tar.gz" | tar -xz -C "$LIPI_INSTALL_DIR" --strip-components=1
    # Strategy 3: Wget + Tar fallback
    elif command -v wget >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
        info "git not found — downloading source archive via wget..."
        wget -qO- "https://github.com/asaudola-cmyk/LiPi_Lang/archive/refs/heads/main.tar.gz" | tar -xz -C "$LIPI_INSTALL_DIR" --strip-components=1
    else
        fail "Neither git nor curl/wget+tar found. Please install git or curl to proceed."
    fi

    if [ ! -f "$LIPI_INSTALL_DIR/src/compiler/driver_cli.lp" ]; then
        fail "Failed to retrieve LiPi repository files into $LIPI_INSTALL_DIR"
    fi
    ok "Lipi repository ready"
}

# ─── Create lipi and lipc commands ──────────────────────────────────────────
create_command() {
    info "Setting up native standalone toolchain in $LIPI_BIN_DIR..."
    mkdir -p "$LIPI_BIN_DIR"
    mkdir -p "$LIPI_INSTALL_DIR/bin"
    mkdir -p "$LIPI_INSTALL_DIR/dist"
    
    # WHY: Execute compilation inside $LIPI_INSTALL_DIR because LiPi's compiler
    # resolves relative includes (src/compiler/..., universe/...) from the working directory.
    (
        cd "$LIPI_INSTALL_DIR" || exit 1

        # Ensure seed file has execute permissions
        [ -f "src/boot/lipi-seed" ] && chmod +x "src/boot/lipi-seed" 2>/dev/null || true

        # 1. Ensure canonical compiler binary exists from bootstrap seed
        if [ ! -x "bin/lipc" ] && [ ! -x "bin/lipc_bin" ]; then
            SEED_EXEC="/tmp/lipi_genesis_seed_$$"
            if [ -f "src/boot/lipi-seed" ]; then
                cp "src/boot/lipi-seed" "$SEED_EXEC"
                chmod +x "$SEED_EXEC"
            elif [ -f "src/boot/seed.b64" ]; then
                if command -v base64 >/dev/null 2>&1; then
                    base64 -d "src/boot/seed.b64" > "$SEED_EXEC" 2>/dev/null || \
                    base64 --decode "src/boot/seed.b64" > "$SEED_EXEC" 2>/dev/null || \
                    base64 -D "src/boot/seed.b64" > "$SEED_EXEC" 2>/dev/null || true
                fi
                chmod +x "$SEED_EXEC" 2>/dev/null || true
            fi
            
            if [ -x "$SEED_EXEC" ]; then
                info "Bootstrapping Stage-3 Modular Silicon Compiler from genesis seed..."
                if "$SEED_EXEC" src/compiler/driver_cli.lp bin/lipc_bin; then
                    chmod +x bin/lipc_bin
                    # Expand arena to 4GB (0x100000000) at offset 202 (0xca) for self-hosting stability
                    printf '\x00\x00\x00\x00\x01\x00\x00\x00' | dd of=bin/lipc_bin bs=1 seek=202 count=8 conv=notrunc >/dev/null 2>&1 || true
                    cp -f bin/lipc_bin bin/lipc
                    cp -f bin/lipc_bin bin/lipc_micro
                    chmod +x bin/lipc bin/lipc_micro
                    ok "Stage-3 Compiler successfully instantiated from source"
                else
                    warn "Seed driver compilation failed, falling back to direct genesis seed"
                    cp "$SEED_EXEC" bin/lipc
                    cp "$SEED_EXEC" bin/lipc_bin
                    cp "$SEED_EXEC" bin/lipc_micro
                    chmod +x bin/lipc bin/lipc_bin bin/lipc_micro
                fi
                rm -f "$SEED_EXEC"
            else
                fail "Could not find or decode bootstrap seed in src/boot/"
            fi
        fi

        [ -x "bin/lipc" ] || cp -f bin/lipc_bin bin/lipc 2>/dev/null || true
        [ -x "bin/lipc_bin" ] || cp -f bin/lipc bin/lipc_bin 2>/dev/null || true
        [ -x "bin/lipc_micro" ] || cp -f bin/lipc bin/lipc_micro 2>/dev/null || true

        # 2. Ensure dist/lipi-language-1.0.0.vsix package exists if editors/vscode present
        if [ -d "editors/vscode" ] && [ ! -f "dist/lipi-language-1.0.0.vsix" ] && command -v zip >/dev/null 2>&1; then
            ( cd editors/vscode && zip -rq ../../dist/lipi-language-1.0.0.vsix . >/dev/null 2>&1 || true )
        fi

        # 3. Compile developer toolchain from pure source using the instantiated compiler
        if [ -x "bin/lipc" ]; then
            info "Building sovereign developer toolchain from pure source..."
            
            build_tool() {
                t_src="$1"
                t_dst="$2"
                if [ ! -x "$t_dst" ]; then
                    if ./bin/lipc "$t_src" "$t_dst" >/dev/null 2>&1; then
                        chmod +x "$t_dst"
                    else
                        warn "Failed to compile $t_src to $t_dst"
                    fi
                fi
            }

            build_tool "src/tools/lipi.lp" "bin/lipi"
            build_tool "src/tools/lipipkg.lp" "bin/lipipkg"
            build_tool "src/tools/lipilsp.lp" "bin/lipilsp"
            build_tool "src/tools/lipidbg.lp" "bin/lipidbg"
            build_tool "src/tools/lipifmt.lp" "bin/lipifmt"
            build_tool "src/tools/lipiconvert.lp" "bin/lipiconvert"
            build_tool "src/tools/lipidoc.lp" "bin/lipidoc"
            build_tool "src/tools/lipirepl.lp" "bin/lipirepl"
            build_tool "src/tools/lipiassimilate.lp" "bin/lipiassimilate"
            build_tool "build.lp" "bin/lipi-build"
            build_tool "tests/run_tests.lp" "bin/lipi-test"
        fi
    )
    
    # Safely symlink all built binaries into user's bin dir
    link_tool() {
        t_name="$1"
        t_desc="$2"
        if [ -x "$LIPI_INSTALL_DIR/bin/$t_name" ]; then
            ln -sf "$LIPI_INSTALL_DIR/bin/$t_name" "$LIPI_BIN_DIR/$t_name"
            ok "Linked: $LIPI_BIN_DIR/$t_name ($t_desc)"
        fi
    }

    link_tool "lipi" "Sovereign CLI Driver & Runner"
    link_tool "lipc" "Direct Silicon Machine Code Compiler"
    link_tool "lipc_bin" "Native Machine Code Compiler Engine"
    link_tool "lipc_micro" "Micro-Architectural Compiler Engine"
    link_tool "lipipkg" "Ed25519 Cryptographic Package Manager"
    link_tool "lipilsp" "LSP IDE Engine"
    link_tool "lipidbg" "Native System Debugger"
    link_tool "lipifmt" "Canonical Code Formatter"
    link_tool "lipiconvert" "Universal Legacy Transpiler"
    link_tool "lipidoc" "Markdown Documentation Engine"
    link_tool "lipirepl" "Interactive Real-Time REPL"
    link_tool "lipiassimilate" "AI Architecture Assimilator"
    link_tool "lipi-build" "Native Build Orchestrator"
    link_tool "lipi-test" "Regression Test Engine"
    if [ -x "$LIPI_INSTALL_DIR/bin/lipilsp" ]; then
        ln -sf "$LIPI_INSTALL_DIR/bin/lipilsp" "$LIPI_BIN_DIR/lipils"
    fi
}

# ─── Add to PATH ─────────────────────────────────────────────────────────────
setup_path() {
    added=0
    
    # Detect shell config file across bash, zsh, ksh, sh
    for cfg in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.bash_profile"; do
        if [ -f "$cfg" ]; then
            if ! grep -q 'LIPI_PATH_ADDED' "$cfg" 2>/dev/null; then
                printf '\n# Lipi Programming Language — LIPI_PATH_ADDED\nexport PATH="%s:$PATH"\n' "$LIPI_BIN_DIR" >> "$cfg"
                added=1
            fi
        fi
    done

    # Support fish shell
    if [ -d "$HOME/.config/fish" ]; then
        fish_cfg="$HOME/.config/fish/config.fish"
        if [ -f "$fish_cfg" ] && ! grep -q 'LIPI_PATH_ADDED' "$fish_cfg" 2>/dev/null; then
            printf '\n# Lipi Programming Language — LIPI_PATH_ADDED\nfish_add_path %s\n' "$LIPI_BIN_DIR" >> "$fish_cfg"
            added=1
        fi
    fi

    # In minimal environments where no rc exists, create ~/.profile
    if [ "$added" -eq 0 ] && [ ! -f "$HOME/.bashrc" ] && [ ! -f "$HOME/.profile" ]; then
        printf '# Lipi Programming Language — LIPI_PATH_ADDED\nexport PATH="%s:$PATH"\n' "$LIPI_BIN_DIR" >> "$HOME/.profile"
        added=1
    fi
    
    # Export for current session
    export PATH="$LIPI_BIN_DIR:$PATH"
    
    if [ "$added" -eq 1 ]; then
        ok "Added $LIPI_BIN_DIR to PATH in shell config"
    else
        ok "$LIPI_BIN_DIR already configured in PATH"
    fi
}

# ─── Verify ──────────────────────────────────────────────────────────────────
verify_install() {
    info "Verifying sovereign installation..."
    
    if "$LIPI_BIN_DIR/lipi" version >/dev/null 2>&1; then
        ok "Lipi sovereign toolchain works!"
    elif "$LIPI_BIN_DIR/lipc" --version >/dev/null 2>&1; then
        ok "Lipi direct machine code compiler works!"
    else
        warn "Verification check had non-zero status — binaries are installed in $LIPI_BIN_DIR"
    fi
}

# ─── Print success ───────────────────────────────────────────────────────────
print_success() {
    printf "\n"
    printf "  %b%b✔ Lipi installed successfully!%b\n\n" "${LIPI_COLOR_BOLD}" "${LIPI_COLOR_GREEN}" "${LIPI_COLOR_RESET}"
    printf "  Get started with modern Lipi CLI:\n\n"
    printf "    %blipi run <file.lp>%b     → Run program in-memory (0%% disk overhead)\n" "${LIPI_COLOR_CYAN}" "${LIPI_COLOR_RESET}"
    printf "    %blipi build <file.lp>%b   → Compile standalone native executable\n" "${LIPI_COLOR_CYAN}" "${LIPI_COLOR_RESET}"
    printf "    %blipi repl%b              → Start interactive REPL\n" "${LIPI_COLOR_CYAN}" "${LIPI_COLOR_RESET}"
    printf "    %blipi test%b              → Run autonomous test suites\n" "${LIPI_COLOR_CYAN}" "${LIPI_COLOR_RESET}"
    printf "    %blipi clean%b             → Clean scratch artifacts (0%% shell)\n" "${LIPI_COLOR_CYAN}" "${LIPI_COLOR_RESET}"
    printf "    %blipi version%b           → Show version & platform architecture\n\n" "${LIPI_COLOR_CYAN}" "${LIPI_COLOR_RESET}"
    printf "  Quick test:\n"
    printf "    %blipi run examples/01_hello_world/main.lp%b\n\n" "${LIPI_COLOR_YELLOW}" "${LIPI_COLOR_RESET}"
    printf "  Documentation:\n"
    printf "    https://github.com/asaudola-cmyk/LiPi_Lang\n\n"
    printf "  ⚠  Restart your terminal (or run: export PATH=\"%s:\$PATH\")\n\n" "$LIPI_BIN_DIR"
}

# ─── Setup Desktop MIME & Icons ──────────────────────────────────────────────
setup_desktop_mime() {
    info "Setting up Linux desktop MIME types and file manager icons..."
    mime_dir="$HOME/.local/share/mime/packages"
    icons_dir="$HOME/.local/share/icons/hicolor/scalable/mimetypes"
    mkdir -p "$mime_dir" "$icons_dir" 2>/dev/null || true
    if [ -f "$LIPI_INSTALL_DIR/docs/branding/lipi-mime.xml" ]; then
        cp -f "$LIPI_INSTALL_DIR/docs/branding/lipi-mime.xml" "$mime_dir/lipi.xml" 2>/dev/null || true
        if command -v update-mime-database >/dev/null 2>&1; then
            update-mime-database "$HOME/.local/share/mime" >/dev/null 2>&1 || true
        fi
    fi
    if [ -f "$LIPI_INSTALL_DIR/docs/branding/lipi_logo.svg" ]; then
        cp -f "$LIPI_INSTALL_DIR/docs/branding/lipi_logo.svg" "$icons_dir/text-x-lipi.svg" 2>/dev/null || true
        if command -v gtk-update-icon-cache >/dev/null 2>&1; then
            gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
        fi
    fi
    ok "Desktop MIME and vector icon integration registered"
}

# ─── Uninstall ───────────────────────────────────────────────────────────────
uninstall() {
    echo "Uninstalling Lipi..."
    rm -f "$LIPI_BIN_DIR/lipi" \
         "$LIPI_BIN_DIR/lipc" \
         "$LIPI_BIN_DIR/lipc_bin" \
         "$LIPI_BIN_DIR/lipc_micro" \
         "$LIPI_BIN_DIR/lipipkg" \
         "$LIPI_BIN_DIR/lipils" \
         "$LIPI_BIN_DIR/lipilsp" \
         "$LIPI_BIN_DIR/lipifmt" \
         "$LIPI_BIN_DIR/lipidbg" \
         "$LIPI_BIN_DIR/lipiconvert" \
         "$LIPI_BIN_DIR/lipidoc" \
         "$LIPI_BIN_DIR/lipirepl" \
         "$LIPI_BIN_DIR/lipiassimilate" \
         "$LIPI_BIN_DIR/lipi-build" \
         "$LIPI_BIN_DIR/lipi-test"
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
    
    check_system
    check_toolchain
    install_lipi
    create_command
    setup_path
    setup_desktop_mime
    verify_install
    print_success
}

main "$@"
