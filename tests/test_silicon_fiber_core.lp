// ==============================================================================
// 🧪 LIPI SILICON FIBER CORE RIGOROUS TEST (tests/test_silicon_fiber_core.lp)
// ⚡ Deep hardware verification:
//    1. Physical x86_64 silicon context switching (switch_context)
//    2. 16-Byte System V ABI stack alignment verification at callee entry
//    3. Callee-saved register preservation (%rbx, %rbp, %r12-%r15)
//    4. Multi-yield cooperative execution with state preservation
//    5. Direct native silicon yield trampoline (yield_silicon) across slices
//    6. Step count synchronization across native function executions
//    7. Null/negative fn_code safe termination without SIGSEGV
//    8. Dual software canary & pointer bounds protection
// ==============================================================================

include "src/runtime/async/fiber.lp"

fn assert_true cond test_name
    if cond == 0
        say "  ❌ FAILED: " + test_name
        exit(1)
    end
    say "  ✔ " + test_name
end

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    end
    say "  ✔ " + test_name
end

say "========================================================"
say "👑 LIPI SILICON FIBER CORE VERIFICATION (Agent 1 of 12)"
say "========================================================"

// ── Test 1: Stack Alignment & Bootstrap Integrity ─────────────────────────────
say "[1/8] Testing Silicon Fiber Stack Frame & 16-Byte Alignment..."
f = fiber_new(777, 1, 10, 4096)
assert_eq(get(f, 0), 777, "Fiber ID is 777")
assert_eq(get(f, 1), FIBER_READY, "Initial state is READY")
assert_eq(get(f, 3), 4096, "Stack size is 4KB")

stk_ptr = get(f, 4)
stk_base = get(f, 2)
assert_true(stk_ptr > stk_base, "Stack pointer is above stack base")
assert_true(stk_ptr < stk_base + 4096, "Stack pointer is within allocated page")

// Canary check
assert_eq(fiber_check_stack_guard(f), 1, "Stack guard canary intact")
fiber_free(f)

// ── Test 2: True Silicon Multi-Slice Execution ────────────────────────────────
say "[2/8] Testing Silicon Multi-Slice Counter Yield & Completion..."
sched = fiber_scheduler_new()

// Fiber A: count to 4 (requires 4 cooperative silicon yields)
// Fiber B: count to 2 (requires 2 cooperative silicon yields)
// Fiber C: accumulator 250 (completes in 1 slice)
fid_a = fiber_scheduler_spawn(sched, 1, 4)
fid_b = fiber_scheduler_spawn(sched, 1, 2)
fid_c = fiber_scheduler_spawn(sched, 2, 250)

// Run ticks until completion
ticks_done = fiber_scheduler_run_all(sched, 50)
assert_eq(ticks_done, 3, "All 3 concurrent fibers completed")

fibers = get(sched, 4)
fa = get(fibers, 0)
fb = get(fibers, 1)
fc = get(fibers, 2)

assert_eq(get(fa, 7), 4, "Fiber A counter reached 4 via silicon execution")
assert_eq(get(fb, 7), 2, "Fiber B counter reached 2 via silicon execution")
assert_eq(get(fc, 7), 250, "Fiber C accumulator reached 250")

assert_eq(get(fa, 1), FIBER_DEAD, "Fiber A is DEAD")
assert_eq(get(fb, 1), FIBER_DEAD, "Fiber B is DEAD")
assert_eq(get(fc, 1), FIBER_DEAD, "Fiber C is DEAD")

assert_eq(get(fa, 8), 4, "Fiber A yielded 4 slices")
assert_eq(get(fb, 8), 2, "Fiber B yielded 2 slices")
assert_eq(get(fc, 8), 1, "Fiber C completed in 1 slice")

// ── Test 3: Silicon Custom Machine Code Function Execution ────────────────────
say "[3/8] Testing Direct Silicon Function Pointer Execution on Fiber Stack..."
// Synthesize a native AMD64 function:
// Signature: f(x) -> x * 10 + 5
jit_fn = syscall(9, 0, 4096, 7, 34, -1, 0)
mem_byte_write(jit_fn, 0, 72)
mem_byte_write(jit_fn, 1, 137)
mem_byte_write(jit_fn, 2, 248) // mov rax, rdi
mem_byte_write(jit_fn, 3, 72)
mem_byte_write(jit_fn, 4, 107)
mem_byte_write(jit_fn, 5, 192)
mem_byte_write(jit_fn, 6, 10)  // imul rax, 10
mem_byte_write(jit_fn, 7, 72)
mem_byte_write(jit_fn, 8, 131)
mem_byte_write(jit_fn, 9, 192)
mem_byte_write(jit_fn, 10, 5)  // add rax, 5
mem_byte_write(jit_fn, 11, 195) // ret

f_custom = fiber_new(888, jit_fn, 7, 4096)
res_st = fiber_execute_slice(f_custom)
assert_eq(res_st, FIBER_DEAD, "Custom JIT fiber transitioned to FIBER_DEAD")
assert_eq(get(f_custom, 7), 75, "Custom JIT fiber computed 7 * 10 + 5 = 75")
assert_eq(get(f_custom, 8), 1, "Custom JIT fiber step count synchronized to 1")
fiber_free(f_custom)
syscall(11, jit_fn, 4096, 0, 0, 0, 0)

// ── Test 4: Stack Guard Bounds Protection in Silicon ──────────────────────────
say "[4/8] Testing Stack Guard Canary Overflow Detection..."
f_canary = fiber_new(999, 1, 5, 2048)
stk_c = get(f_canary, 2)
// Tamper with canary at bottom of stack
mem_byte_write(stk_c, 0, 255)
assert_eq(fiber_check_stack_guard(f_canary), 0, "Corrupted canary correctly detected")

slice_result = fiber_execute_slice(f_canary)
assert_eq(slice_result, -1, "Silicon executor aborted slice upon canary mismatch")
assert_eq(get(f_canary, 1), FIBER_DEAD, "Compromised fiber immediately terminated")
fiber_free(f_canary)

// ── Test 5: Callee-Side 16-Byte Stack Alignment Verification ──────────────────
say "[5/8] Testing Callee-Side System V AMD64 16-Byte Stack Alignment..."
// At callee entry (immediately following `call rax`), %rsp % 16 must strictly equal 8
// per System V AMD64 ABI section 3.2.2.
// Machine code:
//   mov rax, rsp       (48 89 e0)
//   and rax, 15        (48 83 e0 0f)
//   cmp rax, 8         (48 83 f8 08)
//   je .aligned        (74 03)
//   xor eax, eax       (31 c0)
//   ret                (c3)
// .aligned:
//   mov eax, 1         (b8 01 00 00 00)
//   ret                (c3)
align_fn = syscall(9, 0, 4096, 7, 34, -1, 0)
mem_byte_write(align_fn, 0, 72)
mem_byte_write(align_fn, 1, 137)
mem_byte_write(align_fn, 2, 224)
mem_byte_write(align_fn, 3, 72)
mem_byte_write(align_fn, 4, 131)
mem_byte_write(align_fn, 5, 224)
mem_byte_write(align_fn, 6, 15)
mem_byte_write(align_fn, 7, 72)
mem_byte_write(align_fn, 8, 131)
mem_byte_write(align_fn, 9, 248)
mem_byte_write(align_fn, 10, 8)
mem_byte_write(align_fn, 11, 116)
mem_byte_write(align_fn, 12, 3)
mem_byte_write(align_fn, 13, 49)
mem_byte_write(align_fn, 14, 192)
mem_byte_write(align_fn, 15, 195)
mem_byte_write(align_fn, 16, 184)
mem_byte_write(align_fn, 17, 1)
mem_byte_write(align_fn, 18, 0)
mem_byte_write(align_fn, 19, 0)
mem_byte_write(align_fn, 20, 0)
mem_byte_write(align_fn, 21, 195)

f_align = fiber_new(1001, align_fn, 0, 4096)
st_align = fiber_execute_slice(f_align)
assert_eq(st_align, FIBER_DEAD, "Alignment test fiber finished")
assert_eq(get(f_align, 7), 1, "Fiber entry strictly conforms to 16-byte System V ABI alignment")
assert_eq(get(f_align, 8), 1, "Step count incremented to 1")
fiber_free(f_align)
syscall(11, align_fn, 4096, 0, 0, 0, 0)

// ── Test 6: Null and Negative fn_code Safety Guard ────────────────────────────
say "[6/8] Testing Null & Negative fn_code Safety (SIGSEGV Defense)..."
f_null = fiber_new(1002, 0, 0, 4096)
st_null = fiber_execute_slice(f_null)
assert_eq(st_null, FIBER_DEAD, "Null fn_code terminated safely without hardware fault")
fiber_free(f_null)

f_neg = fiber_new(1003, -42, 0, 4096)
st_neg = fiber_execute_slice(f_neg)
assert_eq(st_neg, FIBER_DEAD, "Negative fn_code terminated safely without hardware fault")
fiber_free(f_neg)

// ── Test 7: Direct Silicon Yield Trampoline Across Multiple Slices ────────────
say "[7/8] Testing Native Silicon Yield Trampoline Across Multiple Slices..."
yield_entry = fiber_get_silicon_yield()
assert_true(yield_entry > 0, "Silicon yield entry point is valid")

// Native cooperative task: loops `limit` times, yielding back to scheduler on each step
// Arguments passed by fiber_bootstrap: %rdi = limit (3), %rsi = desc
// Register preservation: saves and restores callee-saved %rbx, %r12, %rbp
ny_fn = syscall(9, 0, 4096, 7, 34, -1, 0)
// 0: push rbx (53)
mem_byte_write(ny_fn, 0, 83)
// 1: push r12 (41 54)
mem_byte_write(ny_fn, 1, 65)
mem_byte_write(ny_fn, 2, 84)
// 3: push rbp (55)
mem_byte_write(ny_fn, 3, 85)
// 4: sub rsp, 8 (48 83 ec 08)
mem_byte_write(ny_fn, 4, 72)
mem_byte_write(ny_fn, 5, 131)
mem_byte_write(ny_fn, 6, 236)
mem_byte_write(ny_fn, 7, 8)
// 8: mov rbx, rsi (48 89 f3) -> save desc in rbx
mem_byte_write(ny_fn, 8, 72)
mem_byte_write(ny_fn, 9, 137)
mem_byte_write(ny_fn, 10, 243)
// 11: mov r12, rdi (49 89 fc) -> save limit in r12 (REX.B prefix 0x49)
mem_byte_write(ny_fn, 11, 73)
mem_byte_write(ny_fn, 12, 137)
mem_byte_write(ny_fn, 13, 252)
// 14: xor ebp, ebp (31 ed) -> counter = 0
mem_byte_write(ny_fn, 14, 49)
mem_byte_write(ny_fn, 15, 237)
// 16: .loop: cmp rbp, r12 (4c 39 e5) -> compare counter with limit (REX.R prefix 0x4C)
mem_byte_write(ny_fn, 16, 76)
mem_byte_write(ny_fn, 17, 57)
mem_byte_write(ny_fn, 18, 229)
// 19: jge .done (target 43, rel = 22: 7d 16)
mem_byte_write(ny_fn, 19, 125)
mem_byte_write(ny_fn, 20, 22)
// 21: inc rbp (48 ff c5)
mem_byte_write(ny_fn, 21, 72)
mem_byte_write(ny_fn, 22, 255)
mem_byte_write(ny_fn, 23, 197)
// 24: mov rdi, rbx (48 89 df) -> pass desc to yield_silicon
mem_byte_write(ny_fn, 24, 72)
mem_byte_write(ny_fn, 25, 137)
mem_byte_write(ny_fn, 26, 223)
// 27: mov rax, yield_entry (48 b8 <imm64>)
mem_byte_write(ny_fn, 27, 72)
mem_byte_write(ny_fn, 28, 184)
mem_write(ny_fn + 29, 0, yield_entry)
// 37: call rax (ff d0) -> invoke yield_silicon
mem_byte_write(ny_fn, 37, 255)
mem_byte_write(ny_fn, 38, 208)
// 39: jmp .loop (target 16, rel = -25: eb e7)
mem_byte_write(ny_fn, 39, 235)
mem_byte_write(ny_fn, 40, 231)
// 41..42: nop
mem_byte_write(ny_fn, 41, 144)
mem_byte_write(ny_fn, 42, 144)
// 43: .done: mov rax, rbp (48 89 e8)
mem_byte_write(ny_fn, 43, 72)
mem_byte_write(ny_fn, 44, 137)
mem_byte_write(ny_fn, 45, 232)
// 46: imul rax, 10 (48 6b c0 0a) -> result = counter * 10
mem_byte_write(ny_fn, 46, 72)
mem_byte_write(ny_fn, 47, 107)
mem_byte_write(ny_fn, 48, 192)
mem_byte_write(ny_fn, 49, 10)
// 50: add rsp, 8 (48 83 c4 08)
mem_byte_write(ny_fn, 50, 72)
mem_byte_write(ny_fn, 51, 131)
mem_byte_write(ny_fn, 52, 196)
mem_byte_write(ny_fn, 53, 8)
// 54: pop rbp (5d)
mem_byte_write(ny_fn, 54, 93)
// 55: pop r12 (41 5c)
mem_byte_write(ny_fn, 55, 65)
mem_byte_write(ny_fn, 56, 92)
// 57: pop rbx (5b)
mem_byte_write(ny_fn, 57, 91)
// 58: ret (c3)
mem_byte_write(ny_fn, 58, 195)

f_y = fiber_new(2001, ny_fn, 3, 4096)

// Slices 1 to 3 should yield cooperatively
st1 = fiber_execute_slice(f_y)
assert_eq(st1, FIBER_READY, "Slice 1 yielded cooperatively in silicon")
assert_eq(get(f_y, 8), 1, "Step count is 1 after slice 1")

st2 = fiber_execute_slice(f_y)
assert_eq(st2, FIBER_READY, "Slice 2 yielded cooperatively in silicon")
assert_eq(get(f_y, 8), 2, "Step count is 2 after slice 2")

st3 = fiber_execute_slice(f_y)
assert_eq(st3, FIBER_READY, "Slice 3 yielded cooperatively in silicon")
assert_eq(get(f_y, 8), 3, "Step count is 3 after slice 3")

// Slice 4 should complete
st4 = fiber_execute_slice(f_y)
assert_eq(st4, FIBER_DEAD, "Slice 4 completed task with FIBER_DEAD")
assert_eq(get(f_y, 7), 30, "Native computation returned 3 * 10 = 30")
assert_eq(get(f_y, 8), 4, "Final step count reached 4")

fiber_free(f_y)
syscall(11, ny_fn, 4096, 0, 0, 0, 0)

// ── Test 8: Global Parameterless fiber_yield & Null Safety ────────────────────
say "[8/8] Testing Global fiber_yield & Null Pointer Robustness..."
assert_eq(fiber_yield(0), 0, "fiber_yield(0) without running fiber returns 0 safely")
assert_eq(fiber_check_stack_guard(0), 0, "fiber_check_stack_guard(0) returns 0 safely")
assert_eq(fiber_free(0), 0, "fiber_free(0) returns 0 safely")

say "========================================================"
say "👑 100% SILICON FIBER SCHEDULER TESTS PASSED FLAWLESSLY!"
say "========================================================"
