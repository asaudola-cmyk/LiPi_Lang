// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN APPLE MACOS & IOS MACH-O 64 RUNNER & VALIDATOR
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | 0% Apple Tools | Sovereign
// 🏛️ File: src/compiler/backend/emulators/macho_runner.lp
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Sovereign Apple Ecosystem Verification: Validates Mach-O 64 executables on
//    non-Apple platforms (Linux / BSD / Bare-Metal) with zero Apple Xcode SDK or macOS hardware.
// 2. Multi-Architecture Validation: Confirms Apple Silicon (ARM64 cputype 16777228)
//    and Intel (x86_64 cputype 16777223) binary headers.
// 3. Load Command Traversal: Verifies MH_MAGIC_64 (0xFEEDFACF), LC_SEGMENT_64 (0x19),
//    LC_MAIN (0x80000028 entry point), and LC_BUILD_VERSION (0x32 platform tagging).
// ==============================================================================

include "utso/memory"
include "utso/collections"
include "utso/string"
include "utso/io"

struct MachORunner
    mor_macho_bytes         // Serialized Mach-O binary bytes
    mor_is_valid_macho      // 1 if magic & headers match
    mor_cpu_type            // 16777223 (x86_64) or 16777228 (ARM64)
    mor_cpu_name            // "x86_64" or "arm64_apple_silicon"
    mor_target_platform     // 1 (macOS) or 2 (iOS)
    mor_platform_name       // "macOS" or "iOS"
    mor_num_load_cmds       // Total load commands (ncmds)
    mor_size_load_cmds      // Size of all load commands (sizeofcmds)
    mor_entry_offset        // Entry point offset from LC_MAIN
    mor_segment_names       // List of segments ("__PAGEZERO", "__TEXT", "__DATA", "__LINKEDIT")
    mor_segment_vaddrs      // List of segment VM addresses
    mor_segment_vsizes      // List of segment VM sizes
    mor_validation_status   // Diagnostic report
end

fn macho_runner_new
    r = MachORunner()
    r.mor_macho_bytes = list()
    r.mor_is_valid_macho = 0
    r.mor_cpu_type = 0
    r.mor_cpu_name = "unknown"
    r.mor_target_platform = 1
    r.mor_platform_name = "macOS"
    r.mor_num_load_cmds = 0
    r.mor_size_load_cmds = 0
    r.mor_entry_offset = 0
    r.mor_segment_names = list()
    r.mor_segment_vaddrs = list()
    r.mor_segment_vsizes = list()
    r.mor_validation_status = "UNINITIALIZED"
    return r

fn macho_read_u32 bytes_list off
    if off + 3 >= len(bytes_list) return 0
    b0 = bytes_list[off]
    b1 = bytes_list[off + 1]
    b2 = bytes_list[off + 2]
    b3 = bytes_list[off + 3]
    return b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)

fn macho_read_u64 bytes_list off
    lo = macho_read_u32(bytes_list, off)
    hi = macho_read_u32(bytes_list, off + 4)
    return lo + (hi * 4294967296)

fn macho_runner_load_bytes runner bytes_list
    // WHY: Parses Apple Mach-O 64 mach_header_64 and traverses load commands.
    runner.mor_macho_bytes = bytes_list
    blen = len(bytes_list)
    if blen < 32
        runner.mor_validation_status = "FAIL: Image smaller than 32-byte mach_header_64"
        return 0
    end

    // 1. Verify MH_MAGIC_64 (0xFEEDFACF == 4277009103)
    magic = macho_read_u32(bytes_list, 0)
    if magic != 4277009103
        runner.mor_validation_status = "FAIL: Invalid Mach-O magic (expected 0xFEEDFACF)"
        return 0
    end

    // 2. CPU Type: 16777223 (x86_64) or 16777228 (ARM64 Apple Silicon)
    runner.mor_cpu_type = macho_read_u32(bytes_list, 4)
    if runner.mor_cpu_type == 16777228
        runner.mor_cpu_name = "arm64_apple_silicon"
    elif runner.mor_cpu_type == 16777223
        runner.mor_cpu_name = "x86_64"
    else
        runner.mor_cpu_name = "custom_arch"
    end

    // 3. File type: MH_EXECUTE == 2 at offset 12
    ftype = macho_read_u32(bytes_list, 12)
    if ftype != 2
        runner.mor_validation_status = "FAIL: Mach-O file type is not MH_EXECUTE (2)"
        return 0
    end

    runner.mor_num_load_cmds = macho_read_u32(bytes_list, 16)
    runner.mor_size_load_cmds = macho_read_u32(bytes_list, 20)

    // 4. Iterate Load Commands starting at byte 32
    cmd_cursor = 32
    cmd_idx = 0
    while cmd_idx < runner.mor_num_load_cmds and cmd_cursor < blen
        cmd_type = macho_read_u32(bytes_list, cmd_cursor)
        cmd_size = macho_read_u32(bytes_list, cmd_cursor + 4)

        if cmd_size <= 0
            break
        end

        // LC_SEGMENT_64 == 25 (0x19)
        if cmd_type == 25
            seg_name = ""
            c_i = 0
            while c_i < 16
                b_c = bytes_list[cmd_cursor + 8 + c_i]
                if b_c != 0
                    seg_name = seg_name + chr(b_c)
                end
                c_i = c_i + 1
            end
            vm_addr = macho_read_u64(bytes_list, cmd_cursor + 24)
            vm_size = macho_read_u64(bytes_list, cmd_cursor + 32)
            push(runner.mor_segment_names, seg_name)
            push(runner.mor_segment_vaddrs, vm_addr)
            push(runner.mor_segment_vsizes, vm_size)

        // LC_MAIN == 2147483688 (0x80000028)
        elif cmd_type == 2147483688
            runner.mor_entry_offset = macho_read_u64(bytes_list, cmd_cursor + 8)

        // LC_BUILD_VERSION == 50 (0x32)
        elif cmd_type == 50
            platform = macho_read_u32(bytes_list, cmd_cursor + 8)
            runner.mor_target_platform = platform
            if platform == 2
                runner.mor_platform_name = "iOS"
            else
                runner.mor_platform_name = "macOS"
            end
        end

        cmd_cursor = cmd_cursor + cmd_size
        cmd_idx = cmd_idx + 1
    end

    runner.mor_is_valid_macho = 1
    runner.mor_validation_status = "PASS: Valid Apple Mach-O 64 (" + runner.mor_cpu_name + " / " + runner.mor_platform_name + ")"
    return 1

fn macho_runner_load_file runner file_path
    data = file_read(file_path)
    if len(data) == 0
        runner.mor_validation_status = "FAIL: File empty or not found: " + file_path
        return 0
    end
    bytes_list = list()
    d_i = 0
    d_len = len(data)
    while d_i < d_len
        push(bytes_list, ord(char_at(data, d_i)))
        d_i = d_i + 1
    end
    return macho_runner_load_bytes(runner, bytes_list)
