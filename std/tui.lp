// ==============================================================================
// 👑 LIPI STANDARD LIBRARY: TERMINAL UI & ANSI ENGINE (std/tui.lp)
// ⚡ Direct Linux TTY | ANSI 256/RGB Color | Double-Buffered Canvas | Zero Libc
// ==============================================================================

// WHY: High-performance terminal applications require direct ANSI sequence synthesis
// and double-buffered text canvases without heavy C dependencies like ncurses.
// std/tui.lp implements 24-bit TrueColor RGB, 256-color palette, cursor control,
// mouse event tracking, and flicker-free frame rendering.

include "std/mem.lp"

// ১. ANSI টেক্সট স্টাইল ও রিসেট ফরম্যাটিং (ANSI Formatting Sequences)
fn ansi_reset
    return "\033[0m"

fn ansi_bold
    return "\033[1m"

fn ansi_dim
    return "\033[2m"

fn ansi_italic
    return "\033[3m"

fn ansi_underline
    return "\033[4m"

fn ansi_reverse
    return "\033[7m"

// ২. ANSI ১৬ স্ট্যান্ডার্ড কালার (Standard 16 Colors)
fn ansi_fg_black   = "\033[30m"
fn ansi_fg_red     = "\033[31m"
fn ansi_fg_green   = "\033[32m"
fn ansi_fg_yellow  = "\033[33m"
fn ansi_fg_blue    = "\033[34m"
fn ansi_fg_magenta = "\033[35m"
fn ansi_fg_cyan    = "\033[36m"
fn ansi_fg_white   = "\033[37m"

fn ansi_bg_black   = "\033[40m"
fn ansi_bg_red     = "\033[41m"
fn ansi_bg_green   = "\033[42m"
fn ansi_bg_yellow  = "\033[43m"
fn ansi_bg_blue    = "\033[44m"
fn ansi_bg_magenta = "\033[45m"
fn ansi_bg_cyan    = "\033[46m"
fn ansi_bg_white   = "\033[47m"

// ৩. ANSI ২৫৬-কালার প্যালেট ফরম্যাটিং (ANSI 256 Color Mode)
// WHY: Allows rich indexed color styling: "\033[38;5;<color>m" for foreground
// and "\033[48;5;<color>m" for background.
fn ansi_fg_256 color_idx
    return "\033[38;5;" + color_idx + "m"

fn ansi_bg_256 color_idx
    return "\033[48;5;" + color_idx + "m"

// ৪. ANSI ২৪-বিট ট্রু-কালার আরজিবি ফরম্যাটিং (24-bit TrueColor RGB Formatting)
// WHY: Synthesizes direct 16.7-million color RGB escape codes: "\033[38;2;r;g;bm".
fn ansi_fg_rgb r g b
    return "\033[38;2;" + r + ";" + g + ";" + b + "m"

fn ansi_bg_rgb r g b
    return "\033[48;2;" + r + ";" + g + ";" + b + "m"

// ৫. কার্সার ও স্ক্রিন কন্ট্রোল (Cursor Movement & Screen Control)
// WHY: Clears terminal buffers and positions cursor at (row, col) coordinates without redrawing everything.
fn terminal_clear
    say "\033[2J\033[H"
    return 1

fn টার্মিনাল_পরিষ্কার
    return terminal_clear()


fn cursor_hide
    say "\033[?25l"
    return 1

fn কার্সার_লুকাও
    return cursor_hide()


fn cursor_show
    say "\033[?25h"
    return 1

fn কার্সার_দেখাও
    return cursor_show()


fn cursor_move_to row col
    say "\033[" + row + ";" + col + "H"
    return 1

// ৬. ডাবল-বাফারড টিইউআই ক্যানভাস বরাদ্দকরণ (Allocate Double-Buffered Text Canvas)
// WHY: Eliminates visual flickering by composing the full text frame in private heap memory
// before pushing it to stdout in a single write syscall.
fn tui_canvas_create width height
    size = width * height
    // Allocate anonymous memory via SYS_mmap (Syscall 9)
    ptr = syscall(9, 0, size, 3, 34, -1, 0)
    // Pre-fill buffer with space character (ASCII 32 = ' ')
    cursor = 0
    while cursor < size
        mem_write_byte(ptr, cursor, 32)
        cursor = cursor + 1
    return ptr

fn canvas_create width height
    return tui_canvas_create(width, height)

// ৭. ক্যানভাস মেমরি অবমুক্তি (Deallocate TUI Canvas)
fn tui_canvas_free canvas width height
    size = width * height
    return syscall(11, canvas, size)

// ৮. ক্যানভাসে ক্যারেক্টার স্থাপন (Set Character on Text Canvas)
// WHY: Places ASCII character byte at grid coordinate (x, y).
fn tui_canvas_pixel canvas width x y char_code
    if x >= 0 and x < width and y >= 0
        idx = (y * width) + x
        mem_write_byte(canvas, idx, char_code)
        return idx
    return -1

fn canvas_pixel canvas width x y char_code
    return tui_canvas_pixel(canvas, width, x, y, char_code)

// ৯. ক্যানভাস টার্মিনালে একবারে রেন্ডার করা (Flush Canvas via Single SYS_write)
// WHY: Pushes entire 2D framebuffer to stdout (fd 1) in one shot to achieve 60FPS.
fn tui_canvas_render canvas size
    terminal_clear()
    // SYS_write (1) -> fd (1 = stdout)
    syscall(1, 1, canvas, size)
    say ""
    return size

fn canvas_রেন্ডার canvas size
    return tui_canvas_render(canvas, size)

// ১০. মাউস ট্র্যাকিং এসজিআর চালু ও বন্ধ (ANSI SGR 1006 Mouse Tracking)
// WHY: Enables mouse click and motion tracking inside the terminal emulator.
fn mouse_tracking_enable
    say "\033[?1000h\033[?1006h"
    return 1

fn মাউস_ট্র্যাকিং_চালু
    return mouse_tracking_enable()


fn mouse_tracking_disable
    say "\033[?1006l\033[?1000l"
    return 1

fn মাউস_ট্র্যাকিং_বন্ধ
    return mouse_tracking_disable()


