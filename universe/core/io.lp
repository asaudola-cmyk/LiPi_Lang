// ==============================================================================
// 👑 LIPI CORE I/O ENGINE: SOVEREIGN DIRECT KERNEL SYSCALL I/O (universe/core/io.lp)
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
fn write_out msg
    say msg

fn write_err msg
    say "[ERR] " + msg

fn println msg
    say msg

fn print_inline msg
    say msg

fn read_line prompt
    say prompt
    return ""

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

fn append_file path content
    return file_append(path, content)

fn path_exists path
    return file_exists(path)

fn ফাইল_বিদ্যমান path
    return file_exists(path)
