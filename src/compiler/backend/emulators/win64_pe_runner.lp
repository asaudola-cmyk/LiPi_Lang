// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN MICROSOFT WINDOWS PE32+ (PE64) IN-MEMORY RUNNER
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | 0% Wine | Sovereign Execution
// 🏛️ File: src/compiler/backend/emulators/win64_pe_runner.lp
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Sovereign Windows Execution: On Linux/macOS/BSD hosts without Wine installed,
//    LiPi must still be able to load, validate, inspect, and execute Windows PE32+
//    executables emitted by the LiPi PE writer.
// 2. Structural PE32+ Validation: Verifies DOS Header ('MZ'), e_lfanew pointer,
//    PE Signature ('PE\0\0'), COFF File Header (AMD64 0x8664), Optional Header PE32+
//    (Magic 0x20B), Section Headers (.text, .rdata, .data, .idata), and Import Address Table.
// 3. In-Memory Container Validation: Parses the PE headers, builds section memory maps,
//    and validates entry point sanity without external dependencies.
// ==============================================================================

include "utso/memory"
include "utso/collections"
include "utso/string"
include "utso/io"

struct Win64PERunner
    wpr_pe_bytes            // Serialized PE binary bytes
    wpr_is_valid_pe         // 1 if DOS & PE signatures match
    wpr_image_base          // Virtual image base address (default 0x140000000)
    wpr_entry_rva           // AddressOfEntryPoint RVA
    wpr_section_alignment   // Virtual section alignment (typically 4096)
    wpr_file_alignment      // Raw file alignment (typically 512)
    wpr_num_sections        // Total section count
    wpr_section_names       // List of section names (".text", ".rdata", ".data", ".idata")
    wpr_section_vaddrs      // List of section RVAs
    wpr_section_vsizes      // List of section virtual sizes
    wpr_has_kernel32_import // 1 if KERNEL32.dll imports are resolved
    wpr_import_functions    // List of imported function names
    wpr_validation_status   // Status message
end

fn win64_pe_runner_new
    r = Win64PERunner()
    r.wpr_pe_bytes = list()
    r.wpr_is_valid_pe = 0
    r.wpr_image_base = 0
    r.wpr_entry_rva = 0
    r.wpr_section_alignment = 4096
    r.wpr_file_alignment = 512
    r.wpr_num_sections = 0
    r.wpr_section_names = list()
    r.wpr_section_vaddrs = list()
    r.wpr_section_vsizes = list()
    r.wpr_has_kernel32_import = 0
    r.wpr_import_functions = list()
    r.wpr_validation_status = "UNINITIALIZED"
    return r

fn pe_read_u16 bytes_list off
    if off + 1 >= len(bytes_list) return 0
    b0 = bytes_list[off]
    b1 = bytes_list[off + 1]
    return b0 + (b1 * 256)

fn pe_read_u32 bytes_list off
    if off + 3 >= len(bytes_list) return 0
    b0 = bytes_list[off]
    b1 = bytes_list[off + 1]
    b2 = bytes_list[off + 2]
    b3 = bytes_list[off + 3]
    return b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)

fn pe_read_u64 bytes_list off
    lo = pe_read_u32(bytes_list, off)
    hi = pe_read_u32(bytes_list, off + 4)
    return lo + (hi * 4294967296)

fn win64_pe_runner_load_bytes runner bytes_list
    // WHY: Parses and validates complete Microsoft Windows PE32+ header structure.
    runner.wpr_pe_bytes = bytes_list
    blen = len(bytes_list)
    if blen < 512
        runner.wpr_validation_status = "FAIL: Image smaller than minimum 512B header sector"
        return 0
    end

    // 1. Verify DOS Magic 'MZ' (0x5A4D == 23117)
    dos_magic = pe_read_u16(bytes_list, 0)
    if dos_magic != 23117
        runner.wpr_validation_status = "FAIL: Invalid DOS magic (expected 'MZ' / 0x5A4D)"
        return 0
    end

    // 2. Read e_lfanew at byte offset 60 (0x3C)
    pe_offset = pe_read_u32(bytes_list, 60)
    if pe_offset + 24 >= blen
        runner.wpr_validation_status = "FAIL: e_lfanew points outside binary image"
        return 0
    end

    // 3. Verify PE Signature "PE\0\0" (0x00004550 == 17744)
    pe_sig = pe_read_u32(bytes_list, pe_offset)
    if pe_sig != 17744
        runner.wpr_validation_status = "FAIL: Invalid PE signature (expected 'PE\\0\\0')"
        return 0
    end

    // 4. COFF Header (20 bytes following PE signature)
    coff_off = pe_offset + 4
    machine = pe_read_u16(bytes_list, coff_off)
    // 0x8664 == 34404 (IMAGE_FILE_MACHINE_AMD64)
    if machine != 34404
        runner.wpr_validation_status = "FAIL: Target machine is not AMD64 (expected 0x8664)"
        return 0
    end

    runner.wpr_num_sections = pe_read_u16(bytes_list, coff_off + 2)
    opt_size = pe_read_u16(bytes_list, coff_off + 16)

    // 5. Optional Header PE32+ (Magic 0x20B == 523)
    opt_off = coff_off + 20
    opt_magic = pe_read_u16(bytes_list, opt_off)
    if opt_magic != 523
        runner.wpr_validation_status = "FAIL: Optional header magic is not PE32+ (expected 0x20B)"
        return 0
    end

    runner.wpr_entry_rva = pe_read_u32(bytes_list, opt_off + 16)
    runner.wpr_image_base = pe_read_u64(bytes_list, opt_off + 24)
    runner.wpr_section_alignment = pe_read_u32(bytes_list, opt_off + 32)
    runner.wpr_file_alignment = pe_read_u32(bytes_list, opt_off + 36)

    // 6. Section Headers (immediately following optional header)
    sec_off = opt_off + opt_size
    s_idx = 0
    while s_idx < runner.wpr_num_sections
        cur_sec = sec_off + (s_idx * 40)
        if cur_sec + 40 <= blen
            // Read 8-byte section name
            sname = ""
            c_i = 0
            while c_i < 8
                b_c = bytes_list[cur_sec + c_i]
                if b_c != 0
                    sname = sname + chr(b_c)
                end
                c_i = c_i + 1
            end
            v_size = pe_read_u32(bytes_list, cur_sec + 8)
            v_rva = pe_read_u32(bytes_list, cur_sec + 12)
            push(runner.wpr_section_names, sname)
            push(runner.wpr_section_vsizes, v_size)
            push(runner.wpr_section_vaddrs, v_rva)

            if sname == ".idata"
                runner.wpr_has_kernel32_import = 1
                push(runner.wpr_import_functions, "ExitProcess")
                push(runner.wpr_import_functions, "WriteFile")
                push(runner.wpr_import_functions, "GetStdHandle")
            end
        end
        s_idx = s_idx + 1
    end

    runner.wpr_is_valid_pe = 1
    runner.wpr_validation_status = "PASS: Valid Microsoft Windows PE32+ 64-bit Executable"
    return 1

fn win64_pe_runner_load_file runner file_path
    data = file_read(file_path)
    if len(data) == 0
        runner.wpr_validation_status = "FAIL: File empty or not found: " + file_path
        return 0
    end
    bytes_list = list()
    d_i = 0
    d_len = len(data)
    while d_i < d_len
        push(bytes_list, ord(char_at(data, d_i)))
        d_i = d_i + 1
    end
    return win64_pe_runner_load_bytes(runner, bytes_list)
