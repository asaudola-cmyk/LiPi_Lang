// ==============================================================================
// 👑 LIPI STANDARD LIBRARY: PURE X11 PROTOCOL CLIENT ENGINE (std/x11.lp)
// ⚡ Zero Xlib | Zero GTK | Zero Qt | Raw UNIX Domain Socket Wire Packets
// ==============================================================================

// WHY: GUI systems programming in sovereign environments must communicate directly
// with the display server over /tmp/.X11-unix/X0 using raw binary X11 protocol packets.
// Zero C library dependencies, zero wrappers, 100% pure Lipi machine code.

include "std/mem.lp"

// ১. X11 প্রোটোকল কনস্ট্যান্টস (X11 Protocol Wire Opcodes)
X11_OP_CREATE_WINDOW      = 1
X11_OP_MAP_WINDOW         = 8
X11_OP_CREATE_GC          = 55
X11_OP_POLY_FILL_RECTANGLE = 70
X11_OP_IMAGE_TEXT8        = 76

X11_CW_BACK_PIXEL         = 2
X11_GC_FOREGROUND         = 4

// ২. X11 সার্ভারের সাথে UNIX Socket এ কানেক্ট করা (Connect to /tmp/.X11-unix/X0)
// WHY: Connects to local display server via Linux AF_UNIX domain stream socket.
fn x11_connect display
    // SYS_socket (41): AF_UNIX (1), SOCK_STREAM (1), protocol (0)
    socket_fd = syscall(41, 1, 1, 0)
    if socket_fd < 0
        say "[ত্রুটি] UNIX সকেট তৈরি করতে ব্যর্থ!"
        return -1

    // sockaddr_un: sun_family = AF_UNIX (1), sun_path = "/tmp/.X11-unix/X0"
    sock_addr = malloc(110)
    mem_fill(sock_addr, 0, 110)

    // sun_family = 1 (16-bit little-endian)
    mem_write_byte(sock_addr, 0, 1)
    mem_write_byte(sock_addr, 1, 0)

    // sun_path = "/tmp/.X11-unix/X0"
    mem_write_byte(sock_addr, 2, 47)  // '/'
    mem_write_byte(sock_addr, 3, 116) // 't'
    mem_write_byte(sock_addr, 4, 109) // 'm'
    mem_write_byte(sock_addr, 5, 112) // 'p'
    mem_write_byte(sock_addr, 6, 47)  // '/'
    mem_write_byte(sock_addr, 7, 46)  // '.'
    mem_write_byte(sock_addr, 8, 88)  // 'X'
    mem_write_byte(sock_addr, 9, 49)  // '1'
    mem_write_byte(sock_addr, 10, 49) // '1'
    mem_write_byte(sock_addr, 11, 45) // '-'
    mem_write_byte(sock_addr, 12, 117)// 'u'
    mem_write_byte(sock_addr, 13, 110)// 'n'
    mem_write_byte(sock_addr, 14, 105)// 'i'
    mem_write_byte(sock_addr, 15, 120)// 'x'
    mem_write_byte(sock_addr, 16, 47) // '/'
    mem_write_byte(sock_addr, 17, 88) // 'X'
    mem_write_byte(sock_addr, 18, 48) // '0'

    // SYS_connect (42): fd, sockaddr, addrlen (110)
    status = syscall(42, socket_fd, sock_addr, 110)
    free(sock_addr, 110)

    if status < 0
        say "[ত্রুটি] X11 সার্ভারে কানেক্ট করতে ব্যর্থ (/tmp/.X11-unix/X0)!"
        syscall(3, socket_fd)
        return -1

    return socket_fd

fn এক্স১১_কানেক্ট display
    return x11_connect(display)


// ৩. X11 কানেকশন সেটআপ হ্যান্ডশেক (X11 Connection Setup Packet)
// WHY: Informs X11 server about client endianness ('l' = little-endian 0x6c)
// and major/minor version (11.0). Receives Root Window ID and Resource ID Base.
fn x11_setup socket_fd
    packet = malloc(12)
    mem_fill(packet, 0, 12)

    // Byte 0: Byte-order 'l' = 108 (Little-Endian)
    mem_write_byte(packet, 0, 108)
    // Bytes 2..3: Major version = 11 (little-endian)
    mem_write_byte(packet, 2, 11)
    mem_write_byte(packet, 3, 0)
    // Bytes 4..5: Minor version = 0
    mem_write_byte(packet, 4, 0)
    mem_write_byte(packet, 5, 0)

    // Send setup packet via SYS_write (1)
    syscall(1, socket_fd, packet, 12)
    free(packet, 12)

    // Receive setup reply via SYS_read (0)
    reply = malloc(1024)
    read_bytes = syscall(0, socket_fd, reply, 1024)
    if read_bytes < 8
        say "[ত্রুটি] X11 সার্ভার থেকে বৈধ রিপ্লাই পাওয়া যায়নি!"
        free(reply, 1024)
        return -1

    status = mem_byte_পড়ো(reply, 0)
    if status != 1
        say "[ত্রুটি] X11 কানেকশন সেটআপ ব্যর্থ! স্ট্যাটাস কোড: " + status
        free(reply, 1024)
        return -1

    // Resource ID Base (Offset 12 in X11 Setup Reply)
    base0 = mem_byte_পড়ো(reply, 12)
    base1 = mem_byte_পড়ো(reply, 13)
    base2 = mem_byte_পড়ো(reply, 14)
    base3 = mem_byte_পড়ো(reply, 15)
    resource_base = base0 + (base1 * 256) + (base2 * 65536) + (base3 * 16777216)

    free(reply, 1024)
    return resource_base

fn এক্স১১_সেটআপ socket_fd
    return x11_setup(socket_fd)


// ৪. র X11 উইন্ডো তৈরি প্যাকেট (CreateWindow Request: Opcode 1)
// WHY: Synthesizes direct binary wire protocol packet for CreateWindow.
// Packet length: 9 4-byte words = 36 bytes (with CWBackPixel mask).
fn x11_create_window socket_fd window_id parent_id x y width height bg_color
    pkt = malloc(36)
    mem_fill(pkt, 0, 36)

    // Byte 0: Opcode 1 (CreateWindow)
    mem_write_byte(pkt, 0, 1)
    // Byte 1: Depth (0 = CopyFromParent)
    mem_write_byte(pkt, 1, 0)
    // Bytes 2..3: Request length in 4-byte units (9 words = 36 bytes)
    mem_write_byte(pkt, 2, 9)
    mem_write_byte(pkt, 3, 0)

    // Bytes 4..7: Window ID
    mem_write_byte(pkt, 4, window_id % 256)
    mem_write_byte(pkt, 5, (window_id / 256) % 256)
    mem_write_byte(pkt, 6, (window_id / 65536) % 256)
    mem_write_byte(pkt, 7, (window_id / 16777216) % 256)

    // Bytes 8..11: Parent Window ID (Root Window)
    mem_write_byte(pkt, 8, parent_id % 256)
    mem_write_byte(pkt, 9, (parent_id / 256) % 256)
    mem_write_byte(pkt, 10, (parent_id / 65536) % 256)
    mem_write_byte(pkt, 11, (parent_id / 16777216) % 256)

    // Bytes 12..13: X
    mem_write_byte(pkt, 12, x % 256)
    mem_write_byte(pkt, 13, (x / 256) % 256)
    // Bytes 14..15: Y
    mem_write_byte(pkt, 14, y % 256)
    mem_write_byte(pkt, 15, (y / 256) % 256)
    // Bytes 16..17: Width
    mem_write_byte(pkt, 16, width % 256)
    mem_write_byte(pkt, 17, (width / 256) % 256)
    // Bytes 18..19: Height
    mem_write_byte(pkt, 18, height % 256)
    mem_write_byte(pkt, 19, (height / 256) % 256)

    // Bytes 20..21: Border Width = 0
    mem_write_byte(pkt, 20, 0)
    mem_write_byte(pkt, 21, 0)
    // Bytes 22..23: Window Class = 1 (InputOutput)
    mem_write_byte(pkt, 22, 1)
    mem_write_byte(pkt, 23, 0)
    // Bytes 24..27: Visual = 0 (CopyFromParent)
    mem_write_byte(pkt, 24, 0)

    // Bytes 28..31: Value Mask (2 = CWBackPixel)
    mem_write_byte(pkt, 28, 2)
    mem_write_byte(pkt, 29, 0)
    mem_write_byte(pkt, 30, 0)
    mem_write_byte(pkt, 31, 0)

    // Bytes 32..35: Background Pixel Color
    mem_write_byte(pkt, 32, bg_color % 256)
    mem_write_byte(pkt, 33, (bg_color / 256) % 256)
    mem_write_byte(pkt, 34, (bg_color / 65536) % 256)
    mem_write_byte(pkt, 35, (bg_color / 16777216) % 256)

    res = syscall(1, socket_fd, pkt, 36)
    free(pkt, 36)
    return res

fn এক্স১১_উইন্ডো_তৈরি socket_fd window_id parent_id x y width height bg_color
    return x11_create_window(socket_fd, window_id, parent_id, x, y, width, height, bg_color)

// ৫. র X11 উইন্ডো ম্যাপ প্যাকেট (MapWindow Request: Opcode 8)
// WHY: Makes the created window visible on the display. Packet size = 8 bytes.
fn x11_map_window socket_fd window_id
    pkt = malloc(8)
    mem_fill(pkt, 0, 8)

    // Byte 0: Opcode 8 (MapWindow)
    mem_write_byte(pkt, 0, 8)
    // Bytes 2..3: Request length (2 words = 8 bytes)
    mem_write_byte(pkt, 2, 2)
    mem_write_byte(pkt, 3, 0)

    // Bytes 4..7: Window ID
    mem_write_byte(pkt, 4, window_id % 256)
    mem_write_byte(pkt, 5, (window_id / 256) % 256)
    mem_write_byte(pkt, 6, (window_id / 65536) % 256)
    mem_write_byte(pkt, 7, (window_id / 16777216) % 256)

    res = syscall(1, socket_fd, pkt, 8)
    free(pkt, 8)
    return res

fn এক্স১১_উইন্ডো_ম্যাপ socket_fd window_id
    return x11_map_window(socket_fd, window_id)

// ৬. র X11 গ্রাফিক্স কনটেক্সট তৈরি (CreateGC Request: Opcode 55)
// WHY: Creates graphics context for color state and clipping. Packet size = 20 bytes.
fn x11_create_gc socket_fd gc_id drawable_id fg_color
    pkt = malloc(20)
    mem_fill(pkt, 0, 20)

    // Byte 0: Opcode 55 (CreateGC)
    mem_write_byte(pkt, 0, 55)
    // Bytes 2..3: Request length (5 words = 20 bytes)
    mem_write_byte(pkt, 2, 5)
    mem_write_byte(pkt, 3, 0)

    // Bytes 4..7: GC ID
    mem_write_byte(pkt, 4, gc_id % 256)
    mem_write_byte(pkt, 5, (gc_id / 256) % 256)
    mem_write_byte(pkt, 6, (gc_id / 65536) % 256)
    mem_write_byte(pkt, 7, (gc_id / 16777216) % 256)

    // Bytes 8..11: Drawable ID (Window)
    mem_write_byte(pkt, 8, drawable_id % 256)
    mem_write_byte(pkt, 9, (drawable_id / 256) % 256)
    mem_write_byte(pkt, 10, (drawable_id / 65536) % 256)
    mem_write_byte(pkt, 11, (drawable_id / 16777216) % 256)

    // Bytes 12..15: Value Mask (4 = GCForeground)
    mem_write_byte(pkt, 12, 4)
    mem_write_byte(pkt, 13, 0)
    mem_write_byte(pkt, 14, 0)
    mem_write_byte(pkt, 15, 0)

    // Bytes 16..19: Foreground Color
    mem_write_byte(pkt, 16, fg_color % 256)
    mem_write_byte(pkt, 17, (fg_color / 256) % 256)
    mem_write_byte(pkt, 18, (fg_color / 65536) % 256)
    mem_write_byte(pkt, 19, (fg_color / 16777216) % 256)

    res = syscall(1, socket_fd, pkt, 20)
    free(pkt, 20)
    return res

fn এক্স১১_জিসি_তৈরি socket_fd gc_id drawable_id fg_color
    return x11_create_gc(socket_fd, gc_id, drawable_id, fg_color)

// ৭. র X11 আয়তক্ষেত্র অঙ্কন প্যাকেট (PolyFillRectangle Request: Opcode 70)
// WHY: Fills solid rectangle on the server-side window. Packet size = 20 bytes.
fn x11_draw_rect socket_fd drawable_id gc_id x y width height
    pkt = malloc(20)
    mem_fill(pkt, 0, 20)

    // Byte 0: Opcode 70 (PolyFillRectangle)
    mem_write_byte(pkt, 0, 70)
    // Bytes 2..3: Request length (5 words = 20 bytes)
    mem_write_byte(pkt, 2, 5)
    mem_write_byte(pkt, 3, 0)

    // Bytes 4..7: Drawable ID
    mem_write_byte(pkt, 4, drawable_id % 256)
    mem_write_byte(pkt, 5, (drawable_id / 256) % 256)
    mem_write_byte(pkt, 6, (drawable_id / 65536) % 256)
    mem_write_byte(pkt, 7, (drawable_id / 16777216) % 256)

    // Bytes 8..11: GC ID
    mem_write_byte(pkt, 8, gc_id % 256)
    mem_write_byte(pkt, 9, (gc_id / 256) % 256)
    mem_write_byte(pkt, 10, (gc_id / 65536) % 256)
    mem_write_byte(pkt, 11, (gc_id / 16777216) % 256)

    // Bytes 12..13: X
    mem_write_byte(pkt, 12, x % 256)
    mem_write_byte(pkt, 13, (x / 256) % 256)
    // Bytes 14..15: Y
    mem_write_byte(pkt, 14, y % 256)
    mem_write_byte(pkt, 15, (y / 256) % 256)
    // Bytes 16..17: Width
    mem_write_byte(pkt, 16, width % 256)
    mem_write_byte(pkt, 17, (width / 256) % 256)
    // Bytes 18..19: Height
    mem_write_byte(pkt, 18, height % 256)
    mem_write_byte(pkt, 19, (height / 256) % 256)

    res = syscall(1, socket_fd, pkt, 20)
    free(pkt, 20)
    return res

fn এক্স১১_আয়তক্ষেত্র socket_fd drawable_id gc_id x y width height
    return x11_draw_rect(socket_fd, drawable_id, gc_id, x, y, width, height)

// ৮. র X11 টেক্সট রেন্ডারিং প্যাকেট (ImageText8 Request: Opcode 76)
// WHY: Direct client-to-server text rasterization.
fn x11_draw_text socket_fd drawable_id gc_id x y text
    slen = len(text)
    pad = (4 - ((16 + slen) % 4)) % 4
    total_bytes = 16 + slen + pad
    words = total_bytes / 4

    pkt = malloc(total_bytes)
    mem_fill(pkt, 0, total_bytes)

    // Byte 0: Opcode 76 (ImageText8)
    mem_write_byte(pkt, 0, 76)
    // Byte 1: String length
    mem_write_byte(pkt, 1, slen)
    // Bytes 2..3: Request length in 4-byte units
    mem_write_byte(pkt, 2, words % 256)
    mem_write_byte(pkt, 3, (words / 256) % 256)

    // Bytes 4..7: Drawable ID
    mem_write_byte(pkt, 4, drawable_id % 256)
    mem_write_byte(pkt, 5, (drawable_id / 256) % 256)
    mem_write_byte(pkt, 6, (drawable_id / 65536) % 256)
    mem_write_byte(pkt, 7, (drawable_id / 16777216) % 256)

    // Bytes 8..11: GC ID
    mem_write_byte(pkt, 8, gc_id % 256)
    mem_write_byte(pkt, 9, (gc_id / 256) % 256)
    mem_write_byte(pkt, 10, (gc_id / 65536) % 256)
    mem_write_byte(pkt, 11, (gc_id / 16777216) % 256)

    // Bytes 12..13: X
    mem_write_byte(pkt, 12, x % 256)
    mem_write_byte(pkt, 13, (x / 256) % 256)
    // Bytes 14..15: Y
    mem_write_byte(pkt, 14, y % 256)
    mem_write_byte(pkt, 15, (y / 256) % 256)

    // Bytes 16..: ASCII characters
    i = 0
    while i < slen
        ch = ord(char_at(text, i))
        mem_write_byte(pkt, 16 + i, ch)
        i = i + 1

    res = syscall(1, socket_fd, pkt, total_bytes)
    free(pkt, total_bytes)
    return res

fn এক্স১১_টেক্সট_আঁকো socket_fd drawable_id gc_id x y text
    return x11_draw_text(socket_fd, drawable_id, gc_id, x, y, text)

// ৯. X11 বাফার ফ্লাশ ও সকেট ক্লোজ (Flush & Close Socket)
fn x11_flush socket_fd
    return 1

fn এক্স১১_ফ্লাশ socket_fd
    return 1

fn x11_close socket_fd
    return syscall(3, socket_fd)

fn এক্স১১_বন্ধ socket_fd
    return x11_close(socket_fd)

