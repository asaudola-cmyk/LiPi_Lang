// ==============================================================================
// 👑 LIPI CORE SYSTEM MEMORY: SOVEREIGN ALLOCATOR & MEMORY OPS (universe/core/memory.lp)
// ⚡ 100% Native Linux Kernel AMD64 ABI | SYS_mmap (9) & SYS_munmap (11) | Zero Libc
// ==============================================================================

// WHY: A sovereign systems language requires direct, kernel-level memory management
// with zero reliance on external C runtimes, malloc/free implementations, or libc.
// This module provides page-aligned virtual memory allocation, zeroing, copying,
// indexed word manipulation, and bilingual Bengali/English standard library APIs.

// ── ১. কার্নেল হিপ মেমরি বরাদ্দ (Direct Heap Allocation via SYS_mmap: syscall 9) ──
// WHY: কার্নেলকে সরাসরি নির্দেশ দিয়ে ভার্চুয়াল অ্যাড্রেস স্পেসে প্রাইভেট অ্যানোনিমাস পেজ বরাদ্দ করা।
// prot = PROT_READ (1) | PROT_WRITE (2) = 3
// flags = MAP_PRIVATE (2) | MAP_ANONYMOUS (32) = 34
// fd = -1, offset = 0
fn malloc size
    পয়েন্টার = syscall(9, 0, size, 3, 34, -1, 0)
    return পয়েন্টার

fn মেমরি_বরাদ্দ size
    return malloc(size)

fn mem_alloc size
    return malloc(size)

// ── ২. কার্নেল হিপ মেমরি অবমুক্তি (Direct Heap Deallocation via SYS_munmap: syscall 11) ──
// WHY: বরাদ্দকৃত মেমরি পেজগুলো লিনাক্স কার্নেলে সফলভাবে ফিরিয়ে দেওয়া।
fn free addr size
    result = syscall(11, addr, size, 0, 0, 0, 0)
    return result

fn মেমরি_মুক্তি addr size
    return free(addr, size)

fn mem_free addr size
    return free(addr, size)

// ── ৩. মেমরি অনুলিপি বা কপি (Pure Native Memory Copy / memcpy) ───────────────────
// WHY: মেমরির এক ব্লক থেকে অন্য ব্লকে প্রতিটি বাইট সরাসরি ট্রান্সফার করা।
fn mem_copy dest src len
    cursor = 0
    while cursor < len
        byte = mem_byte_পড়ো(src, cursor)
        মেমরি_বাইট_লেখো(dest, cursor, byte)
        cursor = cursor + 1
    return len

fn মেমরি_কপি dest src len
    return mem_copy(dest, src, len)

// ── ৪. মেমরি ভরাট বা রিসেট (Pure Native Memory Set / memset) ─────────────────────
// WHY: মেমরির নির্দিষ্ট ব্লককে একটি নির্দিষ্ট বাইট ভ্যালু দ্বারা পূর্ণ করা (যেমন বাফার জিরো করা)।
fn mem_fill addr value len
    cursor = 0
    while cursor < len
        মেমরি_বাইট_লেখো(addr, cursor, value)
        cursor = cursor + 1
    return len

fn মেমরি_ভরাট addr value len
    return mem_fill(addr, value, len)

fn mem_zero addr len
    return mem_fill(addr, 0, len)

fn মেমরি_শূন্য addr len
    return mem_fill(addr, 0, len)

// ── ৫. ৬৪-বিট মেমরি রিড ও রাইট (64-bit Memory Read/Write via byte offset) ─────────
// WHY: সিপিইউ মেমরির নির্দিষ্ট বাইট অফসেট থেকে ৬৪-বিট পূর্ণসংখ্যা পড়া ও লেখা।
fn mem_read addr offset
    return মেমরি_পড়ো(addr, offset)

fn mem_write addr offset value
    মেমরি_লেখো(addr, offset, value)
    return value

// ── ৬. ৮-বিট বাইট মেমরি রিড ও রাইট (8-bit Byte Memory Read/Write) ────────────────
// WHY: বাফার ও স্ট্রিং অপারেশনের জন্য একক বাইট রিড এবং রাইট নিশ্চিত করা।
fn mem_read_byte addr offset
    return mem_byte_পড়ো(addr, offset)

fn mem_byte_read addr offset
    return mem_byte_পড়ো(addr, offset)

fn mem_write_byte addr offset value
    মেমরি_বাইট_লেখো(addr, offset, value)
    return value

fn mem_byte_write addr offset value
    মেমরি_বাইট_লেখো(addr, offset, value)
    return value

// ── ৭. সূচক ভিত্তিক মেমরি এক্সেস (Index-based Memory Access: index * 8 bytes) ──────
// WHY: অ্যারে ও স্ট্রাকচারের ইনডেক্সড ডাটা (০, ১, ২...) দ্রুত রিড ও রাইট করা।
fn mem_write_idx addr index value
    offset = index * 8
    মেমরি_লেখো(addr, offset, value)
    return value

fn মেমরি_সূচক_লেখো addr index value
    return mem_write_idx(addr, index, value)

fn mem_read_idx addr index
    offset = index * 8
    return মেমরি_পড়ো(addr, offset)

fn মেমরি_সূচক_পড়ো addr index
    return mem_read_idx(addr, index)

fn mem_read_u32 addr index
    return mem_read_idx(addr, index)

fn mem_write_u32 addr index value
    return mem_write_idx(addr, index, value)
