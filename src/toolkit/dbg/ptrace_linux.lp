// ==============================================================================
// 👑 LIPI UNIFIED TOOLKIT: LINUX SYS_PTRACE DEBUGGING WRAPPERS (src/toolkit/dbg/ptrace_linux.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | SYS_ptrace (101) | Zero Libc / Zero GDB
// ==============================================================================
//
// WHY THIS MODULE:
// Native debugging, breakpoint injection, and hardware register introspection require
// direct kernel communication via Linux SYS_ptrace (syscall 101).
// Using pure sovereign Lipi to interface directly with the kernel ABI:
// 1. Completely eliminates dependencies on GDB, LLDB, ptrace.h, and libc.
// 2. Extracts exact AMD64 user_regs_struct state (RIP, RSP, RAX, general registers).
// 3. Modifies instruction memory via PTRACE_PEEKTEXT and PTRACE_POKETEXT.
// 4. Enables step-by-step CPU single stepping (PTRACE_SINGLESTEP).

include "universe/core/memory.lp"
include "universe/core/string.lp"
include "universe/core/io.lp"

// ── 1. Linux x86_64 Ptrace Constants ──────────────────────────────────────────

PTRACE_TRACEME    = 0
PTRACE_PEEKTEXT   = 1
PTRACE_PEEKDATA   = 2
PTRACE_POKETEXT   = 4
PTRACE_POKEDATA   = 5
PTRACE_CONT       = 7
PTRACE_KILL       = 8
PTRACE_SINGLESTEP = 9
PTRACE_GETREGS    = 12
PTRACE_SETREGS    = 13
PTRACE_ATTACH     = 16
PTRACE_DETACH     = 17

// ── 2. Hardware Register Struct (Linux System V AMD64 ABI) ───────────────────

// WHY: Maps 1-to-1 to the Linux kernel `struct user_regs_struct` (216 bytes / 27 quadwords).
struct X86_64_Regs
    r15
    r14
    r13
    r12
    rbp
    rbx
    r11
    r10
    r9
    r8
    rax
    rcx
    rdx
    rsi
    rdi
    orig_rax
    rip
    cs
    eflags
    rsp
    ss
    fs_base
    gs_base
    ds
    es
    fs
    gs

// ── 3. Hexadecimal Display Helpers ────────────────────────────────────────────

// WHY: Converts single byte to 2-character hex representation.
fn ptrace_hex8 b
    val = b % 256
    if val < 0 val = val + 256
    n1 = val / 16
    n2 = val % 16
    c1 = ""
    c2 = ""
    if n1 < 10 c1 = chr(48 + n1)
    else c1 = chr(87 + n1)
    if n2 < 10 c2 = chr(48 + n2)
    else c2 = chr(87 + n2)
    return c1 + c2

// WHY: Formats 64-bit integer into canonical 16-character hexadecimal string.
fn ptrace_format_hex val
    buf = malloc(8)
    mem_word_write(buf, 0, val)
    s = ptrace_hex8(mem_byte_read(buf, 7)) + ptrace_hex8(mem_byte_read(buf, 6)) + ptrace_hex8(mem_byte_read(buf, 5)) + ptrace_hex8(mem_byte_read(buf, 4)) + ptrace_hex8(mem_byte_read(buf, 3)) + ptrace_hex8(mem_byte_read(buf, 2)) + ptrace_hex8(mem_byte_read(buf, 1)) + ptrace_hex8(mem_byte_read(buf, 0))
    free(buf, 8)
    return "0x" + s

// ── 4. Raw Linux Kernel Ptrace Invocation ──────────────────────────────────────

// WHY: Canonical syscall 101 gateway with uniform 7-register argument passing.
fn ptrace_raw req pid addr data
    return syscall(101, req, pid, addr, data, 0, 0)

// ── 5. Process Lifecycle Control (Attach / Detach / Cont / Step) ───────────────

// WHY: Attaches to a running Linux process and halts it with SIGSTOP.
fn ptrace_attach pid
    rc = ptrace_raw(PTRACE_ATTACH, pid, 0, 0)
    if rc < 0
        return rc

    // Wait for target process to enter STOPPED state via Linux SYS_wait4 (61)
    status_buf = malloc(8)
    mem_word_write(status_buf, 0, 0)
    syscall(61, pid, status_buf, 0, 0, 0, 0)
    free(status_buf, 8)
    return 0

// WHY: Detaches from traced process, releasing debugging control and resuming it.
fn ptrace_detach pid
    return ptrace_raw(PTRACE_DETACH, pid, 0, 0)

// WHY: Resumes execution of halted target process.
fn ptrace_cont pid
    return ptrace_raw(PTRACE_CONT, pid, 0, 0)

// WHY: Advances CPU execution by exactly one machine instruction and raises SIGTRAP.
fn ptrace_singlestep pid
    return ptrace_raw(PTRACE_SINGLESTEP, pid, 0, 0)

// ── 6. Instruction Memory Inspection & Modification ───────────────────────────

// WHY: Reads a 64-bit machine code word from child virtual memory via PTRACE_PEEKTEXT.
fn ptrace_peek_text pid addr
    return ptrace_raw(PTRACE_PEEKTEXT, pid, addr, 0)

// WHY: Writes a 64-bit machine code word to child virtual memory via PTRACE_POKETEXT.
fn ptrace_poke_text pid addr data
    return ptrace_raw(PTRACE_POKETEXT, pid, addr, data)

// WHY: Reads a single 8-bit opcode byte from child memory at exact address.
fn ptrace_peek_byte pid addr
    word_aligned = (addr / 8) * 8
    byte_offset = addr % 8
    if byte_offset < 0
        byte_offset = byte_offset + 8

    raw_word = ptrace_peek_text(pid, word_aligned)

    // Store in scratch buffer to unpack exact byte
    buf = malloc(8)
    mem_word_write(buf, 0, raw_word)
    byte_val = mem_byte_read(buf, byte_offset)
    free(buf, 8)
    return byte_val

// WHY: Overwrites a single opcode byte in child memory without corrupting adjacent bytes.
fn ptrace_poke_byte pid addr new_byte
    word_aligned = (addr / 8) * 8
    byte_offset = addr % 8
    if byte_offset < 0
        byte_offset = byte_offset + 8

    // Read current 8-byte word
    orig_word = ptrace_peek_text(pid, word_aligned)

    buf = malloc(8)
    mem_word_write(buf, 0, orig_word)
    mem_byte_write(buf, byte_offset, new_byte)
    updated_word = mem_word_read(buf, 0)
    free(buf, 8)

    return ptrace_poke_text(pid, word_aligned, updated_word)

// ── 7. CPU Hardware Register Introspection (PTRACE_GETREGS / SETREGS) ─────────

// WHY: Reads all 27 general, stack, and instruction pointer registers from CPU state.
fn ptrace_get_regs pid
    regs_buf = malloc(216)
    rc = ptrace_raw(PTRACE_GETREGS, pid, 0, regs_buf)
    if rc < 0
        free(regs_buf, 216)
        return 0

    regs = X86_64_Regs()
    regs.r15      = mem_word_read(regs_buf, 0)
    regs.r14      = mem_word_read(regs_buf, 1)
    regs.r13      = mem_word_read(regs_buf, 2)
    regs.r12      = mem_word_read(regs_buf, 3)
    regs.rbp      = mem_word_read(regs_buf, 4)
    regs.rbx      = mem_word_read(regs_buf, 5)
    regs.r11      = mem_word_read(regs_buf, 6)
    regs.r10      = mem_word_read(regs_buf, 7)
    regs.r9       = mem_word_read(regs_buf, 8)
    regs.r8       = mem_word_read(regs_buf, 9)
    regs.rax      = mem_word_read(regs_buf, 10)
    regs.rcx      = mem_word_read(regs_buf, 11)
    regs.rdx      = mem_word_read(regs_buf, 12)
    regs.rsi      = mem_word_read(regs_buf, 13)
    regs.rdi      = mem_word_read(regs_buf, 14)
    regs.orig_rax = mem_word_read(regs_buf, 15)
    regs.rip      = mem_word_read(regs_buf, 16)
    regs.cs       = mem_word_read(regs_buf, 17)
    regs.eflags   = mem_word_read(regs_buf, 18)
    regs.rsp      = mem_word_read(regs_buf, 19)
    regs.ss       = mem_word_read(regs_buf, 20)
    regs.fs_base  = mem_word_read(regs_buf, 21)
    regs.gs_base  = mem_word_read(regs_buf, 22)
    regs.ds       = mem_word_read(regs_buf, 23)
    regs.es       = mem_word_read(regs_buf, 24)
    regs.fs       = mem_word_read(regs_buf, 25)
    regs.gs       = mem_word_read(regs_buf, 26)

    free(regs_buf, 216)
    return regs

// WHY: Writes updated CPU registers back to the Linux kernel via PTRACE_SETREGS.
fn ptrace_set_regs pid regs
    regs_buf = malloc(216)
    mem_word_write(regs_buf, 0 * 8,  regs.r15)
    mem_word_write(regs_buf, 1 * 8,  regs.r14)
    mem_word_write(regs_buf, 2 * 8,  regs.r13)
    mem_word_write(regs_buf, 3 * 8,  regs.r12)
    mem_word_write(regs_buf, 4 * 8,  regs.rbp)
    mem_word_write(regs_buf, 5 * 8,  regs.rbx)
    mem_word_write(regs_buf, 6 * 8,  regs.r11)
    mem_word_write(regs_buf, 7 * 8,  regs.r10)
    mem_word_write(regs_buf, 8 * 8,  regs.r9)
    mem_word_write(regs_buf, 9 * 8,  regs.r8)
    mem_word_write(regs_buf, 10 * 8, regs.rax)
    mem_word_write(regs_buf, 11 * 8, regs.rcx)
    mem_word_write(regs_buf, 12 * 8, regs.rdx)
    mem_word_write(regs_buf, 13 * 8, regs.rsi)
    mem_word_write(regs_buf, 14 * 8, regs.rdi)
    mem_word_write(regs_buf, 15 * 8, regs.orig_rax)
    mem_word_write(regs_buf, 16 * 8, regs.rip)
    mem_word_write(regs_buf, 17 * 8, regs.cs)
    mem_word_write(regs_buf, 18 * 8, regs.eflags)
    mem_word_write(regs_buf, 19 * 8, regs.rsp)
    mem_word_write(regs_buf, 20 * 8, regs.ss)
    mem_word_write(regs_buf, 21 * 8, regs.fs_base)
    mem_word_write(regs_buf, 22 * 8, regs.gs_base)
    mem_word_write(regs_buf, 23 * 8, regs.ds)
    mem_word_write(regs_buf, 24 * 8, regs.es)
    mem_word_write(regs_buf, 25 * 8, regs.fs)
    mem_word_write(regs_buf, 26 * 8, regs.gs)

    rc = ptrace_raw(PTRACE_SETREGS, pid, 0, regs_buf)
    free(regs_buf, 216)
    return rc

// ── 8. Formatted Register Table Printer ───────────────────────────────────────

// WHY: Displays aligned, human-readable terminal table of CPU register values.
fn ptrace_dump_regs regs
    if regs == 0
        say "  ❌ Registers unavailable (target process not stopped)."
        return 0

    say "  ╔══════════════════════════════════════════════════════════════════════╗"
    say "  ║  x86_64 CPU REGISTER DUMP                                            ║"
    say "  ╠══════════════════════════════════════════════════════════════════════╣"
    say "  ║  %rax: " + ptrace_format_hex(regs.rax) + "  %rbx: " + ptrace_format_hex(regs.rbx) + "  ║"
    say "  ║  %rcx: " + ptrace_format_hex(regs.rcx) + "  %rdx: " + ptrace_format_hex(regs.rdx) + "  ║"
    say "  ║  %rsi: " + ptrace_format_hex(regs.rsi) + "  %rdi: " + ptrace_format_hex(regs.rdi) + "  ║"
    say "  ║  %rbp: " + ptrace_format_hex(regs.rbp) + "  %rsp: " + ptrace_format_hex(regs.rsp) + "  ║"
    say "  ║  %rip: " + ptrace_format_hex(regs.rip) + "  EFL : " + ptrace_format_hex(regs.eflags) + "  ║"
    say "  ║  %r8 : " + ptrace_format_hex(regs.r8)  + "  %r9 : " + ptrace_format_hex(regs.r9)  + "  ║"
    say "  ║  %r10: " + ptrace_format_hex(regs.r10) + "  %r11: " + ptrace_format_hex(regs.r11) + "  ║"
    say "  ║  %r12: " + ptrace_format_hex(regs.r12) + "  %r13: " + ptrace_format_hex(regs.r13) + "  ║"
    say "  ║  %r14: " + ptrace_format_hex(regs.r14) + "  %r15: " + ptrace_format_hex(regs.r15) + "  ║"
    say "  ╚══════════════════════════════════════════════════════════════════════╝"
    return 0
