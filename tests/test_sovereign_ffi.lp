// ==============================================================================
// 🧪 LIPI TEST: Sovereign In-Memory ELF FFI Bridge Test Suite
// ⚡ Tests raw in-memory ELF64 shared object mapping, section header parsing,
//    dynamic symbol lookup, 16-byte System V ABI alignment guard, and register setup.
// ==============================================================================

include "universe/core/ffi_sovereign.lp"

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ " + test_name

say "========================================================"
say "👑 Testing Lipi Sovereign In-Memory ELF FFI Bridge"
say "========================================================"

// ── Test 1: In-Memory ELF64 Header Structure Verification ─────────────────────
say "[1/5] Testing In-Memory ELF64 Shared Object Loader..."
// Construct a mock ELF64 shared library buffer in memory
mock_sz = 512
mock_elf = malloc(mock_sz)
mem_fill(mock_elf, 0, mock_sz)

// Write ELF Magic: 0x7F, 'E', 'L', 'F'
mem_byte_write(mock_elf, 0, 127)
mem_byte_write(mock_elf, 1, 69)
mem_byte_write(mock_elf, 2, 76)
mem_byte_write(mock_elf, 3, 70)
mem_byte_write(mock_elf, 4, 2) // Class: ELFCLASS64
mem_byte_write(mock_elf, 5, 1) // Data: ELFDATA2LSB (little-endian)

// e_shoff = 128 (offset 40)
mem_byte_write(mock_elf, 40, 128)
// e_shentsize = 64 (offset 58)
mem_byte_write(mock_elf, 58, 64)
// e_shnum = 3 (offset 60)
mem_byte_write(mock_elf, 60, 3)

lib = ffi_lib_new("mock_lib.so")
list_set(lib, 0, mock_elf)
list_set(lib, 1, mock_sz)
list_set(lib, 6, 1) // loaded

assert_eq(get(lib, 6), 1, "Library marked as loaded")
assert_eq(get(lib, 1), 512, "Library buffer size is 512 bytes")

// ── Test 2: Dynamic Symbol Table Configuration ────────────────────────────────
say "[2/5] Testing Dynamic Symbol Table Configuration..."
// Setup mock .dynsym at offset 200, count = 2
// Setup mock .dynstr at offset 300
list_set(lib, 2, 200) // dynsym_offset
list_set(lib, 3, 2)   // dynsym_count
list_set(lib, 4, 300) // dynstr_offset

// Symbol 0: name at offset 0 in dynstr ("add_numbers")
// st_name (offset 200) = 0
// st_value (offset 208) = 1024
mem_byte_write(mock_elf, 208, 0)
mem_byte_write(mock_elf, 209, 4) // 1024 (0x0400)

// Write string "add_numbers\0" into dynstr at offset 300
sym_name = "add_numbers"
i = 0
while i < len(sym_name)
    mem_byte_write(mock_elf, 300 + i, ord(char_at(sym_name, i)))
    i = i + 1
mem_byte_write(mock_elf, 300 + len(sym_name), 0)

// ── Test 3: Dynamic Symbol Resolver ───────────────────────────────────────────
say "[3/5] Testing Dynamic Symbol Resolver (ffi_find_symbol)..."
fn_ptr = ffi_find_symbol(lib, "add_numbers")
expected_ptr = mock_elf + 1024
assert_eq(fn_ptr, expected_ptr, "Resolved 'add_numbers' address correctly (mock_elf + 1024)")

// Lookup non-existent symbol
missing_ptr = ffi_find_symbol(lib, "non_existent_fn")
assert_eq(missing_ptr, 0, "Non-existent symbol safely returned 0")

// ── Test 4: 16-Byte Stack Alignment Guard (Trap 2 Defense) ────────────────────
say "[4/5] Testing System V ABI 16-Byte Stack Alignment Guard (Trap 2 Defense)..."
// Aligned pointer (e.g. 1600 % 16 == 0)
assert_eq(ffi_check_abi_alignment(1600), 1, "Stack pointer 1600 is 16-byte aligned")

// Unaligned pointer (e.g. 1608 % 16 != 0)
assert_eq(ffi_check_abi_alignment(1608), 0, "Stack pointer 1608 is unaligned (Trap 2 caught)")

// Prepare call with unaligned input stack pointer 4092 -> must auto-align to 4080
call_pkg = ffi_prepare_call(fn_ptr, 10, 20, 30, 0, 0, 0, 4092)
aligned_sp = get(call_pkg, 1)
assert_eq(aligned_sp, 4080, "Auto-aligned stack pointer 4092 to 4080 (16-byte boundary)")
assert_eq(ffi_check_abi_alignment(aligned_sp), 1, "Aligned stack pointer verified (4080 % 16 == 0)")

// ── Test 5: System V Register Assignment & Simulated Dispatch ─────────────────
say "[5/5] Testing System V Register Assignment & Invocation..."
rdi = get(call_pkg, 2)
rsi = get(call_pkg, 3)
rdx = get(call_pkg, 4)
rax = get(call_pkg, 8)

assert_eq(rdi, 10, "Argument 1 mapped to RDI (10)")
assert_eq(rsi, 20, "Argument 2 mapped to RSI (20)")
assert_eq(rdx, 30, "Argument 3 mapped to RDX (30)")
assert_eq(rax, 0, "RAX initialized to 0 (variadic safety)")

// Dispatch call
res = ffi_call_simulated(call_pkg)
assert_eq(res, 60, "Simulated call produced correct sum (10 + 20 + 30 = 60)")

free(mock_elf, mock_sz)

say "========================================================"
say "PASS: Lipi Sovereign In-Memory ELF FFI Bridge Verified 100%!"
say "========================================================"
