// 📜 লিপি heap memory ও ডায়nameিa memory অ্যালোaশন লাইব্রেরি (Pure Lipi Memory & Allocator)
// 🏛️ direct লিনাa্স aার্নেল page অ্যালোaশন ও র পয়েন্টার ম্যানিpoolেশন (Linux AMD64 Kernel ABI)
// ০% Libc, ০% malloc() নির্ভরতা — direct SYS_mmap ও SYS_munmap aার্নেল syscall

// ১. aার্নেল heap memory allocation (Direct Heap Allocation via SYS_mmap: syscall 9)
// WHY: aার্নেলaে direct instruction দিয়ে ভার্চুয়াল address স্পেসে private অ্যানোনিমাস page allocation aরা।
// prot = PROT_READ (1) | PROT_WRITE (2) = 3
// flags = MAP_PRIVATE (2) | MAP_ANONYMOUS (32) = 34
// fd = -1, offset = 0
fn malloc size
    পয়েন্টার = syscall(9, 0, size, 3, 34, -1, 0)
    return পয়েন্টার

// ২. aার্নেল heap memory অবমুa্তি (Direct Heap Deallocation via SYS_munmap: syscall 11)
// WHY: বরাদ্দaৃত memory পেজগুলো লিনাa্স aার্নেলে successভাবে ফিরিয়ে দেওয়া।
fn free addr size
    result = syscall(11, addr, size)
    return result

// ৩. memory অনুলিপি বা aপি (Pure Native Memory Copy / memcpy)
// WHY: memর এa ব্লa থেaে other ব্লaে each byte direct transfer aরা।
fn mem_copy dest src len
    cursor = 0
    while cursor < len
        byte = mem_byte_পড়ো(src, cursor)
        mem_write_byte(dest, cursor, byte)
        cursor = cursor + 1
    return len

// ৪. memory ভরাট বা রিসেট (Pure Native Memory Set / memset)
// WHY: memর নির্দিষ্ট ব্লaaে এaটি নির্দিষ্ট byte value দ্বারা full aরা (যেমন buffer জিরো aরা)।
fn mem_fill addr value len
    cursor = 0
    while cursor < len
        mem_write_byte(addr, cursor, value)
        cursor = cursor + 1
    return len

// ৫. ৬৪-বিট word memতে সংরa্ষণ (Write 64-bit QWORD at index)
// WHY: array ও স্ট্রাaচারের indexa্সড ডাটা fast সংরa্ষণ aরা।
fn mem_write_word addr index value
    offset = index * 8
    mem_write(addr, offset, value)
    return value

// ৬. ৬৪-বিট word memory থেaে reading (Read 64-bit QWORD from index)
// WHY: array বা স্ট্রাaচারের indexa্সড ডাটা direct load aরা।
fn mem_শব্দ_পড়ো addr index
    offset = index * 8
    value = mem_পড়ো(addr, offset)
    return value
