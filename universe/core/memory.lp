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

fn mem_read_u32 addr offset
    b0 = mem_read_byte(addr, offset)
    b1 = mem_read_byte(addr, offset + 1)
    b2 = mem_read_byte(addr, offset + 2)
    b3 = mem_read_byte(addr, offset + 3)
    return b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)

fn mem_write_u32 addr offset value
    mem_write_byte(addr, offset, value % 256)
    mem_write_byte(addr, offset + 1, (value / 256) % 256)
    mem_write_byte(addr, offset + 2, (value / 65536) % 256)
    mem_write_byte(addr, offset + 3, (value / 16777216) % 256)
    return value

fn mem_read_u64 addr offset
    return mem_read(addr, offset)

fn mem_write_u64 addr offset value
    return mem_write(addr, offset, value)

// ── ৮. সভেরিন সেগ্রিগেটেড স্ল্যাব অ্যালোকেটর (Segregated Slab Allocator) ────────
// WHY: ছোট ছোট মেমরি বরাদ্দ (16B থেকে 2048B) সরাসরি কার্নেল সিসকল ছাড়া O(1) LIFO
// ফ্রি-লিস্টে তাৎক্ষণিক রিসাইক্লিং করে মেমরি ফ্র্যাগমেন্টেশন ও কার্নেল ট্রানজিশন দূর করা।
// এটি ভারী Tracing GC ছাড়াই সিস্টেমকে ১০০% জিরো-পজ (Zero-Pause) ও আল্ট্রা-ফাস্ট রাখে।

fn get_slab_buckets
    return slab_buckets_ptr()

fn slab_get_class_index size
    if size <= 16
        return 0
    if size <= 32
        return 1
    if size <= 64
        return 2
    if size <= 128
        return 3
    if size <= 256
        return 4
    if size <= 512
        return 5
    if size <= 1024
        return 6
    if size <= 2048
        return 7
    return -1

fn slab_get_slot_size class_idx
    if class_idx == 0
        return 16
    if class_idx == 1
        return 32
    if class_idx == 2
        return 64
    if class_idx == 3
        return 128
    if class_idx == 4
        return 256
    if class_idx == 5
        return 512
    if class_idx == 6
        return 1024
    if class_idx == 7
        return 2048
    return 0

fn slab_alloc req_size
    if req_size <= 0
        return 0
    if req_size > 2048
        return malloc(req_size)

    b_addr = get_slab_buckets()
    c_idx = slab_get_class_index(req_size)
    slot_size = slab_get_slot_size(c_idx)

    head = mem_read_idx(b_addr, c_idx)
    if head > 0
        // O(1) Pop from freelist
        next_free = mem_read(head, 0)
        mem_write_idx(b_addr, c_idx, next_free)
        // Zero slot payload for memory safety
        mem_zero(head, slot_size)
        return head

    // Freelist empty: Allocate a fresh 64KB slab
    slab_capacity = 65536
    slab_page = malloc(slab_capacity)
    if slab_page <= 0
        return 0

    // Carve slab into slots and build LIFO freelist
    total_slots = slab_capacity / slot_size
    // First slot is allocated to caller
    ret_ptr = slab_page

    // Link remaining slots into freelist
    if total_slots > 1
        first_free = slab_page + slot_size
        mem_write_idx(b_addr, c_idx, first_free)

        curr_slot = first_free
        si = 2
        while si < total_slots
            next_slot = slab_page + (si * slot_size)
            mem_write(curr_slot, 0, next_slot)
            curr_slot = next_slot
            si = si + 1
        // Last slot points to 0 (end of freelist)
        mem_write(curr_slot, 0, 0)

    mem_zero(ret_ptr, slot_size)
    return ret_ptr

fn স্ল্যাব_বরাদ্দ req_size
    return slab_alloc(req_size)

fn slab_free addr req_size
    if addr <= 0
        return 0
    if req_size > 2048
        return free(addr, req_size)

    b_addr = get_slab_buckets()
    c_idx = slab_get_class_index(req_size)
    if c_idx < 0
        return 0

    // O(1) Push to freelist
    curr_head = mem_read_idx(b_addr, c_idx)
    mem_write(addr, 0, curr_head)
    mem_write_idx(b_addr, c_idx, addr)
    return 0

fn স্ল্যাব_মুক্তি addr req_size
    return slab_free(addr, req_size)

// ── ৯. কমপ্যাক্ট ৮-বাইট হার্ডওয়্যার অবজেক্ট হেডার প্রোটোকল (Hardware Object Header) ─
// WHY: মেমরি ট্র্যাকিংয়ের জন্য কোনো পাইথন-স্টাইল O(n) ডিকশনারি বা হ্যাশম্যাপ না রেখে
// সরাসরি মেমরি ব্লকের পূর্বে ৮-বাইটের ফিক্সড হার্ডওয়্যার হেডার সংরক্ষণ করা:
//   Offset -8: [ Size: 32-bit uint ]
//   Offset -4: [ Type: 8-bit uint  ] (0=Raw, 1=String, 2=Array, 3=Struct, 4=Closure)
//   Offset -3: [ Color: 8-bit uint ] (0=White, 1=Grey, 2=Black)
//   Offset -2: [ Flags: 16-bit uint] (Bit0=Alloc, Bit1=Pinned, Bit2=HasPtrs)
//   Offset  0: [ User Payload Data... ]
// এটি O(1) টাইমে ১টি মেমরি অপারেশনে অবজেক্টের মেটাডাটা প্রদান করে।

OBJ_TYPE_RAW     = 0
OBJ_TYPE_STR     = 1
OBJ_TYPE_ARRAY   = 2
OBJ_TYPE_STRUCT  = 3
OBJ_TYPE_CLOSURE = 4

OBJ_FLAG_ALLOC    = 1
OBJ_FLAG_PINNED   = 2
OBJ_FLAG_HAS_PTRS = 4

OBJ_COLOR_WHITE  = 0
OBJ_COLOR_GREY   = 1
OBJ_COLOR_BLACK  = 2

fn obj_header_init payload_ptr size type_id flags
    if payload_ptr <= 8
        return 0
    hdr_base = payload_ptr - 8
    // Write 32-bit size (4 bytes: offset 0..3)
    mem_write_u32(hdr_base, 0, size)
    // Write 8-bit type (offset 4)
    mem_write_byte(hdr_base, 4, type_id % 256)
    // Write 8-bit color (offset 5, default white = 0)
    mem_write_byte(hdr_base, 5, 0)
    // Write 16-bit flags (offset 6..7)
    mem_write_byte(hdr_base, 6, flags % 256)
    mem_write_byte(hdr_base, 7, (flags / 256) % 256)
    return payload_ptr

fn অবজেক্ট_হেডার_তৈরি পয়েন্টার সাইজ টাইপ ফ্ল্যাগ
    return obj_header_init(পয়েন্টার, সাইজ, টাইপ, ফ্ল্যাগ)

fn obj_get_size payload_ptr
    if payload_ptr <= 8 return 0
    return mem_read_u32(payload_ptr - 8, 0)

fn অবজেক্ট_সাইজ পয়েন্টার
    return obj_get_size(পয়েন্টার)

fn obj_get_type payload_ptr
    if payload_ptr <= 8 return 0
    return mem_read_byte(payload_ptr - 8, 4)

fn অবজেক্ট_টাইপ পয়েন্টার
    return obj_get_type(পয়েন্টার)

fn obj_get_color payload_ptr
    if payload_ptr <= 8 return 0
    return mem_read_byte(payload_ptr - 8, 5)

fn অবজেক্ট_রং পয়েন্টার
    return obj_get_color(পয়েন্টার)

fn obj_set_color payload_ptr color
    if payload_ptr <= 8 return 0
    mem_write_byte(payload_ptr - 8, 5, color % 256)
    return color

fn অবজেক্ট_রং_নির্ধারণ পয়েন্টার রং
    return obj_set_color(পয়েন্টার, রং)

fn obj_get_flags payload_ptr
    if payload_ptr <= 8 return 0
    hdr_base = payload_ptr - 8
    f0 = mem_read_byte(hdr_base, 6)
    f1 = mem_read_byte(hdr_base, 7)
    return f0 + (f1 * 256)

fn অবজেক্ট_ফ্ল্যাগ পয়েন্টার
    return obj_get_flags(পয়েন্টার)

fn obj_has_ptrs payload_ptr
    flags = obj_get_flags(payload_ptr)
    return (flags % 8) / 4


