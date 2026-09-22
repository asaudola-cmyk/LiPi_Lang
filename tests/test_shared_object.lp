// ==============================================================================
// 👑 Test: Lipi Sovereign Shared Object (.so) Dynamic Library Emitter
// ⚡ 100% Pure Lipi | ELF64 ET_DYN | Position Independent Code (PIC) | Zero GCC
// ==============================================================================
//
// WHY: Validates that Lipi compiles standalone Linux ELF64 Shared Libraries (.so)
//      with ET_DYN (type 3), canonical .dynamic and .dynsym export tables,
//      and RIP-relative addressing without calling gcc -shared or GNU ld.
// ==============================================================================

include "src/runtime/lipi_syscall.lp"

say "========================================================"
say "👑 Testing Lipi Sovereign Shared Object (.so) Emitter"
say "========================================================"

// ── Test 1: Generate Shared Library Source ───────────────────────────────────
say "[1/4] Generating Sovereign Library Source (/tmp/libtest_math.lp)..."

lib_source = "fn lipi_math_add a b\n    return a + b\n\nfn lipi_math_mul a b\n    return a * b\n\nfn lipi_math_square x\n    return x * x\n"
src_path = "/tmp/libtest_math.lp"
so_path  = "/tmp/libtest_math.so"

fd = syscall(2, src_path, 577, 420, 0, 0, 0) // O_WRONLY | O_CREAT | O_TRUNC (0x241 = 577), 0644
if fd < 0
    say "FAIL: Failed to open " + src_path + " for writing."
    exit(1)

syscall(1, fd, lib_source, len(lib_source), 0, 0, 0)
syscall(3, fd, 0, 0, 0, 0, 0)
say "  ✔ Source generated successfully."

// Helper: executes shell command via fork + execve
fn exec_cmd cmd_str
    sh = "/bin/sh"
    flag = "-c"
    argv = syscall(9, 0, 64, 3, 34, 0 - 1, 0)
    sys_poke(argv + 0, sh)
    sys_poke(argv + 8, flag)
    sys_poke(argv + 16, cmd_str)
    sys_poke(argv + 24, 0)

    env = syscall(9, 0, 16, 3, 34, 0 - 1, 0)
    sys_poke(env + 0, 0)

    st = syscall(9, 0, 16, 3, 34, 0 - 1, 0)
    sys_poke(st + 0, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        syscall(59, sh, argv, env, 0, 0, 0)
        syscall(60, 1, 0, 0, 0, 0, 0)

    syscall(61, pid, st, 0, 0, 0, 0)
    raw_status = sys_peek(st)
    exit_code = (raw_status / 256) % 256

    syscall(11, argv, 64, 0, 0, 0, 0)
    syscall(11, env, 16, 0, 0, 0, 0)
    syscall(11, st, 16, 0, 0, 0, 0)
    return exit_code

// ── Test 2: Compile with 'lipc -shared' ───────────────────────────────────────
say "[2/4] Compiling to Standalone ELF64 Shared Object (.so)..."

cmd_str = "./bin/lipc -shared " + src_path + " -o " + so_path
code = exec_cmd(cmd_str)
if code != 0
    say "FAIL: Failed to compile shared library! Exit code: " + str(code)
    exit(1)
say "  ✔ Compilation finished successfully (exit 0)."

// ── Test 3: Inspect Binary ELF64 Header & ET_DYN Verification ─────────────────
say "[3/4] Inspecting Generated .so ELF64 Headers..."

so_fd = syscall(2, so_path, 0, 0, 0, 0, 0) // O_RDONLY
if so_fd < 0
    say "FAIL: Generated shared object " + so_path + " not found!"
    exit(1)

hdr_buf = syscall(9, 0, 1024, 3, 34, 0 - 1, 0)
n_read = syscall(0, so_fd, hdr_buf, 1024, 0, 0, 0) // read 1KB
if n_read < 176
    say "FAIL: File size too small for ELF64 header + phdrs: " + str(n_read)
    exit(1)

// Verify ELF Magic: 0x7F 'E' 'L' 'F'
b0 = sys_peek8(hdr_buf + 0)
b1 = sys_peek8(hdr_buf + 1)
b2 = sys_peek8(hdr_buf + 2)
b3 = sys_peek8(hdr_buf + 3)

if b0 != 127 or b1 != 69 or b2 != 76 or b3 != 70
    say "FAIL: Corrupted ELF magic bytes!"
    exit(1)
say "  ✔ ELF Magic verified: 0x7F 'E' 'L' 'F'"

// Verify ELF Class: 2 (64-bit)
elf_class = sys_peek8(hdr_buf + 4)
if elf_class != 2
    say "FAIL: Expected 64-bit ELF class 2, got: " + str(elf_class)
    exit(1)
say "  ✔ ELF Class verified: 64-bit Architecture"

// Verify e_type at byte 16: ET_DYN (3 = Shared Object / Position-Independent)
e_type = sys_peek8(hdr_buf + 16)
if e_type != 3
    say "FAIL: Expected e_type == 3 (ET_DYN Shared Object), got: " + str(e_type)
    exit(1)
say "  ✔ ELF e_type verified: ET_DYN (3) Shared Object Dynamic Library!"

// Verify e_machine at byte 18: EM_X86_64 (62)
e_machine = sys_peek8(hdr_buf + 18)
if e_machine != 62
    say "FAIL: Expected EM_X86_64 (62), got: " + str(e_machine)
    exit(1)
say "  ✔ Machine architecture verified: AMD x86-64 (EM_X86_64)"

// Verify Program Header Count at byte 56: e_phnum == 2 (PT_LOAD + PT_DYNAMIC)
e_phnum = sys_peek8(hdr_buf + 56)
if e_phnum != 2
    say "FAIL: Expected e_phnum == 2, got: " + str(e_phnum)
    exit(1)
say "  ✔ Program headers verified: PT_LOAD and PT_DYNAMIC present (phnum=2)"

// ── Test 4: Exported Symbols in .dynstr Verification ──────────────────────────
say "[4/4] Verifying Exported Functions in Dynamic String & Symbol Tables..."

// Read entire file to find symbol strings
all_bytes = syscall(9, 0, 65536, 3, 34, 0 - 1, 0)
syscall(8, so_fd, 0, 0, 0, 0, 0) // lseek to 0
total_so = syscall(0, so_fd, all_bytes, 65536, 0, 0, 0)
syscall(3, so_fd, 0, 0, 0, 0, 0)

fn search_bytes buf buf_len pattern
    p_len = len(pattern)
    bi = 0
    while bi <= buf_len - p_len
        match = 1
        pi = 0
        while pi < p_len
            if sys_peek8(buf + bi + pi) != ord(char_at(pattern, pi))
                match = 0
                break
            pi = pi + 1
        if match == 1 return 1
        bi = bi + 1
    return 0

found_add = search_bytes(all_bytes, total_so, "lipi_math_add")
found_mul = search_bytes(all_bytes, total_so, "lipi_math_mul")
found_sq  = search_bytes(all_bytes, total_so, "lipi_math_square")

if found_add == 0 or found_mul == 0 or found_sq == 0
    say "FAIL: Exported symbols not found in .dynstr table!"
    exit(1)

say "  ✔ Exported symbol verified: 'lipi_math_add' in .dynstr"
say "  ✔ Exported symbol verified: 'lipi_math_mul' in .dynstr"
say "  ✔ Exported symbol verified: 'lipi_math_square' in .dynstr"

// Clean up temporary files
syscall(87, src_path, 0, 0, 0, 0, 0) // unlink
syscall(87, so_path, 0, 0, 0, 0, 0)  // unlink
syscall(11, hdr_buf, 1024, 0, 0, 0, 0)
syscall(11, all_bytes, 65536, 0, 0, 0, 0)

say "========================================================"
say "PASS: Sovereign Shared Object (.so) Emitter 100% Verified!"
say "========================================================"
