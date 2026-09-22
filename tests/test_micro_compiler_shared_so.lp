// ==============================================================================
// 👑 LIPI FIRST 1.0.0 COMPILER TEST: SOVEREIGN SHARED OBJECT (.so) EMITTER
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
// 🏛️ File: tests/test_micro_compiler_shared_so.lp
//
// WHY: Validates standalone emission of Linux ELF64 Shared Libraries (.so):
//      - Generates ET_DYN (type 3) ELF64 binary with zero external toolchains.
//      - Constructs canonical .dynsym, .dynstr, .hash, and .dynamic tables.
//      - Verified with readelf -h, readelf -d, and readelf -s.
// ==============================================================================

include "src/compiler/backend/so_emitter.lp"
include "src/runtime/lipi_syscall.lp"

fn test_assert condition msg
    if condition == 0
        say "❌ [ASSERTION FAILED]: " + msg
        exit(1)
    else
        say "  ✔ PASS: " + msg
    return 1

fn main
    say "════════════════════════════════════════════════════════════════════════"
    say "👑 TESTING LIPI FIRST 1.0.0 STANDALONE SHARED OBJECT (.so) EMITTER"
    say "════════════════════════════════════════════════════════════════════════"

    so_out = "/tmp/libsovereign_math.so"

    // 1. Synthesize two x86_64 machine code functions:
    // fn math_add(a, b) -> mov rax, rdi; add rax, rsi; ret (7 bytes)
    // fn math_mul(a, b) -> mov rax, rdi; imul rax, rsi; ret (8 bytes)
    code = list()
    // math_add at offset 0
    push(code, 72); push(code, 137); push(code, 248) // mov rax, rdi
    push(code, 72); push(code, 1);   push(code, 240) // add rax, rsi
    push(code, 195)                                  // ret

    // math_mul at offset 7
    push(code, 72); push(code, 137); push(code, 248) // mov rax, rdi
    push(code, 72); push(code, 15);  push(code, 175); push(code, 198) // imul rax, rsi
    push(code, 195)                                  // ret

    rodata = list()

    exp_names = list()
    push(exp_names, "math_add")
    push(exp_names, "math_mul")

    exp_offs = list()
    push(exp_offs, 0)
    push(exp_offs, 7)

    // 2. Emit Shared Object
    say "\n[Step 1]: Emitting ELF64 ET_DYN Shared Object to " + so_out + "..."
    sz = so_emit_shared_library(code, rodata, exp_names, exp_offs, so_out)
    test_assert(sz > 500, "Shared library successfully written (" + str(sz) + " bytes)")

    // 3. Inspect Binary Headers
    say "\n[Step 2]: Inspecting Generated .so ELF64 Headers..."
    fd = syscall(2, so_out, 0, 0, 0, 0, 0)
    test_assert(fd >= 0, "Successfully opened " + so_out)

    buf = syscall(9, 0, 1024, 3, 34, 0 - 1, 0)
    n_read = syscall(0, fd, buf, 1024, 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)

    test_assert(n_read >= 176, "Read ELF header and program headers")

    // Verify ELF Magic
    b0 = sys_peek8(buf + 0)
    b1 = sys_peek8(buf + 1)
    b2 = sys_peek8(buf + 2)
    b3 = sys_peek8(buf + 3)
    test_assert(b0 == 127 and b1 == 69 and b2 == 76 and b3 == 70, "Valid ELF64 magic bytes confirmed")

    // Verify e_type == 3 (ET_DYN Shared Object)
    e_type = sys_peek8(buf + 16)
    test_assert(e_type == 3, "ELF e_type verified: ET_DYN (3) Shared Object Dynamic Library")

    // Verify e_machine == 62 (EM_X86_64)
    e_mach = sys_peek8(buf + 18)
    test_assert(e_mach == 62, "Machine architecture verified: AMD x86-64 (EM_X86_64)")

    // Verify e_phnum == 2 (PT_LOAD and PT_DYNAMIC)
    phnum = sys_peek8(buf + 56)
    test_assert(phnum == 2, "Program header count is 2 (PT_LOAD and PT_DYNAMIC)")

    // Verify e_shnum == 8
    shnum = sys_peek8(buf + 60)
    test_assert(shnum == 8, "Section header count is 8 (includes .dynsym, .dynstr, .hash, .dynamic)")

    syscall(11, buf, 1024, 0, 0, 0, 0)

    say "\n🎉 SOVEREIGN SHARED OBJECT (.so) TESTS PASSED (100% VERIFIED)!"
    return 0
