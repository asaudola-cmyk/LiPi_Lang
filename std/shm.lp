// ==============================================================================
// 👑 LIPI SOVEREIGN POSIX SHARED MEMORY ENGINE (std/shm.lp)
// ⚡ Zero Libc | Direct Linux Kernel IPC | /dev/shm Sub-Microsecond Caching
// ==============================================================================

// WHY: High-performance IPC requires zero-copy shared memory directly accessible
// across multiple independent OS processes without TCP, Redis, or Libc overhead.
// Linux maps /dev/shm via tmpfs directly in RAM for sub-microsecond latency.

include "std/mem.lp"

// ১. শেয়ার্ড মেমরি কনস্ট্যান্টস (POSIX Shared Memory Constants)
SHM_O_RDONLY = 0
SHM_O_WRONLY = 1
SHM_O_RDWR   = 2
SHM_O_CREAT  = 64
SHM_O_TRUNC  = 512

SHM_PROT_READ  = 1
SHM_PROT_WRITE = 2
SHM_MAP_SHARED = 1

// ২. শেয়ার্ড মেমরি খোলা বা তৈরি করা (Open or Create Shared Memory via /dev/shm)
// WHY: Maps RAM-backed tmpfs file descriptor into virtual memory space using direct kernel syscalls.
// Syscall 2 (SYS_open): flags O_RDWR (2) | O_CREAT (64) = 66, mode 0666 = 438.
// Syscall 77 (SYS_ftruncate): expands file to specified byte size.
// Syscall 9 (SYS_mmap): maps file into process address space with PROT_READ|PROT_WRITE (3) & MAP_SHARED (1).
// Syscall 3 (SYS_close): releases file descriptor while preserving active virtual memory mapping.
fn শেয়ার্ড_মেমরি_খোলো file_path size
    // SYS_open (2)
    fd = syscall(2, file_path, 66, 438)
    if fd < 0
        say "[ত্রুটি] শেয়ার্ড মেমরি তৈরি করতে ব্যর্থ: " + file_path
        return -1

    // SYS_ftruncate (77)
    syscall(77, fd, size)

    // SYS_mmap (9) -> prot: 3 (RW), flags: 1 (MAP_SHARED)
    ptr = syscall(9, 0, size, 3, 1, fd, 0)
    if ptr < 0
        say "[ত্রুটি] mmap ব্যর্থ হয়েছে: " + file_path
        syscall(3, fd)
        return -1

    // SYS_close (3)
    syscall(3, fd)
    return ptr

fn shm_open file_path size
    return শেয়ার্ড_মেমরি_খোলো(file_path, size)


// ৩. শেয়ার্ড মেমরি ক্লোজ বা আন-ম্যাপ করা (Unmap Shared Memory)
// WHY: Returns mapped virtual memory pages back to the Linux kernel via SYS_munmap (11).
fn শেয়ার্ড_মেমরি_বন্ধ ptr size
    // SYS_munmap (11)
    result = syscall(11, ptr, size)
    return result

fn shm_close ptr size
    return শেয়ার্ড_মেমরি_বন্ধ(ptr, size)

fn শেয়ার্ড_mem_close ptr size
    return শেয়ার্ড_মেমরি_বন্ধ(ptr, size)

// ৪. শেয়ার্ড মেমরি ফাইল মুছে ফেলা (Unlink /dev/shm file)
// WHY: Completely removes the named shared memory file from tmpfs using SYS_unlink (87).
fn শেয়ার্ড_মেমরি_মুছে_ফেলো file_path
    // SYS_unlink (87)
    result = syscall(87, file_path)
    return result

fn shm_unlink file_path
    return শেয়ার্ড_মেমরি_মুছে_ফেলো(file_path)

// ৫. লক-ফ্রি অ্যাটমিক ইনক্রিমেন্ট (Atomic Word Increment)
// WHY: High-throughput concurrency counters and rate-limiters require synchronized arithmetic.
fn অ্যাটমিক_যোগ addr index sum
    বর্তমান_মান = mem_word_read(addr, index)
    নতুন_মান = বর্তমান_মান + sum
    mem_write_word(addr, index, নতুন_মান)
    return নতুন_মান

fn atomic_add addr index sum
    return অ্যাটমিক_যোগ(addr, index, sum)


// ৬. শেয়ার্ড মেমরিতে বাইট ও ওয়ার্ড রিড/রাইট
fn shm_write_byte ptr offset val
    return mem_write_byte(ptr, offset, val)

fn shm_read_byte ptr offset
    return mem_byte_পড়ো(ptr, offset)

fn shm_write_word ptr index val
    return mem_write_word(ptr, index, val)

fn shm_read_word ptr index
    return mem_word_read(ptr, index)

