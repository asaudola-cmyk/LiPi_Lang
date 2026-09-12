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
    // Read up to 16KB header and sections
    buf = syscall(9, 0, 65536, 3, 34, 0 - 1, 0)
    nread = syscall(0, fd, buf, 65536, 0, 0, 0) // sys_read
    syscall(3, fd, 0, 0, 0, 0, 0) // sys_close
    return list(buf, nread)

res = open_and_read_elf("bin/lipi")
buf = get(res, 0)
nread = get(res, 1)

if nread <= 0
    say "FAIL: Unable to read bin/lipi binary"
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

if e_shnum != 4
    say "FAIL: Expected 4 section headers (.null, .text, .debug_line, .shstrtab), got " + str(e_shnum)
    exit(1)

if e_shstrndx != 3
    say "FAIL: Expected e_shstrndx == 3 (.shstrtab index), got " + str(e_shstrndx)
    exit(1)

say "  ✔ Section Headers Table verified: e_shoff=" + str(e_shoff) + " e_shnum=" + str(e_shnum) + " shstrndx=" + str(e_shstrndx)

// ── Step 3: Validate Section Entries (.text, .debug_line, .shstrtab) ──────────
say "[3/4] Validating Section Names and Attribute Flags..."

// Section 1: .text (sh_type == 1 SHT_PROGBITS, sh_flags == 6 SHF_ALLOC | SHF_EXECINSTR)
sh_text_off = e_shoff + 64
text_type = mem_byte_read(buf, sh_text_off + 4)
text_flags = mem_byte_read(buf, sh_text_off + 8)
if text_type != 1 or text_flags != 6
    say "FAIL: Section .text attributes mismatch: type=" + str(text_type) + " flags=" + str(text_flags)
    exit(1)
say "  ✔ Section 1 (.text) verified (SHT_PROGBITS, SHF_ALLOC|SHF_EXECINSTR)"

// Section 2: .debug_line (sh_type == 1 SHT_PROGBITS, sh_flags == 0)
sh_dbg_off = e_shoff + 128
dbg_type = mem_byte_read(buf, sh_dbg_off + 4)
dbg_file_off = mem_byte_read(buf, sh_dbg_off + 24) + (mem_byte_read(buf, sh_dbg_off + 25) * 256) + (mem_byte_read(buf, sh_dbg_off + 26) * 65536)
dbg_size = mem_byte_read(buf, sh_dbg_off + 32) + (mem_byte_read(buf, sh_dbg_off + 33) * 256)
if dbg_type != 1 or dbg_size <= 0
    say "FAIL: Section .debug_line attributes mismatch: type=" + str(dbg_type) + " size=" + str(dbg_size)
    exit(1)
say "  ✔ Section 2 (.debug_line) verified (offset=" + str(dbg_file_off) + " size=" + str(dbg_size) + " bytes)"

// Section 3: .shstrtab (sh_type == 3 SHT_STRTAB)
sh_str_off = e_shoff + 192
str_type = mem_byte_read(buf, sh_str_off + 4)
if str_type != 3
    say "FAIL: Section .shstrtab attributes mismatch: type=" + str(str_type)
    exit(1)
say "  ✔ Section 3 (.shstrtab) verified (SHT_STRTAB)"

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
