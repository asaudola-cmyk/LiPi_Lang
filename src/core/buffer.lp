// ==============================================================================
// 👑 LIPI FIRST 1.0.0 FREESTANDING CORE SILICON PRIMITIVES: BUFFER (src/core/buffer.lp)
// ⚡ 100% Pure Lipi Sovereign Implementation | Zero C | Zero Libc | Zero Dependencies
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Machine code generation (ELF emitters, Mach-O loaders, WASM bytecode, DWARF tables)
//    emits variable-length instruction streams, relocations, and string tables whose
//    exact final size cannot be known ahead of time.
// 2. Fixed-size buffers risk catastrophic memory corruption, while linked node chains
//    suffer from massive cache miss rates and pointer overhead.
// 3. This module implements a contiguous, self-growing byte buffer with amortized O(1)
//    append times, power-of-two capacity geometric growth, hardware alignment padding,
//    and built-in LEB128 (DWARF/WASM) and Little/Big Endian serializers.
// ==============================================================================

struct ByteBuffer
    buf_data
    buf_len
    buf_capacity

// ── 1. Buffer Lifecycle Management ────────────────────────────────────────────

// WHY: Allocates a new byte buffer backed by raw virtual memory.
//      Guarantees at least 16 bytes initial capacity to avoid micro-reallocations.
fn buffer_new(initial_cap)
    buf = ByteBuffer()
    cap = initial_cap
    if cap < 16
        cap = 16
    buf.buf_data = alloc(cap)
    buf.buf_len = 0
    buf.buf_capacity = cap
    return buf

// WHY: Releases underlying memory back to the sovereign kernel allocator.
fn buffer_free(buf)
    if buf == 0 return 0
    if buf.buf_data != 0 and buf.buf_capacity > 0
        free(buf.buf_data, buf.buf_capacity)
        buf.buf_data = 0
        buf.buf_capacity = 0
        buf.buf_len = 0
    return 1

// WHY: Reusable buffer pattern: resets write offset to 0 without deallocating memory,
//      enabling 0-overhead reuse across compiler passes.
fn buffer_clear(buf)
    if buf == 0 return 0
    buf.buf_len = 0
    return 1

// ── 2. Capacity & Growth Policy ───────────────────────────────────────────────

// WHY: Amortized O(1) capacity growth using standard 2x geometric progression.
//      If capacity is exceeded, doubles the buffer and copies bytes with zero external C calls.
fn buffer_ensure_capacity(buf, additional_bytes)
    if buf == 0 return 0
    if additional_bytes <= 0 return 1

    req_cap = buf.buf_len + additional_bytes
    if req_cap <= buf.buf_capacity
        return 1

    new_cap = buf.buf_capacity * 2
    if new_cap < req_cap
        new_cap = req_cap + 64

    new_data = alloc(new_cap)
    if new_data == 0
        return 0 // Memory allocation failure

    // Copy existing bytes into newly allocated memory block
    i = 0
    cur_len = buf.buf_len
    old_data = buf.buf_data
    while i < cur_len
        b = mem_byte_read(old_data, i)
        mem_byte_write(new_data, i, b)
        i = i + 1

    // Free previous memory block
    if old_data != 0 and buf.buf_capacity > 0
        free(old_data, buf.buf_capacity)

    buf.buf_data = new_data
    buf.buf_capacity = new_cap
    return 1

// ── 3. Single-Byte Operations ─────────────────────────────────────────────────

// WHY: Appends a single 8-bit unsigned byte to the buffer.
fn buffer_write_u8(buf, val)
    if buf == 0 return 0
    buffer_ensure_capacity(buf, 1)
    mem_byte_write(buf.buf_data, buf.buf_len, val & 255)
    buf.buf_len = buf.buf_len + 1
    return 1

// WHY: Appends a single 8-bit signed byte to the buffer.
fn buffer_write_i8(buf, val)
    return buffer_write_u8(buf, val)

// WHY: Reads a byte at `offset` with strict bounds protection.
fn buffer_read_u8(buf, offset)
    if buf == 0 or buf.buf_data == 0 return 0
    if offset < 0 or offset >= buf.buf_len return 0
    return mem_byte_read(buf.buf_data, offset)

// WHY: In-place byte patch (e.g. patching jump displacement offsets in binary codegen).
fn buffer_set_u8(buf, offset, val)
    if buf == 0 or buf.buf_data == 0 return 0
    if offset < 0 or offset >= buf.buf_len return 0
    mem_byte_write(buf.buf_data, offset, val & 255)
    return 1

// ── 4. Fixed-Width Endian Serializers ──────────────────────────────────────────

// WHY: Emits 16-bit integer in Little-Endian byte order.
fn buffer_write_u16_le(buf, val)
    buffer_write_u8(buf, val & 255)
    buffer_write_u8(buf, (val >> 8) & 255)
    return 2

// WHY: Emits 16-bit integer in Big-Endian (Network) byte order.
fn buffer_write_u16_be(buf, val)
    buffer_write_u8(buf, (val >> 8) & 255)
    buffer_write_u8(buf, val & 255)
    return 2

// WHY: Emits 32-bit integer in Little-Endian byte order (standard x86/ARM opcode fields).
fn buffer_write_u32_le(buf, val)
    buffer_write_u8(buf, val & 255)
    buffer_write_u8(buf, (val >> 8) & 255)
    buffer_write_u8(buf, (val >> 16) & 255)
    buffer_write_u8(buf, (val >> 24) & 255)
    return 4

// WHY: Emits 32-bit integer in Big-Endian byte order.
fn buffer_write_u32_be(buf, val)
    buffer_write_u8(buf, (val >> 24) & 255)
    buffer_write_u8(buf, (val >> 16) & 255)
    buffer_write_u8(buf, (val >> 8) & 255)
    buffer_write_u8(buf, val & 255)
    return 4

// WHY: Emits 64-bit integer in Little-Endian byte order (AMD64 64-bit address / pointer).
fn buffer_write_u64_le(buf, val)
    buffer_write_u8(buf, val & 255)
    buffer_write_u8(buf, (val >> 8) & 255)
    buffer_write_u8(buf, (val >> 16) & 255)
    buffer_write_u8(buf, (val >> 24) & 255)
    buffer_write_u8(buf, (val >> 32) & 255)
    buffer_write_u8(buf, (val >> 40) & 255)
    buffer_write_u8(buf, (val >> 48) & 255)
    buffer_write_u8(buf, (val >> 56) & 255)
    return 8

// WHY: Emits 64-bit integer in Big-Endian byte order.
fn buffer_write_u64_be(buf, val)
    buffer_write_u8(buf, (val >> 56) & 255)
    buffer_write_u8(buf, (val >> 48) & 255)
    buffer_write_u8(buf, (val >> 40) & 255)
    buffer_write_u8(buf, (val >> 32) & 255)
    buffer_write_u8(buf, (val >> 24) & 255)
    buffer_write_u8(buf, (val >> 16) & 255)
    buffer_write_u8(buf, (val >> 8) & 255)
    buffer_write_u8(buf, val & 255)
    return 8

// ── 5. Bulk Memory & String Writing ───────────────────────────────────────────

// WHY: Appends an arbitrary contiguous byte block from physical memory into buffer.
fn buffer_write_bytes(buf, src_ptr, count)
    if buf == 0 or src_ptr == 0 or count <= 0 return 0
    buffer_ensure_capacity(buf, count)
    dst_ptr = buf.buf_data
    base = buf.buf_len
    i = 0
    while i < count
        b = mem_byte_read(src_ptr, i)
        mem_byte_write(dst_ptr, base + i, b)
        i = i + 1
    buf.buf_len = buf.buf_len + count
    return count

// WHY: Emits raw ASCII/UTF-8 string bytes into binary output without null terminator.
fn buffer_write_string(buf, s)
    if buf == 0 or s == 0 return 0
    slen = len(s)
    if slen <= 0 return 0
    buffer_ensure_capacity(buf, slen)
    dst_ptr = buf.buf_data
    base = buf.buf_len
    i = 0
    while i < slen
        c = ord(char_at(s, i))
        mem_byte_write(dst_ptr, base + i, c)
        i = i + 1
    buf.buf_len = buf.buf_len + slen
    return slen

// ── 6. LEB128 Variable-Length Encoding (DWARF & WASM Standards) ──────────────

// WHY: Unsigned LEB128 (Little-Endian Base 128) packs integers into 1 to 10 bytes,
//      storing 7 bits per byte with high bit (0x80) signaling continuation.
//      Standard in WebAssembly bytecode and DWARF debug sections (.debug_line, .debug_info).
fn buffer_write_uleb128(buf, val)
    if buf == 0 return 0
    v = val
    written = 0
    more = 1
    while more == 1
        b = v & 127
        v = v >> 7
        if v == 0
            more = 0
            buffer_write_u8(buf, b)
        else
            buffer_write_u8(buf, b | 128)
        written = written + 1
    return written

// WHY: Signed LEB128 encodes two's-complement integers into variable-length bytes.
//      Terminates when remaining bits match sign extension of the 7th bit.
fn buffer_write_sleb128(buf, val)
    if buf == 0 return 0
    v = val
    written = 0
    more = 1
    while more == 1
        b = v & 127
        v = v >> 7
        sign_bit = (b >> 6) & 1
        if (v == 0 and sign_bit == 0) or (v == (0 - 1) and sign_bit == 1)
            more = 0
            buffer_write_u8(buf, b)
        else
            buffer_write_u8(buf, b | 128)
        written = written + 1
    return written

// ── 7. Hardware Cacheline & Memory Alignment Padding ──────────────────────────

// WHY: Padds buffer with zero bytes until its length is a multiple of `align`.
//      Mandatory for ELF section alignment (e.g. 16, 64 bytes) and CPU instruction caching.
fn buffer_align_to(buf, align)
    if buf == 0 or align <= 1 return 0
    rem = buf.buf_len % align
    if rem == 0 return 0
    padding = align - rem
    i = 0
    while i < padding
        buffer_write_u8(buf, 0)
        i = i + 1
    return padding

// ── 8. Buffer Introspection ───────────────────────────────────────────────────

fn buffer_len(buf)
    if buf == 0 return 0
    return buf.buf_len

fn buffer_capacity(buf)
    if buf == 0 return 0
    return buf.buf_capacity

fn buffer_data(buf)
    if buf == 0 return 0
    return buf.buf_data
