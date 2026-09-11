// std/io.lp — Lipi 2.0 Standard I/O Library
// Global Standard | Low-level I/O via direct Linux kernel syscalls (0% Libc)

// File descriptor constants
STDIN  = 0
STDOUT = 1
STDERR = 2

// Open flags
O_RDONLY = 0
O_WRONLY = 1
O_RDWR   = 2
O_CREAT  = 64
O_TRUNC  = 512

// Write string to stdout
fn write_out msg
    say msg

// Write string to stderr
fn write_err msg
    say "[ERR] " + msg

// Write line to stdout
fn println msg
    say msg

// Print with no newline (simulated)
fn print_inline msg
    say msg

// Read a line (simulated — runtime handles)
fn read_line prompt
    say prompt
    return ""

// File operations (syscall-based Linux AMD64)
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

// Print a table row
fn print_row label value
    say label + ": " + value
