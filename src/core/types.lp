// ==============================================================================
// 👑 LIPI FIRST 1.0.0 FREESTANDING CORE SILICON PRIMITIVES: TYPES (src/core/types.lp)
// ⚡ 100% Pure Lipi Sovereign Implementation | Zero C | Zero Libc | Zero Dependencies
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Hardware-level silicon types require strict, deterministic sizing and alignment
//    independent of host C compiler ABIs, operating system quirks, or runtime GC.
// 2. High-performance compilers, AST lowerings, and VM/JIT runtimes require compact,
//    integer-tagged type identifiers that fit in a single CPU register for O(1) matching.
// 3. Slices (pointer + length + element_size) form the universal zero-copy bridge
//    between raw kernel memory pages, string views, binary buffers, and compilation units.
//
// ARCHITECTURAL SPECIFICATION:
// - Hardware Target: AMD64 / AArch64 Silicon Architecture
// - Pointer Width: 64 bits (8 bytes)
// - Word Size: 64 bits (8 bytes, standard CPU quadword)
// - Cacheline Alignment: 64 bytes (L1 Data Cache line boundary)
// ==============================================================================

// ── 1. Silicon Hardware Architecture Constants ───────────────────────────────

POINTER_WIDTH    = 8
POINTER_BITS     = 64
WORD_SIZE        = 8
WORD_BITS        = 64
CACHELINE_SIZE   = 64
PAGE_SIZE        = 4096
HUGE_PAGE_SIZE   = 2097152

// ── 2. Universal Type Tags (Numeric Identifiers for Compiler & IR) ────────────
// WHY: Using contiguous small integers enables O(1) jump-table dispatch in
//      the compiler frontend, optimizer, and code generator.

TYPE_UNKNOWN     = 0
TYPE_VOID        = 1
TYPE_BOOL        = 2
TYPE_I8          = 3
TYPE_U8          = 4
TYPE_I16         = 5
TYPE_U16         = 6
TYPE_I32         = 7
TYPE_U32         = 8
TYPE_I64         = 9
TYPE_U64         = 10
TYPE_F32         = 11
TYPE_F64         = 12
TYPE_PTR         = 13
TYPE_RAW_PTR     = 14
TYPE_SLICE       = 15
TYPE_ARRAY       = 16
TYPE_STRING      = 17
TYPE_STRUCT      = 18
TYPE_FN          = 19
TYPE_ANY         = 20

// ── 3. Integer Range Limits (Signed & Unsigned Silicon Boundaries) ────────────

I8_MIN           = 0 - 128
I8_MAX           = 127
U8_MAX           = 255

I16_MIN          = 0 - 32768
I16_MAX          = 32767
U16_MAX          = 65535

I32_MIN          = 0 - 2147483648
I32_MAX          = 2147483647
U32_MAX          = 4294967295

I64_MIN          = 0 - 9223372036854775807 - 1
I64_MAX          = 9223372036854775807

// ── 4. Hardware Alignment Primitives ──────────────────────────────────────────

// WHY: Rounds an offset or memory address up to the next multiple of `align`.
//      Requires `align` to be a power of 2 (e.g. 1, 2, 4, 8, 16, 64).
//      Essential for CPU bus transfers, preventing split-line memory accesses.
fn align_up(val, align)
    if align <= 1
        return val
    rem = val % align
    if rem == 0
        return val
    return val + (align - rem)

// WHY: Rounds an offset or memory address down to the nearest multiple of `align`.
fn align_down(val, align)
    if align <= 1
        return val
    rem = val % align
    return val - rem

// WHY: Verifies whether an address satisfies the hardware alignment requirement.
fn is_aligned(val, align)
    if align <= 1
        return 1
    return (val % align) == 0

// ── 5. Type Introspection Functions ───────────────────────────────────────────

// WHY: Returns the exact silicon byte footprint of a primitive type.
fn type_byte_size(tag)
    if tag == TYPE_I8 or tag == TYPE_U8 or tag == TYPE_BOOL
        return 1
    if tag == TYPE_I16 or tag == TYPE_U16
        return 2
    if tag == TYPE_I32 or tag == TYPE_U32 or tag == TYPE_F32
        return 4
    if tag == TYPE_I64 or tag == TYPE_U64 or tag == TYPE_F64 or tag == TYPE_PTR or tag == TYPE_RAW_PTR or tag == TYPE_FN
        return 8
    if tag == TYPE_SLICE
        // Slice is { slice_ptr: 8, slice_len: 8, slice_elem_size: 8 } -> 24 bytes in Lipi
        return 24
    if tag == TYPE_STRING
        // String view { ptr: 8, len: 8 } -> 16 bytes
        return 16
    return 8

// WHY: Returns the natural hardware alignment boundary for a type.
fn type_alignment(tag)
    if tag == TYPE_I8 or tag == TYPE_U8 or tag == TYPE_BOOL
        return 1
    if tag == TYPE_I16 or tag == TYPE_U16
        return 2
    if tag == TYPE_I32 or tag == TYPE_U32 or tag == TYPE_F32
        return 4
    // 64-bit scalars and pointers require 8-byte natural alignment
    return 8

// WHY: Determines if a type is an integer primitive.
fn type_is_integer(tag)
    if tag >= TYPE_I8 and tag <= TYPE_U64
        return 1
    return 0

// WHY: Determines if a type is a signed integer primitive.
fn type_is_signed(tag)
    if tag == TYPE_I8 or tag == TYPE_I16 or tag == TYPE_I32 or tag == TYPE_I64
        return 1
    return 0

// WHY: Determines if a type is an unsigned integer primitive.
fn type_is_unsigned(tag)
    if tag == TYPE_U8 or tag == TYPE_U16 or tag == TYPE_U32 or tag == TYPE_U64
        return 1
    return 0

// WHY: Determines if a type is an IEEE-754 floating point primitive.
fn type_is_float(tag)
    if tag == TYPE_F32 or tag == TYPE_F64
        return 1
    return 0

// WHY: Determines if a type is an address pointer.
fn type_is_pointer(tag)
    if tag == TYPE_PTR or tag == TYPE_RAW_PTR
        return 1
    return 0

// WHY: Returns the canonical string representation for error messages and AST dumps.
fn type_name(tag)
    if tag == TYPE_VOID     return "void"
    if tag == TYPE_BOOL     return "bool"
    if tag == TYPE_I8       return "i8"
    if tag == TYPE_U8       return "u8"
    if tag == TYPE_I16      return "i16"
    if tag == TYPE_U16      return "u16"
    if tag == TYPE_I32      return "i32"
    if tag == TYPE_U32      return "u32"
    if tag == TYPE_I64      return "i64"
    if tag == TYPE_U64      return "u64"
    if tag == TYPE_F32      return "f32"
    if tag == TYPE_F64      return "f64"
    if tag == TYPE_PTR      return "ptr"
    if tag == TYPE_RAW_PTR  return "raw_ptr"
    if tag == TYPE_SLICE    return "slice"
    if tag == TYPE_ARRAY    return "array"
    if tag == TYPE_STRING   return "string"
    if tag == TYPE_STRUCT   return "struct"
    if tag == TYPE_FN       return "fn"
    if tag == TYPE_ANY      return "any"
    return "unknown"

// WHY: Range checker to prevent arithmetic overflows when casting or constant-folding.
fn int_fits_type(val, tag)
    if tag == TYPE_I8
        if val >= I8_MIN and val <= I8_MAX return 1
        return 0
    if tag == TYPE_U8
        if val >= 0 and val <= U8_MAX return 1
        return 0
    if tag == TYPE_I16
        if val >= I16_MIN and val <= I16_MAX return 1
        return 0
    if tag == TYPE_U16
        if val >= 0 and val <= U16_MAX return 1
        return 0
    if tag == TYPE_I32
        if val >= I32_MIN and val <= I32_MAX return 1
        return 0
    if tag == TYPE_U32
        if val >= 0 and val <= U32_MAX return 1
        return 0
    if tag == TYPE_I64 or tag == TYPE_U64
        return 1
    return 0

// ── 6. Zero-Copy Slice Representation & Silicon Operations ────────────────────
// WHY: A slice is a fat pointer { slice_ptr, slice_len, slice_elem_size } providing
//      safe, non-owning views into contiguous memory without heap allocations or buffer copying.

struct Slice
    slice_ptr
    slice_len
    slice_elem_size

// WHY: Instantiates a new slice referencing an existing memory segment.
fn slice_new(ptr, len, elem_size)
    s = Slice()
    s.slice_ptr = ptr
    s.slice_len = len
    if elem_size <= 0
        s.slice_elem_size = 1
    else
        s.slice_elem_size = elem_size
    return s

// WHY: Creates an empty zero-capacity slice.
fn slice_empty(elem_size)
    return slice_new(0, 0, elem_size)

// WHY: Returns the number of elements in the slice.
fn slice_length(s)
    if s == 0 return 0
    return s.slice_len

// WHY: Calculates the total memory footprint of the slice in bytes.
fn slice_byte_len(s)
    if s == 0 return 0
    return s.slice_len * s.slice_elem_size

// WHY: Checks whether the slice contains zero elements.
fn slice_is_empty(s)
    if s == 0 return 1
    if s.slice_len <= 0 return 1
    return 0

// WHY: Computes the exact physical memory address of element at `index`.
//      Includes defensive bounds checking; returns 0 on out-of-bounds.
fn slice_get_ptr(s, index)
    if s == 0 or s.slice_ptr == 0 return 0
    if index < 0 or index >= s.slice_len return 0
    return s.slice_ptr + (index * s.slice_elem_size)

// WHY: Reads an 8-bit byte at `index` from a byte slice (elem_size == 1).
fn slice_read_byte(s, index)
    if s == 0 or s.slice_ptr == 0 return 0
    if index < 0 or index >= s.slice_len return 0
    return mem_byte_read(s.slice_ptr, index)

// WHY: Writes an 8-bit byte at `index` into a byte slice.
fn slice_write_byte(s, index, val)
    if s == 0 or s.slice_ptr == 0 return 0
    if index < 0 or index >= s.slice_len return 0
    mem_byte_write(s.slice_ptr, index, val)
    return 1

// WHY: Reads a 64-bit quadword at `index` from a 64-bit slice (elem_size == 8).
fn slice_read_word(s, index)
    if s == 0 or s.slice_ptr == 0 return 0
    if index < 0 or index >= s.slice_len return 0
    offset = index * s.slice_elem_size
    return mem_read(s.slice_ptr, offset)

// WHY: Writes a 64-bit quadword at `index` into a 64-bit slice.
fn slice_write_word(s, index, val)
    if s == 0 or s.slice_ptr == 0 return 0
    if index < 0 or index >= s.slice_len return 0
    offset = index * s.slice_elem_size
    mem_write(s.slice_ptr, offset, val)
    return 1

// WHY: Creates a windowed subslice spanning `[start_idx, end_idx)` in O(1) time
//      with zero allocation and strict boundary preservation.
fn slice_subslice(s, start_idx, end_idx)
    if s == 0 or s.slice_ptr == 0
        return slice_empty(1)
    if start_idx < 0
        start_idx = 0
    if end_idx > s.slice_len
        end_idx = s.slice_len
    if start_idx >= end_idx
        return slice_new(s.slice_ptr + (start_idx * s.slice_elem_size), 0, s.slice_elem_size)
    new_ptr = s.slice_ptr + (start_idx * s.slice_elem_size)
    new_len = end_idx - start_idx
    return slice_new(new_ptr, new_len, s.slice_elem_size)

// WHY: High-performance memory copying between slices. Copies at most `count` elements.
fn slice_copy(dest, src, count)
    if dest == 0 or src == 0 or dest.slice_ptr == 0 or src.slice_ptr == 0 return 0
    if dest.slice_elem_size != src.slice_elem_size return 0
    to_copy = count
    if to_copy > src.slice_len to_copy = src.slice_len
    if to_copy > dest.slice_len to_copy = dest.slice_len
    if to_copy <= 0 return 0

    total_bytes = to_copy * dest.slice_elem_size
    i = 0
    while i < total_bytes
        b = mem_byte_read(src.slice_ptr, i)
        mem_byte_write(dest.slice_ptr, i, b)
        i = i + 1
    return to_copy
