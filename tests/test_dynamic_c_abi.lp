// ==============================================================================
// 🧪 LIPI REGRESSION TEST: Universal C-ABI Dynamic Assimilation & Scoped Arena
// ⚡ Verifies AMD64 JIT trampoline generation, System V ABI register marshalling,
//    and scoped arena memory lifecycle (Challenging C, C++, and Zig).
// ==============================================================================

include "universe/core/ffi_sovereign.lp"
include "universe/core/c_abi_call.lp"
include "universe/core/arena.lp"

fn assert_true cond test_name
    if cond == 0
        say "  ❌ FAILED: " + test_name
        exit(1)
    say "  ✔ [PASS] " + test_name

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ [PASS] " + test_name

say "================================================================="
say "👑 LIPI C-ABI: UNIVERSAL DYNAMIC ASSIMILATION (Pillar 2) 👑"
say "================================================================="

// ── Test 1: JIT Trampoline Page Allocation & Instruction Synthesis ─────────────
say "▶ Test 1: Testing Executable Trampoline Synthesis..."
tramp = c_abi_init_trampoline()
assert_true(tramp > 0, "Executable trampoline page mmapped successfully")

// Verify first opcode is mov r11, rdi (0x49, 0x89, 0xFB)
b0 = mem_byte_read(tramp, 0)
b1 = mem_byte_read(tramp, 1)
b2 = mem_byte_read(tramp, 2)
assert_eq(b0, 73, "Byte 0 is 0x49 (REX.WB prefix)")
assert_eq(b1, 137, "Byte 1 is 0x89 (MOV opcode)")
assert_eq(b2, 251, "Byte 2 is 0xFB (ModR/M r11, rdi)")

// Verify ret instruction at end (0xC3 = 195)
b_ret = mem_byte_read(tramp, 31)
assert_eq(b_ret, 195, "Trampoline concludes with RET opcode (0xC3)")

// ── Test 2: System V AMD64 ABI 16-Byte Stack Alignment Verification ───────────
say "\n▶ Test 2: Testing System V ABI Stack Alignment..."
assert_true(ffi_check_abi_alignment(1048576) == 1, "Stack 1048576 is 16-byte aligned")
assert_true(ffi_check_abi_alignment(1048578) == 0, "Stack 1048578 is unaligned (rejected)")

// Prepare simulated ABI call package: fn_ptr=4096, rdi=10, rsi=20, rdx=30
call_pkg = ffi_prepare_call(4096, 10, 20, 30, 0, 0, 0, 65536)
aligned_sp = get(call_pkg, 1)
assert_true(ffi_check_abi_alignment(aligned_sp) == 1, "Prepared stack pointer strictly aligned")
sim_res = ffi_call_simulated(call_pkg)
assert_eq(sim_res, 60, "System V simulated register sum (10 + 20 + 30 = 60)")

// ── Test 3: Scoped Arena Memory Lifecycle ──────────────────────────────────────
say "\n▶ Test 3: Testing Scoped Arena Memory Allocator..."
// 64 KB Arena
pool = arena_create(65536)
assert_true(pool > 0, "Arena pool allocated via SYS_mmap")

// Dispense three 8-byte aligned memory chunks
chunk1 = arena_alloc(pool, 32)
chunk2 = arena_alloc(pool, 64)
chunk3 = arena_alloc_aligned(pool, 128, 64) // 64-byte AVX-512 cacheline aligned

assert_true(chunk1 > 0, "Chunk 1 allocated")
assert_true(chunk2 > chunk1, "Chunk 2 bump-allocated above chunk 1")
assert_eq(chunk3 % 64, 0, "Chunk 3 strictly 64-byte aligned for SIMD vector registers")

used = arena_used(pool)
assert_true(used >= 224, "Arena tracks used memory")

// Single-cycle bulk destruction unmaps memory
destroyed = arena_destroy(pool)
assert_eq(destroyed, 0, "Arena completely destroyed without memory leak")

say "\n🎉 ALL UNIVERSAL C-ABI DYNAMIC ASSIMILATION TESTS PASSED!"
