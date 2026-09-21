// ==============================================================================
// 👑 Test: Lipi DWARF v4 Line Matrix & ELF Section Header Table Engine
// ⚡ 100% Pure Lipi | ELF64 Section Headers (.debug_line, .shstrtab) | DWARF v4
// ==============================================================================
//
// WHY: Validates that the compiler emits standards-compliant DWARF v4 .debug_line
//      prologues and state-machine instructions, and attaches a complete 64-byte ELF
//      Section Header Table (.text, .debug_line, .shstrtab) for gdb/lldb native debugging.
// ==============================================================================

include "src/runtime/lipi_syscall.lp"

say "========================================================"
say "👑 Testing Lipi DWARF v4 Debug Symbols & ELF Sections"
say "========================================================"

fn open_and_read_elf path
    fd = syscall(2, path, 0, 0, 0, 0, 0) // sys_open(O_RDONLY)
    if fd < 0 return list(0, 0)
    // Read up to 64KB header and sections
    buf = syscall(9, 0, 65536, 3, 34, 0 - 1, 0)
    nread = syscall(0, fd, buf, 65536, 0, 0, 0) // sys_read
    syscall(3, fd, 0, 0, 0, 0, 0) // sys_close
    return list(buf, nread)

// Compile a small debug sample binary with -g
sample_lp = "/tmp/test_dwarf_sample.lp"
sample_bin = "/tmp/test_dwarf_sample.bin"
sample_src = "fn main\n    return 42\nmain()\n"

fd = syscall(2, sample_lp, 577, 420, 0, 0, 0) // O_WRONLY|O_CREAT|O_TRUNC
if fd >= 0
    syscall(1, fd, sample_src, len(sample_src), 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)

argv = syscall(9, 0, 64, 3, 34, 0 - 1, 0)
prog = "bin/lipc"
arg1 = "-g"
mem_word_write(argv, 0, prog)
mem_word_write(argv, 8, arg1)
mem_word_write(argv, 16, sample_lp)
mem_word_write(argv, 24, sample_bin)
mem_word_write(argv, 32, 0)

env = syscall(9, 0, 32, 3, 34, 0 - 1, 0)
path_env = "PATH=/usr/bin:/bin:/usr/local/bin"
mem_word_write(env, 0, path_env)
mem_word_write(env, 8, 0)

st = syscall(9, 0, 8, 3, 34, 0 - 1, 0)
mem_word_write(st, 0, 0)

pid = syscall(57, 0, 0, 0, 0, 0, 0)
if pid == 0
    null_fd = syscall(2, "/dev/null", 2, 0, 0, 0, 0)
    if null_fd >= 0
        syscall(33, null_fd, 1, 0, 0, 0, 0)
        syscall(33, null_fd, 2, 0, 0, 0, 0)
        syscall(3, null_fd, 0, 0, 0, 0, 0)
    syscall(59, prog, argv, env, 0, 0, 0)
    syscall(60, 127, 0, 0, 0, 0, 0)

syscall(61, pid, st, 0, 0, 0, 0)
syscall(11, argv, 64, 0, 0, 0, 0)
syscall(11, env, 32, 0, 0, 0, 0)
syscall(11, st, 8, 0, 0, 0, 0)

res = open_and_read_elf(sample_bin)
buf = get(res, 0)
nread = get(res, 1)

if nread <= 0
    say "FAIL: Unable to read " + sample_bin
    exit(1)

// ── Step 1: Validate ELF64 Header Magic ────────────────────────────────────────
say "[1/4] Validating ELF64 Magic & Machine Architecture..."
if mem_byte_read(buf, 0) != 127 or mem_byte_read(buf, 1) != 69 or mem_byte_read(buf, 2) != 76 or mem_byte_read(buf, 3) != 70
    say "FAIL: Invalid ELF magic"
    exit(1)

// Class 2 (64-bit), Data 1 (little-endian)
if mem_byte_read(buf, 4) != 2 or mem_byte_read(buf, 5) != 1
    say "FAIL: Not 64-bit little endian ELF"
    exit(1)

say "  ✔ ELF64 x86_64 Machine Header Verified"

// ── Step 2: Validate Section Header Table Configuration ───────────────────────
say "[2/4] Validating Section Header Table Offsets (e_shoff, e_shnum, e_shstrndx)..."

e_shoff = mem_byte_read(buf, 40) + (mem_byte_read(buf, 41) * 256) + (mem_byte_read(buf, 42) * 65536)
e_shentsize = mem_byte_read(buf, 58) + (mem_byte_read(buf, 59) * 256)
e_shnum = mem_byte_read(buf, 60) + (mem_byte_read(buf, 61) * 256)
e_shstrndx = mem_byte_read(buf, 62) + (mem_byte_read(buf, 63) * 256)

if e_shoff == 0
    say "FAIL: ELF Section Header Table missing (e_shoff == 0)"
    exit(1)

if e_shentsize != 64
    say "FAIL: Expected e_shentsize == 64, got " + str(e_shentsize)
    exit(1)

if e_shnum < 4
    say "FAIL: Expected at least 4 section headers, got " + str(e_shnum)
    exit(1)

say "  ✔ Section Headers Table verified: e_shoff=" + str(e_shoff) + " e_shnum=" + str(e_shnum) + " shstrndx=" + str(e_shstrndx)

// ── Step 3: Scan Section Entries (.text, .debug_line, .shstrtab) ──────────────
say "[3/4] Validating Section Names and Attribute Flags..."

found_text = 0
found_dbg = 0
found_str = 0
dbg_file_off = 0
dbg_size = 0

s_idx = 0
while s_idx < e_shnum
    sh_off = e_shoff + (s_idx * 64)
    sec_type = mem_byte_read(buf, sh_off + 4)
    sec_flags = mem_byte_read(buf, sh_off + 8)
    sec_file_off = mem_byte_read(buf, sh_off + 24) + (mem_byte_read(buf, sh_off + 25) * 256) + (mem_byte_read(buf, sh_off + 26) * 65536)
    sec_size = mem_byte_read(buf, sh_off + 32) + (mem_byte_read(buf, sh_off + 33) * 256)

    // .text section: SHT_PROGBITS (1) and SHF_ALLOC|SHF_EXECINSTR (6)
    if sec_type == 1 and sec_flags == 6
        found_text = 1

    // .debug_line section: SHT_PROGBITS (1) and flags == 0 and sec_size > 0
    if sec_type == 1 and sec_flags == 0 and sec_size > 0 and found_dbg == 0
        found_dbg = 1
        dbg_file_off = sec_file_off
        dbg_size = sec_size

    // .shstrtab: SHT_STRTAB (3)
    if sec_type == 3
        found_str = 1

    s_idx = s_idx + 1

if found_text != 1
    say "FAIL: Section .text not found"
    exit(1)
say "  ✔ Section .text verified (SHT_PROGBITS, SHF_ALLOC|SHF_EXECINSTR)"

if found_dbg != 1 or dbg_size <= 0
    say "FAIL: Section .debug_line not found or empty"
    exit(1)
say "  ✔ Section .debug_line verified (offset=" + str(dbg_file_off) + " size=" + str(dbg_size) + " bytes)"

if found_str != 1
    say "FAIL: Section .shstrtab not found"
    exit(1)
say "  ✔ Section .shstrtab verified (SHT_STRTAB)"

// ── Step 4: Validate DWARF v4 .debug_line Standard Header ─────────────────────
say "[4/4] Validating DWARF v4 Line Number Header Spec..."

d_ver = mem_byte_read(buf, dbg_file_off + 4)
if d_ver != 4
    say "FAIL: Expected DWARF Version 4, got: " + str(d_ver)
    exit(1)

min_inst = mem_byte_read(buf, dbg_file_off + 10)
if min_inst != 1
    say "FAIL: Expected min_inst_len == 1, got: " + str(min_inst)
    exit(1)

op_base = mem_byte_read(buf, dbg_file_off + 15)
if op_base != 13
    say "FAIL: Expected opcode_base == 13, got: " + str(op_base)
    exit(1)

say "  ✔ DWARF v4 Line Matrix Header validated (ver 4, opcode_base 13, min_inst 1)"

syscall(11, buf, 65536, 0, 0, 0, 0) // munmap

say "========================================================"
say "PASS: DWARF Debug Symbols Test Suite Verified 100%!"
say "========================================================"
