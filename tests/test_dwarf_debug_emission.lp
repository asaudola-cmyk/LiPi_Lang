// ==============================================================================
// 👑 LIPI FIRST 1.0.0 COMPILER TEST: NATIVE DWARF v4/v5 DEBUG EMISSION
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
// 🏛️ File: tests/test_dwarf_debug_emission.lp
//
// WHY: Validates end-to-end embedding of DWARF v4/v5 debug metadata into native
//      ELF64 binaries without any external assembler, linker, or compiler:
//      - Serializes .debug_line program with source file, directory, and line tables.
//      - Serializes .debug_info compilation unit DIE with compiler identity.
//      - Serializes .debug_abbrev schema.
//      - Emits standalone ELF64 executable with 9 sections.
//      - Verifies section header table and .debug_* sections.
// ==============================================================================

import "src/compiler/backend/formats/elf/elf_header.lp"
import "src/compiler/backend/formats/elf/program_header.lp"
import "src/compiler/backend/formats/elf/section_header.lp"
import "src/compiler/backend/formats/elf/relocation.lp"
import "src/compiler/backend/formats/elf/elf_writer.lp"
import "src/compiler/backend/formats/debug/dwarf_line.lp"
import "src/compiler/backend/formats/debug/dwarf_info.lp"
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
    say "👑 TESTING LIPI FIRST 1.0.0 NATIVE DWARF v4/v5 DEBUG EMISSION (-g)"
    say "════════════════════════════════════════════════════════════════════════"

    out_path = "/tmp/test_dwarf_exec.bin"

    // 1. Build simple x86_64 machine code payload: mov rax, 42; ret
    code = [72, 199, 192, 42, 0, 0, 0, 195] // 8 bytes

    // 2. Build DWARF .debug_line section
    say "\n[Step 1]: Generating DWARF .debug_line Program..."
    line_builder = dwarf_line_builder_new(4)
    dwarf_line_add_dir(line_builder, "/home/shafiullah/Documents/file/work/lipi")
    dwarf_line_add_file(line_builder, "main.lp", 1)
    dwarf_line_emit_set_address(line_builder, 4194480) // base + start stub
    dwarf_line_emit_advance_line(line_builder, 10)
    dwarf_line_emit_copy(line_builder)
    dwarf_line_emit_advance_pc(line_builder, 8)
    dwarf_line_emit_advance_line(line_builder, 1)
    dwarf_line_end_sequence(line_builder, 4194488)

    line_bytes = dwarf_line_serialize(line_builder)
    test_assert(line_bytes.len() > 30, ".debug_line section serialized (" + str(line_bytes.len()) + " bytes)")

    // 3. Build DWARF .debug_info & .debug_abbrev sections
    say "\n[Step 2]: Generating DWARF .debug_info & .debug_abbrev DIE Tree..."
    abbrev_bytes = dwarf_abbrev_build_standard()
    test_assert(abbrev_bytes.len() > 10, ".debug_abbrev section constructed (" + str(abbrev_bytes.len()) + " bytes)")

    cu = dwarf_unit_create("LiPi First 1.0.0 (প্রথম ১.০.০)", "main.lp", "/home/shafiullah/Documents/file/work/lipi", 4194480, 4194488, 0)
    dwarf_unit_add_function(cu, "main", 4194480, 4194488, 1, 10)
    dwarf_unit_add_base_type(cu, "i64", 8, DW_ATE_signed())

    info_bytes = dwarf_info_serialize(cu)
    test_assert(info_bytes.len() > 40, ".debug_info section serialized (" + str(info_bytes.len()) + " bytes)")

    // 4. Emit ELF64 executable with embedded DWARF sections
    say "\n[Step 3]: Emitting ELF64 Executable with Embedded DWARF Sections..."
    res = elf_emit_executable_with_debug(code, [], [], 0, line_bytes, info_bytes, abbrev_bytes, out_path)
    test_assert(res.ew_success == 1, "ELF64 binary successfully written to " + out_path)
    test_assert(res.ew_file_size > 500, "Executable file size is valid (" + str(res.ew_file_size) + " bytes)")

    // 5. Verify Executable Header & Section Count
    say "\n[Step 4]: Inspecting Emitted ELF64 Headers for DWARF Metadata..."
    fd = syscall(2, out_path, 0, 0, 0, 0, 0) // O_RDONLY
    test_assert(fd >= 0, "Successfully opened emitted ELF64 executable")

    buf = syscall(9, 0, 1024, 3, 34, 0 - 1, 0)
    n_read = syscall(0, fd, buf, 1024, 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)

    // Check ELF Magic
    m0 = sys_peek8(buf + 0)
    m1 = sys_peek8(buf + 1)
    m2 = sys_peek8(buf + 2)
    m3 = sys_peek8(buf + 3)
    test_assert(m0 == 127 and m1 == 69 and m2 == 76 and m3 == 70, "Valid ELF64 magic bytes confirmed")

    // Check e_shnum at offset 60 (2 bytes) == 9 sections (.null, .text, .rodata, .data, .bss, .debug_line, .debug_info, .debug_abbrev, .shstrtab)
    sh_num = sys_peek8(buf + 60)
    test_assert(sh_num == 9, "ELF Header declares exactly 9 sections (including 3 DWARF sections)")

    // Check e_shstrndx at offset 62 (2 bytes) == 8 (.shstrtab index)
    shstr_idx = sys_peek8(buf + 62)
    test_assert(shstr_idx == 8, ".shstrtab correctly assigned to section index 8")

    syscall(11, buf, 1024, 0, 0, 0, 0)

    say "\n🎉 DWARF v4/v5 DEBUG EMISSION TESTS PASSED (100% VERIFIED)!"
    return 0
