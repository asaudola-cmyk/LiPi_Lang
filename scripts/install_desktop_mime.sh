#!/bin/bash
# ==============================================================================
# Lipi Programming Language — FreeDesktop Linux Desktop & MIME Installer
# File: scripts/install_desktop_mime.sh
# ==============================================================================
#
# WHY: Linux desktop file managers (Thunar, Nautilus, Nemo, Dolphin, PCManFM)
# resolve file icons using the FreeDesktop.org Shared MIME-info Database and
# XDG Icon Theme specifications.
#
# Previously, *.lp files displayed a grey document icon with '#!' because:
# 1. In ~/.local/share/mime/packages/lipi.xml, an explicit '<icon name="text-x-script"/>'
#    directive forced GIO to resolve the generic shell script icon ('#!').
# 2. No dedicated 'text-x-lipi.svg' icon existed in the user or system icon themes
#    (Papirus-Dark, Papirus, Adwaita, Breeze, hicolor).
#
# This script registers Lipi's sovereign MIME type (text/x-lipi) and installs
# pixel-perfect vector SVGs and raster PNGs across all desktop themes and resolutions.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

HOME_DIR="${HOME:-/root}"
MIME_PACKAGES_DIR="$HOME_DIR/.local/share/mime/packages"
ICONS_BASE_DIR="$HOME_DIR/.local/share/icons"
APPS_DIR="$HOME_DIR/.local/share/applications"

COLOR_GREEN="\033[32m"
COLOR_CYAN="\033[36m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_BOLD="\033[1m"
COLOR_RESET="\033[0m"

log_info()    { echo -e "  ${COLOR_CYAN}→${COLOR_RESET} $1"; }
log_success() { echo -e "  ${COLOR_GREEN}✔${COLOR_RESET} $1"; }
log_warn()    { echo -e "  ${COLOR_YELLOW}⚠${COLOR_RESET} $1"; }
log_error()   { echo -e "  ${COLOR_RED}✘ Error:${COLOR_RESET} $1"; }

echo ""
echo -e "${COLOR_BOLD}${COLOR_CYAN}═════════════════════════════════════════════════════════════════${COLOR_RESET}"
echo -e "${COLOR_BOLD}  👑 LIPI DESKTOP & FREEDESKTOP MIME INSTALLER 👑${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}═════════════════════════════════════════════════════════════════${COLOR_RESET}"
echo ""

# ─── Step 1: Install MIME Definition ──────────────────────────────────────────
install_mime() {
    log_info "Installing FreeDesktop Shared MIME definition for Lipi (.lp, .lipi, .লিপি)..."
    mkdir -p "$MIME_PACKAGES_DIR"

    local mime_src="$REPO_DIR/assets/branding/lipi-mime.xml"
    if [ ! -f "$mime_src" ]; then
        log_error "MIME definition file not found at $mime_src"
        exit 1
    fi

    cp -f "$mime_src" "$MIME_PACKAGES_DIR/lipi.xml"
    log_success "Created: $MIME_PACKAGES_DIR/lipi.xml"

    if command -v update-mime-database &>/dev/null; then
        update-mime-database "$HOME_DIR/.local/share/mime"
        log_success "Updated MIME database: $HOME_DIR/.local/share/mime"
    else
        log_warn "update-mime-database not found in PATH; skipping MIME cache compilation."
    fi
}

# ─── Step 2: Install Desktop & Icon Theme Assets ──────────────────────────────
install_icons() {
    log_info "Installing vector and raster icons across desktop themes..."
    local themes=("Papirus-Dark" "Papirus" "hicolor")
    local sizes=("16" "22" "24" "32" "48" "64" "128")
    local aliases=("application-x-lipi.svg" "text-lipi.svg" "lipi.svg" "gnome-mime-text-x-lipi.svg")

    for theme in "${themes[@]}"; do
        for sz in "${sizes[@]}"; do
            local dir="$ICONS_BASE_DIR/$theme/${sz}x${sz}/mimetypes"
            mkdir -p "$dir"

            local icon_src="$REPO_DIR/assets/branding/desktop_icons/text-x-lipi-${sz}.svg"
            if [ -f "$icon_src" ]; then
                cp -f "$icon_src" "$dir/text-x-lipi.svg"
                for alias in "${aliases[@]}"; do
                    ln -sf "text-x-lipi.svg" "$dir/$alias"
                done
            fi
        done

        # Scalable mimetypes
        local scalable_dir="$ICONS_BASE_DIR/$theme/scalable/mimetypes"
        mkdir -p "$scalable_dir"
        local sc_src="$REPO_DIR/assets/branding/desktop_icons/text-x-lipi-scalable.svg"
        if [ -f "$sc_src" ]; then
            cp -f "$sc_src" "$scalable_dir/text-x-lipi.svg"
            for alias in "${aliases[@]}"; do
                ln -sf "text-x-lipi.svg" "$scalable_dir/$alias"
            done
        fi

        # Scalable Application icon (for desktop launcher / menu)
        local apps_icon_dir="$ICONS_BASE_DIR/$theme/scalable/apps"
        mkdir -p "$apps_icon_dir"
        if [ -f "$REPO_DIR/assets/branding/lipi_mark.svg" ]; then
            cp -f "$REPO_DIR/assets/branding/lipi_mark.svg" "$apps_icon_dir/lipi.svg"
        fi
    done

    # Raster PNG icons in hicolor (fallback for environments without SVG support)
    local png_sizes=("16x16" "32x32" "48x48" "64x64" "128x128" "256x256" "512x512")
    local png_aliases=("application-x-lipi.png" "text-lipi.png" "lipi.png" "gnome-mime-text-x-lipi.png")
    for psz in "${png_sizes[@]}"; do
        local png_src="$REPO_DIR/assets/branding/png/lipi_icon_${psz}.png"
        if [ -f "$png_src" ]; then
            local pdir="$ICONS_BASE_DIR/hicolor/$psz/mimetypes"
            mkdir -p "$pdir"
            cp -f "$png_src" "$pdir/text-x-lipi.png"
            for pa in "${png_aliases[@]}"; do
                ln -sf "text-x-lipi.png" "$pdir/$pa"
            done
        fi
    done

    # Install Desktop launcher entry
    mkdir -p "$APPS_DIR"
    if [ -f "$REPO_DIR/assets/branding/lipi.desktop" ]; then
        cp -f "$REPO_DIR/assets/branding/lipi.desktop" "$APPS_DIR/lipi.desktop"
        log_success "Installed application launcher: $APPS_DIR/lipi.desktop"
    fi

    log_success "Installed vector SVGs and PNG rasters into user icon themes."
}

# ─── Step 3: Rebuild GTK Icon Caches ──────────────────────────────────────────
rebuild_caches() {
    log_info "Rebuilding GTK icon theme caches..."
    if command -v gtk-update-icon-cache &>/dev/null; then
        for theme in "Papirus-Dark" "Papirus" "hicolor"; do
            local tdir="$ICONS_BASE_DIR/$theme"
            if [ -d "$tdir" ]; then
                gtk-update-icon-cache -f -q -t "$tdir" 2>/dev/null || true
            fi
        done
        log_success "GTK icon theme caches refreshed successfully."
    else
        log_warn "gtk-update-icon-cache not found; file manager will read uncompressed icons."
    fi
}

# ─── Step 4: Refresh Running File Managers ────────────────────────────────────
refresh_desktop() {
    # If Thunar is running, restart it cleanly so the user immediately sees the new icons
    if pgrep -x thunar &>/dev/null; then
        log_info "Restarting Thunar to refresh icon cache immediately..."
        thunar -q 2>/dev/null || true
        log_success "Thunar restarted."
    fi
}

# ─── Step 5: Verify ───────────────────────────────────────────────────────────
verify() {
    log_info "Verifying FreeDesktop MIME & Icon resolution..."
    local test_file="$REPO_DIR/universe/web/app.lp"
    if [ -f "$test_file" ] && command -v xdg-mime &>/dev/null; then
        local q_type
        q_type="$(xdg-mime query filetype "$test_file" 2>/dev/null || true)"
        if [ "$q_type" = "text/x-lipi" ]; then
            log_success "xdg-mime query filetype: $q_type (Verified text/x-lipi!)"
        else
            log_warn "xdg-mime reported '$q_type', expected 'text/x-lipi'"
        fi
    fi

    if command -v gio &>/dev/null && [ -f "$test_file" ]; then
        local icon_str
        icon_str="$(gio info "$test_file" 2>/dev/null | grep 'standard::icon:' || true)"
        log_info "GIO file icon resolution: $icon_str"
    fi
}

main() {
    install_mime
    install_icons
    rebuild_caches
    refresh_desktop
    verify
    echo ""
    echo -e "  ${COLOR_BOLD}${COLOR_GREEN}✔ Lipi Linux Desktop & Icon integration completed successfully!${COLOR_RESET}"
    echo ""
}

main "$@"
