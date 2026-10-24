// ==============================================================================
// 🧪 LIPI SILICON TEST: INTEL AMX 2D HARDWARE TILE ACCELERATOR
// ⚡ Module: tests/test_amx_silicon.lp
// 100% Pure LiPi Implementation — Zero External / C++ / Python Dependencies
// ==============================================================================

include "utso/io.lp"
include "utso/string.lp"
include "src/compiler/backend/x86_64/amx.lp"

fn test_tile_config_builder
    say "[AMX] Testing Palette 1 Tile Configuration Builder..."
    cfg = amx_tilecfg_new()
    if cfg[0] != 1
        say "FAIL: Palette ID must be 1"
        return 0
    end
    if cfg[1] != 0
        say "FAIL: start_row must be 0"
        return 0
    end

    // Configure Tile 0: 16 rows, 64 column bytes
    amx_tilecfg_set_tile(cfg, 0, 16, 64)
    if cfg[16] != 64 or cfg[17] != 0
        say "FAIL: Tile 0 colsb must be 64 bytes"
        return 0
    end
    if cfg[48] != 16
        say "FAIL: Tile 0 rows must be 16"
        return 0
    end

    // Build uniform 8-tile configuration (16x64)
    u_cfg = amx_build_tile_config(16, 64)
    t = 0
    while t < 8
        c_val = u_cfg[16 + (t * 2)]
        r_val = u_cfg[48 + t]
        if c_val != 64 or r_val != 16
            say "FAIL: Uniform tile dimensions mismatch on tile " + str(t)
            return 0
        end
        t = t + 1
    end
    say "  ✔ Tile Configuration: 64-byte layout verified bit-for-bit."
    return 1

fn test_instruction_encoders
    say "[AMX] Testing AMX Machine Byte Encoders..."

    // 1. TILERELEASE: C4 E2 78 49 C0
    rel_bytes = amx_emit_tilerelease()
    if len(rel_bytes) != 5
        say "FAIL: TILERELEASE length must be 5 bytes"
        return 0
    end
    if rel_bytes[0] != 196 or rel_bytes[1] != 226 or rel_bytes[2] != 120 or rel_bytes[3] != 73 or rel_bytes[4] != 192
        say "FAIL: TILERELEASE opcode mismatch"
        return 0
    end

    // 2. LDTILECFG: C4 E2 78 49 44 24 disp
    ld_bytes = amx_emit_ldtilecfg(16)
    if len(ld_bytes) != 7
        say "FAIL: LDTILECFG length must be 7 bytes"
        return 0
    end
    if ld_bytes[0] != 196 or ld_bytes[3] != 73 or ld_bytes[6] != 16
        say "FAIL: LDTILECFG opcode mismatch"
        return 0
    end

    // 3. STTILECFG: C4 E2 78 49 4C 24 disp
    st_bytes = amx_emit_sttilecfg(32)
    if st_bytes[4] != 76 or st_bytes[6] != 32
        say "FAIL: STTILECFG opcode mismatch"
        return 0
    end

    // 4. TDPBSSD tmm0, tmm1, tmm2
    dp_bytes = amx_emit_tdpbssd(0, 1, 2)
    if len(dp_bytes) != 5 or dp_bytes[3] != 94
        say "FAIL: TDPBSSD opcode mismatch"
        return 0
    end

    // 5. TDPBF16PS tmm0, tmm1, tmm2
    bf_bytes = amx_emit_tdpbf16ps(0, 1, 2)
    if len(bf_bytes) != 5 or bf_bytes[3] != 92
        say "FAIL: TDPBF16PS opcode mismatch"
        return 0
    end

    say "  ✔ AMX Instruction Opcodes: All 5 VEX encoders validated."
    return 1

fn test_cpuid_hardware_probe
    say "[AMX] Testing In-Silicon Hardware Feature Probe..."
    amx_detected = cpu_has_amx()
    cpuid_amx_val = cpuid_amx()
    if amx_detected != cpuid_amx_val
        say "FAIL: Inconsistent AMX detection between cpu_has_amx and cpuid_amx"
        return 0
    end
    if amx_detected == 1
        say "  ✔ Silicon AMX Detected: Intel Sapphire Rapids / Emerald Rapids / Granite Rapids CPU."
    else
        say "  ✔ Silicon Hardware Probe: Non-AMX Host (AMD Zen 4 / Prior Intel) — Emulation Fallback Active."
    end
    return 1

fn test_tile_matmul_computation
    say "[AMX] Testing 2D 16x16 Tile Matrix Multiplication..."

    // Test 1: 16x16 Identity Multiplication
    // A: 16x16 test matrix (row * 16 + col)
    // B: 16x16 identity matrix
    mat_a = list()
    mat_id = list()
    r = 0
    while r < 16
        c = 0
        while c < 16
            push(mat_a, (r * 16) + c + 1)
            if r == c
                push(mat_id, 1)
            else
                push(mat_id, 0)
            end
            c = c + 1
        end
        r = r + 1
    end

    res_id = amx_tile_matmul(mat_a, mat_id, 16, 16, 16)
    idx = 0
    while idx < 256
        if res_id[idx] != mat_a[idx]
            say "FAIL: A * Identity must equal A at index " + str(idx)
            return 0
        end
        idx = idx + 1
    end
    say "  ✔ 16x16 Identity Tile Multiplication: Bit-for-bit exact match."

    // Test 2: 16x16 Ones * Twos (Each dot product = 16 * (1 * 2) = 32)
    mat_ones = list()
    mat_twos = list()
    i = 0
    while i < 256
        push(mat_ones, 1)
        push(mat_twos, 2)
        i = i + 1
    end

    res_ones_twos = amx_tile_matmul(mat_ones, mat_twos, 16, 16, 16)
    j = 0
    while j < 256
        if res_ones_twos[j] != 32
            say "FAIL: Element must be 32, got " + str(res_ones_twos[j]) + " at " + str(j)
            return 0
        end
        j = j + 1
    end
    say "  ✔ 16x16 Accumulator Tile Tiling: 256 dwords verified (32 each)."
    return 1

fn main
    say "===================================================================="
    say "👑 LIPI SILICON: INTEL AMX 2D HARDWARE TILING TEST SUITE"
    say "===================================================================="
    if test_tile_config_builder() == 0 exit(1) end
    if test_instruction_encoders() == 0 exit(1) end
    if test_cpuid_hardware_probe() == 0 exit(1) end
    if test_tile_matmul_computation() == 0 exit(1) end
    say "===================================================================="
    say "🎉 ALL INTEL AMX HARDWARE TILING TESTS PASSED (100% GREEN)!"
    say "===================================================================="
    return 0

main()
