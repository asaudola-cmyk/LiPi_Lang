// ==============================================================================
// 👑 LIPI UNIVERSE GUI — GRAND UMBRELLA PRELUDE (universe/gui.lp)
// ⚡ 100% Pure Sovereign Lipi Machine Code Engine | Zero X11 | Zero Wayland
// ==============================================================================
//
// WHY: Provides a unified gateway for all graphical rendering, windowing,
// 2D primitives, and terminal user interfaces (TUI) in pure Lipi.
// Developers can simply write:
//     import "universe/gui"
// to access direct Linux /dev/fb0 hardware framebuffer rendering, Bresenham canvas,
// desktop windows, buttons, and ANSI curses-like terminal interfaces.
// ==============================================================================

import "universe/gui/framebuffer"
import "universe/gui/canvas"
import "universe/gui/window"
import "universe/gui/tui"
import "universe/gui/font"

// ── Virtual / Hardware Framebuffer Factory ────────────────────────────────────
// WHY: Opens Linux /dev/fb0 or seamlessly creates a 64-byte aligned virtual buffer.
@fn lipi_gui_open(width, height)
    if width <= 0
        width = 640
    end
    if height <= 0
        height = 480
    end
    return lipi_fb_open(width, height)
@end

@fn লিপি_গুই_ওপেন(প্রস্থ, উচ্চতা)
    return lipi_gui_open(প্রস্থ, উচ্চতা)
@end
