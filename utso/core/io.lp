// ==============================================================================
// 👑 LIPI CORE I/O ENGINE: SOVEREIGN DIRECT KERNEL SYSCALL I/O (utso/core/io.lp)
// ⚡ 100% Native Linux Kernel AMD64 ABI | SYS_read/SYS_write/SYS_open/SYS_close | Zero Libc
// ==============================================================================

// WHY: High-performance systems I/O requires direct kernel interaction without the
// overhead of C stdio buffering or POSIX libc abstractions.
// This module provides low-level file descriptor syscalls, standard stream routines,
// high-level file utilities, and bilingual Bengali/English standard library APIs.

// ── File Descriptor & Open Flag Constants ─────────────────────────────────────
STDIN    = 0
STDOUT   = 1
STDERR   = 2

O_RDONLY = 0
O_WRONLY = 1
O_RDWR   = 2
O_CREAT  = 64
O_TRUNC  = 512

// ── ১. স্ট্যান্ডার্ড আউটপুট ও এরর স্ট্রিমিং (Standard Stream Printing) ─────────
// WHY: কনসোল ও স্ট্যান্ডার্ড আউটপুটে স্ট্রিং প্রিন্ট করা।
include "utso/core/memory.lp"

fn write_out msg
    say msg

fn write_err msg
    say "[ERR] " + msg

fn println msg
    say msg

fn print_raw msg
    // WHY: Direct Linux SYS_write (syscall 1) to STDOUT (fd 1) without appending newline.
    // 0% libc stdio dependency.
    if msg == "" return 0
    return syscall(1, 1, msg, len(msg), 0, 0, 0)

fn প্রিন্ট_র msg
    return print_raw(msg)

fn print_inline msg
    // WHY: High-performance inline printing without trailing newline.
    return print_raw(msg)

fn প্রিন্ট_ইনলাইন msg
    return print_raw(msg)

g_io_last_read_bytes = 0

fn io_last_read_bytes
    return g_io_last_read_bytes

fn আইও_সর্বশেষ_পঠিত_বাইট
    return io_last_read_bytes()

// ── ১খ. ৮KB বাফার্ড রিডার ও রাইটার (8KB Buffered BufReader / BufWriter) ───────
// WHY: Eliminates 1-byte-per-syscall overhead on stdin/file streams (1,024x fewer syscalls
// per KB!) while maintaining exact newline framing across arbitrary chunk boundaries.

struct BufReader
    br_fd
    br_buf
    br_cap
    br_pos
    br_len
    br_eof
end

fn buf_reader_new fd cap
    c = cap
    if c < 256 c = 8192 end
    b = malloc(c)
    return BufReader(fd, b, c, 0, 0, 0)
end

fn buf_reader_free r
    if r != 0 and r.br_buf != 0
        free(r.br_buf, r.br_cap)
        r.br_buf = 0
    end
    return 0
end

fn buf_reader_fill r
    if r == 0 or r.br_eof == 1 return 0 end
    n = syscall(0, r.br_fd, r.br_buf, r.br_cap, 0, 0, 0)
    if n <= 0
        r.br_pos = 0
        r.br_len = 0
        r.br_eof = 1
        return 0
    end
    r.br_pos = 0
    r.br_len = n
    return n
end

fn buf_reader_read r dst max_bytes
    if r == 0 or max_bytes <= 0 return 0 end
    total = 0
    while total < max_bytes
        if r.br_pos >= r.br_len
            got = buf_reader_fill(r)
            if got <= 0 break end
        end
        avail = r.br_len - r.br_pos
        need = max_bytes - total
        take = avail
        if need < take take = need end
        k = 0
        while k < take
            mem_byte_write(dst, total + k, mem_byte_read(r.br_buf, r.br_pos + k))
            k = k + 1
        end
        r.br_pos = r.br_pos + take
        total = total + take
    end
    return total
end

fn buf_reader_read_line r
    // WHY: Reads one full line using 8KB chunked SYS_read into ByteBuffer (O(N), zero per-char syscall!)
    if r == 0 return ":EOF:" end
    bb = buf_new(128)
    got_any = 0
    done = 0
    while done == 0
        if r.br_pos >= r.br_len
            n = buf_reader_fill(r)
            if n <= 0 break end
        end
        while r.br_pos < r.br_len
            b = mem_byte_read(r.br_buf, r.br_pos)
            r.br_pos = r.br_pos + 1
            got_any = 1
            if b == 10
                done = 1
                break
            elif b != 13
                buf_write_byte(bb, b)
            end
        end
    end
    if got_any == 0
        buf_free(bb)
        return ":EOF:"
    end
    out = buf_to_str(bb)
    buf_free(bb)
    return out
end

struct BufWriter
    bw_fd
    bw_buf
    bw_cap
    bw_len
end

fn buf_writer_new fd cap
    c = cap
    if c < 256 c = 8192 end
    b = malloc(c)
    return BufWriter(fd, b, c, 0)
end

fn buf_writer_flush w
    if w == 0 or w.bw_len <= 0 return 0 end
    written = 0
    while written < w.bw_len
        n = syscall(1, w.bw_fd, w.bw_buf + written, w.bw_len - written, 0, 0, 0)
        if n == 0 - 4 continue end
        if n <= 0 break end
        written = written + n
    end
    w.bw_len = 0
    return written
end

fn buf_writer_write w data
    if w == 0 return 0 end
    n = len(data)
    if n == 0 return 0 end
    if n >= w.bw_cap
        buf_writer_flush(w)
        return syscall(1, w.bw_fd, data, n, 0, 0, 0)
    end
    if w.bw_len + n > w.bw_cap
        buf_writer_flush(w)
    end
    k = 0
    while k < n
        mem_byte_write(w.bw_buf, w.bw_len + k, mem_byte_read(data, k))
        k = k + 1
    end
    w.bw_len = w.bw_len + n
    return n
end

fn buf_writer_free w
    if w != 0
        buf_writer_flush(w)
        if w.bw_buf != 0
            free(w.bw_buf, w.bw_cap)
            w.bw_buf = 0
        end
    end
    return 0
end

global g_stdin_buf_reader = 0

fn read_line prompt
    // WHY: High-throughput O(N) 8KB-buffered stdin reader (1 SYS_read per 8KB instead of 1 per byte!).
    // Preserves exact line boundaries across multiple read_line() calls and returns ":EOF:" on empty EOF.
    if prompt != ""
        print_raw(prompt)
    end
    if g_stdin_buf_reader == 0
        g_stdin_buf_reader = buf_reader_new(0, 8192)
    end
    return buf_reader_read_line(g_stdin_buf_reader)

fn রিড_লাইন prompt
    return read_line(prompt)

// ── ২. লিনাক্স কার্নেল ফাইল অপারেশন (Direct Linux AMD64 Kernel Syscalls) ────────
// WHY: SYS_open (2), SYS_close (3), SYS_read (0), SYS_write (1), SYS_lseek (8) সরাসরি আহ্বান।
fn file_open path flags
    return syscall(2, path, flags, 420, 0, 0, 0)

fn ফাইল_খোলো path
    return syscall(2, path, 0, 0, 0, 0, 0)

fn ফাইল_তৈরি path
    return syscall(2, path, 577, 420, 0, 0, 0)

fn ফাইল_খোলো_যুক্ত path
    return syscall(2, path, 1089, 420, 0, 0, 0)

fn file_close fd
    return syscall(3, fd, 0, 0, 0, 0, 0)

fn ফাইল_বন্ধ fd
    return syscall(3, fd, 0, 0, 0, 0, 0)

fn file_read_fd fd buffer size
    return syscall(0, fd, buffer, size, 0, 0, 0)

fn ফাইল_পড়ো fd buffer size
    return syscall(0, fd, buffer, size, 0, 0, 0)

fn file_write_fd fd data size
    return syscall(1, fd, data, size, 0, 0, 0)

fn ফাইল_লেখো fd data size
    return syscall(1, fd, data, size, 0, 0, 0)

fn file_seek fd offset whence
    return syscall(8, fd, offset, whence, 0, 0, 0)

fn ফাইল_সিক fd offset whence
    return syscall(8, fd, offset, whence, 0, 0, 0)

fn file_sync fd
    return syscall(74, fd, 0, 0, 0, 0, 0)

fn ফাইল_সিঙ্ক fd
    return syscall(74, fd, 0, 0, 0, 0, 0)

fn print_row label value
    say label + ": " + value

fn সারি_প্রিন্ট label value
    say label + ": " + value

// ── ৩. উচ্চ-স্তরের ফাইল ইউটিলিটি (High-Level File Operations) ────────────────────
// WHY: এক কলেই পুরো ফাইল পড়া ও লেখার জন্য কম্পাইলার ইন্ট্রিনসিক কল।
fn read_file path
    return file_read(path)

fn write_file path content
    return file_write(path, content)

fn file_append path content
    // WHY: Appends content to a file via direct Linux kernel syscalls with partial-write & EINTR (-4) retry loop.
    // Flags: O_WRONLY | O_CREAT | O_APPEND = 1 | 64 | 1024 = 1089, mode = 0644 (420)
    fd = syscall(2, path, 1089, 420, 0, 0, 0)
    if fd < 0
        return 0
    end
    clen = len(content)
    written = 0
    ok = 1
    while written < clen
        n = syscall(1, fd, content + written, clen - written, 0, 0, 0)
        if n == 0 - 4
            continue
        end
        if n <= 0
            ok = 0
            break
        end
        written = written + n
    end
    syscall(3, fd, 0, 0, 0, 0, 0)
    return ok

fn append_file path content
    return file_append(path, content)

fn path_exists path
    return file_exists(path)

fn ফাইল_বিদ্যমান path
    return file_exists(path)
