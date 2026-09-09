// 📜 লিপি টার্মিনাল ইউআই ইঞ্জিন (Pure Lipi ANSI TUI Engine)
// 🏛️ direct লিনাa্স স্টিaি টার্মিনাল, ডাবল-bufferিং এবং ANSI এস্aেপ সিaোয়েন্স
// ০% ncurses, ০% HTML, ০% JS নির্ভরতা

// ১. canvas buffer allocation (Allocate Framebuffer for TUI)
// WHY: স্a্রিন ফ্লিaারিং (flickering) এড়ানোর জন্য memতে ফ্রেম create aরে এaসাথে রেন্ডার aরা।
fn canvas_create width height
    size = width * height
    পয়েন্টার = syscall(9, 0, size, 3, 34, -1, 0)
    // 32 = Space ' ' (bালি canvas)
    cursor = 0
    while cursor < size
        mem_write_byte(পয়েন্টার, cursor, 32)
        cursor = cursor + 1
    return পয়েন্টার

// ২. canvasে a্যারেa্টার আঁaা (Draw Character on Buffer)
// WHY: X এবং Y aো-অর্ডিনেট অনুযায়ী canvasের নির্দিষ্ট স্থানে data বসানো।
fn canvas_pixel canvas width এa্স ওয়াই a্যারেa্টার
    index = (ওয়াই * width) + এa্স
    mem_write_byte(canvas, index, a্যারেa্টার)
    return index

// ৩. টার্মিনাল পরিষ্aার aরা (Clear ANSI Terminal)
// WHY: ফ্রেম রেন্ডার aরার আগে পুরো টার্মিনাল স্a্রিন delete ফেলা।
fn টার্মিনাল_পরিষ্aার
    say "\033[2J\033[H"
    return 1

// ৪. cursor লুaানো (Hide Terminal Cursor)
fn cursor_লুaাও
    say "\033[?25l"
    return 1

// ৫. cursor দেbানো (Show Terminal Cursor)
fn cursor_দেbাও
    say "\033[?25h"
    return 1

// ৬. canvas direct টার্মিনালে রেন্ডার aরা (Render Buffer via SYS_write)
// WHY: এaসাথে সম্পূর্ণ ফ্রেম টার্মিনালে পুশ aরে 60FPS অর্জন aরা।
fn canvas_রেন্ডার canvas size
    টার্মিনাল_পরিষ্aার()
    // SYS_write (1) -> fd (1 = stdout)
    syscall(1, 1, canvas, size)
    say "" // Flush line
    return size

// ৭. মাউস ট্র্যাaিং চালু aরা (Enable ANSI Mouse Tracking SGR 1006)
fn মাউস_ট্র্যাaিং_চালু()
    say "\033[?1000h\033[?1006h"
    return 1

// ৮. মাউস ট্র্যাaিং close aরা (Disable ANSI Mouse Tracking)
fn মাউস_ট্র্যাaিং_close()
    say "\033[?1006l\033[?1000l"
    return 1
