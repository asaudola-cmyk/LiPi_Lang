// 📜 লিপি হিপ মেমরি ও ডায়নামিক মেমরি অ্যালোকেশন লাইব্রেরি (Pure Lipi Memory & Allocator)
// 🏛️ সরাসরি লিনাক্স কার্নেল পেজ অ্যালোকেশন ও র পয়েন্টার ম্যানিপুলেশন (Linux AMD64 Kernel ABI)
// ০% Libc, ০% malloc() নির্ভরতা — সরাসরি SYS_mmap ও SYS_munmap কার্নেল সিসকল

// ১. কার্নেল হিপ মেমরি বরাদ্দ (Direct Heap Allocation via SYS_mmap: syscall 9)
// WHY: কার্নেলকে সরাসরি নির্দেশ দিয়ে ভার্চুয়াল অ্যাড্রেস স্পেসে প্রাইভেট অ্যানোনিমাস পেজ বরাদ্দ করা।
// prot = PROT_READ (1) | PROT_WRITE (2) = 3
// flags = MAP_PRIVATE (2) | MAP_ANONYMOUS (32) = 34
// fd = -1, offset = 0
fn malloc size
    পয়েন্টার = syscall(9, 0, size, 3, 34, -1, 0)
    return পয়েন্টার

fn মেমরি_বরাদ্দ size
    return malloc(size)

// ২. কার্নেল হিপ মেমরি অবমুক্তি (Direct Heap Deallocation via SYS_munmap: syscall 11)
// WHY: বরাদ্দকৃত মেমরি পেজগুলো লিনাক্স কার্নেলে সফলভাবে ফিরিয়ে দেওয়া।
fn free addr size
    result = syscall(11, addr, size, 0, 0, 0, 0)
    return result

fn মেমরি_মুক্তি addr size
    return free(addr, size)

// ৩. মেমরি অনুলিপি বা কপি (Pure Native Memory Copy / memcpy)
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

// ৪. মেমরি ভরাট বা রিসেট (Pure Native Memory Set / memset)
// WHY: মেমরির নির্দিষ্ট ব্লককে একটি নির্দিষ্ট বাইট ভ্যালু দ্বারা পূর্ণ করা (যেমন বাফার জিরো করা)।
fn mem_fill addr value len
    cursor = 0
    while cursor < len
        মেমরি_বাইট_লেখো(addr, cursor, value)
        cursor = cursor + 1
    return len

fn মেমরি_ভরাট addr value len
    return mem_fill(addr, value, len)

// ৫. ৬৪-বিট মেমরি রিড ও রাইট (64-bit Memory Read/Write via byte offset)
// WHY: সিপিইউ মেমরির নির্দিষ্ট বাইট অফসেট থেকে ৬৪-বিট পূর্ণসংখ্যা পড়া ও লেখা।
fn mem_read addr offset
    return মেমরি_পড়ো(addr, offset)

fn mem_write addr offset value
    মেমরি_লেখো(addr, offset, value)
    return value

// ৬. সূচক ভিত্তিক মেমরি এক্সেস (Index-based Memory Access: index * 8 bytes)
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

// ৭. মেমরি বরাদ্দ ও অবমুক্তির সার্বভৌমিক এলিয়াস (Universal Allocation Aliases)
fn mem_alloc size
    return malloc(size)

fn mem_free addr size
    return free(addr, size)
