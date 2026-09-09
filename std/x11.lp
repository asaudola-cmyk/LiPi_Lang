// 📜 লিপি X11 নেটিভ window ইঞ্জিন (Pure Lipi X11 Windowing Protocol)
// 🏛️ GTK, Qt বা Xlib ছাড়াই direct UNIX ডোমেইন সaেটের মাধ্যমে গ্রাফিa্যাল window!
// ইনোভেশন: /tmp/.X11-unix/X0 সaেটে direct বাইনারি প্যাaেট পাঠিয়ে rate্ডওয়্যার এa্সিলারেশন।

include "std/mem.lp"

// ১. X11 সার্ভারের সাথে UNIX Socket এ aানেa্ট aরা
// WHY: Xlib এর পরাধীনতা দূর aরে we direct X Server-এর সাথে aথা বলছি।
fn এa্স11_aানেa্ট
    // SYS_socket (41): AF_UNIX (1), SOCK_STREAM (1), 0
    socket_fd = syscall(41, 1, 1, 0)
    if socket_fd < 0
        say "❌ UNIX সকেট created ব্যর্থ!"
        return -1

    // sockaddr_un (sun_family = 1, sun_path = "/tmp/.X11-unix/X0")
    // memতে 110 byte বরাদ্দ
    sock_addr = syscall(9, 0, 110, 3, 34, -1, 0)
    mem_fill(sock_addr, 0, 110)

    // sun_family = AF_UNIX (1) -> 16-bit (2 bytes)
    mem_write_byte(sock_addr, 0, 1)
    mem_write_byte(sock_addr, 1, 0)

    // sun_path = "/tmp/.X11-unix/X0"
    mem_write_byte(sock_addr, 2, 47) // '/'
    mem_write_byte(sock_addr, 3, 116) // 't'
    mem_write_byte(sock_addr, 4, 109) // 'm'
    mem_write_byte(sock_addr, 5, 112) // 'p'
    mem_write_byte(sock_addr, 6, 47) // '/'
    mem_write_byte(sock_addr, 7, 46) // '.'
    mem_write_byte(sock_addr, 8, 88) // 'X'
    mem_write_byte(sock_addr, 9, 49) // '1'
    mem_write_byte(sock_addr, 10, 49) // '1'
    mem_write_byte(sock_addr, 11, 45) // '-'
    mem_write_byte(sock_addr, 12, ۱17) // 'u'
    mem_write_byte(sock_addr, 12, 117) // 'u'
    mem_write_byte(sock_addr, 13, 110) // 'n'
    mem_write_byte(sock_addr, 14, 105) // 'i'
    mem_write_byte(sock_addr, 15, ۱20) // 'x'
    mem_write_byte(sock_addr, 15, 120) // 'x'
    mem_write_byte(sock_addr, 16, 47) // '/'
    mem_write_byte(sock_addr, 17, 88) // 'X'
    mem_write_byte(sock_addr, 18, 48) // '0'

    // SYS_connect (42): fd, sockaddr, addrlen (110)
    status = syscall(42, socket_fd, sock_addr, 110)

    syscall(11, sock_addr, 110) // memory রিলিজ

    if status < 0
        say "❌ X11 সার্ভারে কানেক্ট করতে ব্যর্থ (X0 নেই)!"
        return -1

    return socket_fd

// ২. aানেaশন সেটআপ (X11 Connection Setup Packet)
// WHY: X11 সার্ভারaে বলতে হবে যে we লিটল-এন্ডিয়ান (l) এবং ভার্সন 11.0 ব্যবrate aরছি।
fn এa্স11_সেটআপ socket_fd
    প্যাaেট = syscall(9, 0, 12, 3, 34, -1, 0)

    // Byte-order: 'l' = 108 (0x6c) - Little Endian
    mem_write_byte(প্যাaেট, 0, 108)

    // Protocol major version = 11 (0x0b)
    mem_write_byte(প্যাaেট, 2, 11)
    mem_write_byte(প্যাaেট, 3, 0)

    // Protocol minor version = 0
    mem_write_byte(প্যাaেট, 4, 0)
    mem_write_byte(প্যাaেট, 5, 0)

    // Auth name & data len = 0 (16-bit 0)
    mem_write_byte(প্যাaেট, 6, 0)
    mem_write_byte(প্যাaেট, 7, 0)
    mem_write_byte(প্যাaেট, 8, 0)
    mem_write_byte(প্যাaেট, 9, 0)
    mem_write_byte(প্যাaেট, 10, 0)
    mem_write_byte(প্যাaেট, 11, 0)

    // SYS_sendto (44): fd, buf, len, flags, dest_addr, addrlen
    syscall(44, socket_fd, প্যাaেট, 12, 0, 0, 0)
    syscall(11, প্যাaেট, 12)

    // server থেaে রেসপন্স পড়া (SYS_recvfrom = 45)
    // রেসপন্সে Root Window ID এবং Resource Base থাaে যা window তৈরির জন্য লাগবে।
    response = syscall(9, 0, 4096, 3, 34, -1, 0)
    পঠিত_byte = syscall(45, socket_fd, response, 4096, 0, 0, 0)

    if পঠিত_byte < 8
        say "❌ X11 সার্ভার থেকে সঠিক response পাওয়া যায়নি!"
        return -1

    // রেসপন্সের প্রথম byte: 1 = Success, 0 = Failed, 2 = Authenticate
    status = mem_byte_পড়ো(response, 0)
    if status != 1
        say "❌ X11 কানেকশন সেটআপ ব্যর্থ! status কোড: " + status
        return -1

    // Resource ID Base (Offset 12 in X11 Setup Reply)
    // 32-bit ID base
    base0 = mem_byte_পড়ো(response, 12)
    base1 = mem_byte_পড়ো(response, 13)
    base2 = mem_byte_পড়ো(response, 14)
    base3 = mem_byte_পড়ো(response, 15)
    রিসোর্স_base = base0 + (base1 * 256) + (base2 * 65536) + (base3 * 16777216)

    say "✅ X11 কানেকশন সফল! Resource Base ID: " + রিসোর্স_base

    return response // পয়েন্টার return দিচ্ছি
