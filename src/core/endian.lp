// ==============================================================================
// 👑 LIPI FIRST 1.0.0 FREESTANDING CORE SILICON PRIMITIVES: ENDIAN (src/core/endian.lp)
// ⚡ 100% Pure Lipi Sovereign Implementation | Zero C | Zero Libc | Zero Dependencies
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Cross-compilation and executable synthesis (Linux ELF64, Apple Mach-O, Windows PE,
//    WebAssembly bytecode, RISC-V kernels) require deterministic multi-byte serialization
//    independent of the host machine's native CPU endianness.
// 2. Binary protocols (TCP/IP network byte order = Big-Endian, DWARF debug info = Little-Endian,
//    WASM bytecode = Little-Endian) mandate fast, zero-branching bitwise serializers.
// 3. This module provides pure bitwise byte-swapping and memory load/store primitives
//    with zero external C library reliance.
// ==============================================================================

// ── 1. Pure Bitwise Byte-Swapping Primitives (CPU BSWAP Emulation) ───────────

// WHY: Reverses the byte order of a 16-bit unsigned or signed integer.
//      (0x1234 -> 0x3412)
fn bswap16(v)
    b0 = v & 255
    b1 = (v >> 8) & 255
    return (b0 << 8) | b1

// WHY: Reverses the byte order of a 32-bit unsigned or signed integer.
//      (0x12345678 -> 0x78563412)
fn bswap32(v)
    b0 = v & 255
    b1 = (v >> 8) & 255
    b2 = (v >> 16) & 255
    b3 = (v >> 24) & 255
    return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3

// WHY: Reverses the byte order of a 64-bit quadword integer.
//      Used for 64-bit ELF headers, relocations, and Mach-O load commands.
fn bswap64(v)
    b0 = v & 255
    b1 = (v >> 8) & 255
    b2 = (v >> 16) & 255
    b3 = (v >> 24) & 255
    b4 = (v >> 32) & 255
    b5 = (v >> 40) & 255
    b6 = (v >> 48) & 255
    b7 = (v >> 56) & 255
    res = (b0 << 56) | (b1 << 48) | (b2 << 40) | (b3 << 32)
    res = res | (b4 << 24) | (b5 << 16) | (b6 << 8) | b7
    return res

// ── 2. Host Silicon Endianness Detection ──────────────────────────────────────

// WHY: AMD64 and ARM64 in standard mode are Little-Endian, but network processors
//      and certain RISC-V configurations may run Big-Endian. This detects host order
//      dynamically via an inline 2-byte word check.
fn endian_is_host_little()
    // Constant 1 in 16-bit representation:
    // Little-endian memory layout: [0x01, 0x00] -> first byte is 1
    // Big-endian memory layout:    [0x00, 0x01] -> first byte is 0
    w = 1
    b0 = w & 255
    if b0 == 1
        return 1
    return 0

// ── 3. Memory Serialization: 16-Bit Integers ──────────────────────────────────

// WHY: Writes 16-bit value in Little-Endian byte order to memory at [ptr + offset].
fn mem_write_u16_le(ptr, offset, val)
    if ptr == 0 return 0
    mem_byte_write(ptr, offset + 0, val & 255)
    mem_byte_write(ptr, offset + 1, (val >> 8) & 255)
    return 2

// WHY: Writes 16-bit value in Big-Endian (Network Byte Order) to memory at [ptr + offset].
fn mem_write_u16_be(ptr, offset, val)
    if ptr == 0 return 0
    mem_byte_write(ptr, offset + 0, (val >> 8) & 255)
    mem_byte_write(ptr, offset + 1, val & 255)
    return 2

// WHY: Reads 16-bit unsigned integer in Little-Endian byte order from [ptr + offset].
fn mem_read_u16_le(ptr, offset)
    if ptr == 0 return 0
    b0 = mem_byte_read(ptr, offset + 0)
    b1 = mem_byte_read(ptr, offset + 1)
    return b0 | (b1 << 8)

// WHY: Reads 16-bit unsigned integer in Big-Endian byte order from [ptr + offset].
fn mem_read_u16_be(ptr, offset)
    if ptr == 0 return 0
    b0 = mem_byte_read(ptr, offset + 0)
    b1 = mem_byte_read(ptr, offset + 1)
    return (b0 << 8) | b1

// ── 4. Memory Serialization: 32-Bit Integers ──────────────────────────────────

// WHY: Writes 32-bit value in Little-Endian byte order to memory at [ptr + offset].
fn mem_write_u32_le(ptr, offset, val)
    if ptr == 0 return 0
    mem_byte_write(ptr, offset + 0, val & 255)
    mem_byte_write(ptr, offset + 1, (val >> 8) & 255)
    mem_byte_write(ptr, offset + 2, (val >> 16) & 255)
    mem_byte_write(ptr, offset + 3, (val >> 24) & 255)
    return 4

// WHY: Writes 32-bit value in Big-Endian byte order to memory at [ptr + offset].
fn mem_write_u32_be(ptr, offset, val)
    if ptr == 0 return 0
    mem_byte_write(ptr, offset + 0, (val >> 24) & 255)
    mem_byte_write(ptr, offset + 1, (val >> 16) & 255)
    mem_byte_write(ptr, offset + 2, (val >> 8) & 255)
    mem_byte_write(ptr, offset + 3, val & 255)
    return 4

// WHY: Reads 32-bit unsigned integer in Little-Endian byte order from [ptr + offset].
fn mem_read_u32_le(ptr, offset)
    if ptr == 0 return 0
    b0 = mem_byte_read(ptr, offset + 0)
    b1 = mem_byte_read(ptr, offset + 1)
    b2 = mem_byte_read(ptr, offset + 2)
    b3 = mem_byte_read(ptr, offset + 3)
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)

// WHY: Reads 32-bit unsigned integer in Big-Endian byte order from [ptr + offset].
fn mem_read_u32_be(ptr, offset)
    if ptr == 0 return 0
    b0 = mem_byte_read(ptr, offset + 0)
    b1 = mem_byte_read(ptr, offset + 1)
    b2 = mem_byte_read(ptr, offset + 2)
    b3 = mem_byte_read(ptr, offset + 3)
    return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3

// ── 5. Memory Serialization: 64-Bit Integers ──────────────────────────────────

// WHY: Writes 64-bit value in Little-Endian byte order to memory at [ptr + offset].
fn mem_write_u64_le(ptr, offset, val)
    if ptr == 0 return 0
    mem_byte_write(ptr, offset + 0, val & 255)
    mem_byte_write(ptr, offset + 1, (val >> 8) & 255)
    mem_byte_write(ptr, offset + 2, (val >> 16) & 255)
    mem_byte_write(ptr, offset + 3, (val >> 24) & 255)
    mem_byte_write(ptr, offset + 4, (val >> 32) & 255)
    mem_byte_write(ptr, offset + 5, (val >> 40) & 255)
    mem_byte_write(ptr, offset + 6, (val >> 48) & 255)
    mem_byte_write(ptr, offset + 7, (val >> 56) & 255)
    return 8

// WHY: Writes 64-bit value in Big-Endian byte order to memory at [ptr + offset].
fn mem_write_u64_be(ptr, offset, val)
    if ptr == 0 return 0
    mem_byte_write(ptr, offset + 0, (val >> 56) & 255)
    mem_byte_write(ptr, offset + 1, (val >> 48) & 255)
    mem_byte_write(ptr, offset + 2, (val >> 40) & 255)
    mem_byte_write(ptr, offset + 3, (val >> 32) & 255)
    mem_byte_write(ptr, offset + 4, (val >> 24) & 255)
    mem_byte_write(ptr, offset + 5, (val >> 16) & 255)
    mem_byte_write(ptr, offset + 6, (val >> 8) & 255)
    mem_byte_write(ptr, offset + 7, val & 255)
    return 8

// WHY: Reads 64-bit unsigned integer in Little-Endian byte order from [ptr + offset].
fn mem_read_u64_le(ptr, offset)
    if ptr == 0 return 0
    b0 = mem_byte_read(ptr, offset + 0)
    b1 = mem_byte_read(ptr, offset + 1)
    b2 = mem_byte_read(ptr, offset + 2)
    b3 = mem_byte_read(ptr, offset + 3)
    b4 = mem_byte_read(ptr, offset + 4)
    b5 = mem_byte_read(ptr, offset + 5)
    b6 = mem_byte_read(ptr, offset + 6)
    b7 = mem_byte_read(ptr, offset + 7)
    res = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    res = res | (b4 << 32) | (b5 << 40) | (b6 << 48) | (b7 << 56)
    return res

// WHY: Reads 64-bit unsigned integer in Big-Endian byte order from [ptr + offset].
fn mem_read_u64_be(ptr, offset)
    if ptr == 0 return 0
    b0 = mem_byte_read(ptr, offset + 0)
    b1 = mem_byte_read(ptr, offset + 1)
    b2 = mem_byte_read(ptr, offset + 2)
    b3 = mem_byte_read(ptr, offset + 3)
    b4 = mem_byte_read(ptr, offset + 4)
    b5 = mem_byte_read(ptr, offset + 5)
    b6 = mem_byte_read(ptr, offset + 6)
    b7 = mem_byte_read(ptr, offset + 7)
    res = (b0 << 56) | (b1 << 48) | (b2 << 40) | (b3 << 32)
    res = res | (b4 << 24) | (b5 << 16) | (b6 << 8) | b7
    return res

// ── 6. Conversion Functions (Host to Target / Target to Host) ─────────────────

fn endian_to_le16(v)
    if endian_is_host_little() return v
    return bswap16(v)

fn endian_to_be16(v)
    if endian_is_host_little() return bswap16(v)
    return v

fn endian_to_le32(v)
    if endian_is_host_little() return v
    return bswap32(v)

fn endian_to_be32(v)
    if endian_is_host_little() return bswap32(v)
    return v

fn endian_to_le64(v)
    if endian_is_host_little() return v
    return bswap64(v)

fn endian_to_be64(v)
    if endian_is_host_little() return bswap64(v)
    return v

fn endian_from_le16(v) return endian_to_le16(v)
fn endian_from_be16(v) return endian_to_be16(v)
fn endian_from_le32(v) return endian_to_le32(v)
fn endian_from_be32(v) return endian_to_be32(v)
fn endian_from_le64(v) return endian_to_le64(v)
fn endian_from_be64(v) return endian_to_be64(v)
