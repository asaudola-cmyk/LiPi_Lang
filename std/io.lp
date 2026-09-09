// std/io.lp — Lipi 2.0 Standard I/O Library
// Global Standard | Low-level I/O via syscalls

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

// Read a line (simulated \u2014 runtime handles)
fn read_line prompt
    say prompt
    return ""  // Runtime provides input

// File operations (syscall-based)
fn file_open path flags
    // Returns fd via syscall
    return syscall 2 path flags 0

fn file_close fd
    return syscall 3 fd 0 0

fn file_read fd buffer size
    return syscall 0 fd buffer size

fn file_write fd data size
    return syscall 1 fd data size

fn file_seek fd offset whence
    return syscall 8 fd offset whence

// Print a horizontal rule
fn print_rule width char
    say str_repeat char width

// Print a table row
fn print_row label value
    say label + ": " + value
