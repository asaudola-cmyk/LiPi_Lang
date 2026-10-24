// ==============================================================================
// 👑 LIPI UNIVERSAL ARCHITECTURE — INTEL AMX (2D TILE MATRIX) ACCELERATOR
// ⚡ Module: src/compiler/backend/x86_64/amx.lp
// 🏛️ Architecture: Intel Advanced Matrix Extensions (AMX) Silicon Tiling Engine
// 100% Pure LiPi Implementation — Zero External / C++ / Python Dependencies
// Features: Intel AMX Tile Registers (TMM0-TMM7), Palette 1 Configuration,
// LDTILECFG, STTILECFG, TILERELEASE, TILELOADD, TILESTORED, TDPBSSD & TDPBF16PS
// ==============================================================================

include "utso/memory.lp"
include "utso/string.lp"

// ── 1. AMX Tile Architecture Constants ────────────────────────────────────────

AMX_PALETTE_1          = 1   // Palette 1: 8 Tile Registers, up to 16 rows x 64 bytes
AMX_TILES_COUNT        = 8   // TMM0 through TMM7
AMX_MAX_ROWS           = 16  // Maximum rows per tile
AMX_MAX_COLS_BYTES     = 64  // Maximum column bytes per tile (64 bytes = 16x 32-bit dwords)
AMX_TILECFG_SIZE_BYTES = 64  // 64-byte hardware tile configuration structure

// AMX Tile Register IDs
TMM0 = 0
TMM1 = 1
TMM2 = 2
TMM3 = 3
TMM4 = 4
TMM5 = 5
TMM6 = 6
TMM7 = 7

// ── 2. AMX 64-Byte Tile Configuration Builder ─────────────────────────────────
//
// Hardware Layout for Palette 1 (64 bytes total):
//   Byte 0:       palette_id (1 byte = 1)
//   Byte 1:       start_row  (1 byte = 0)
//   Bytes 2..15:  reserved   (14 bytes = 0)
//   Bytes 16..31: colsb[0..7] (8 x 2-byte unsigned 16-bit column byte widths)
//   Bytes 32..47: reserved   (16 bytes = 0)
//   Bytes 48..55: rows[0..7]  (8 x 1-byte row counts)
//   Bytes 56..63: reserved   (8 bytes = 0)

fn amx_tilecfg_new
    // WHY: Allocates a zero-initialized 64-byte tile configuration structure
    cfg = list()
    i = 0
    while i < 64
        push(cfg, 0)
        i = i + 1
    end
    // Set palette ID = 1 (Palette 1)
    cfg[0] = AMX_PALETTE_1
    cfg[1] = 0 // start_row = 0
    return cfg

fn amx_tilecfg_set_tile cfg tile_id num_rows num_cols_bytes
    // WHY: Configures dimensions for a specific tile register (TMM0..TMM7)
    if tile_id < 0 or tile_id >= AMX_TILES_COUNT
        return 0
    end
    if num_rows > AMX_MAX_ROWS
        num_rows = AMX_MAX_ROWS
    end
    if num_cols_bytes > AMX_MAX_COLS_BYTES
        num_cols_bytes = AMX_MAX_COLS_BYTES
    end

    // Set colsb (2 bytes per tile, starting at offset 16 + tile_id * 2)
    cols_off = 16 + (tile_id * 2)
    cfg[cols_off] = num_cols_bytes & 255
    cfg[cols_off + 1] = (num_cols_bytes / 256) & 255

    // Set rows (1 byte per tile, starting at offset 48 + tile_id)
    rows_off = 48 + tile_id
    cfg[rows_off] = num_rows & 255
    return 1

fn amx_build_tile_config num_rows num_cols_bytes
    // WHY: Prepares a complete 8-tile uniform configuration for 16x64 tile tiling
    cfg = amx_tilecfg_new()
    t = 0
    while t < AMX_TILES_COUNT
        amx_tilecfg_set_tile(cfg, t, num_rows, num_cols_bytes)
        t = t + 1
    end
    return cfg

// ── 3. AMX Machine Byte Instruction Emitters ─────────────────────────────────

// LDTILECFG [base + disp32]
// VEX.LZ.0F38.W0 49 /0
fn amx_emit_ldtilecfg disp32
    // C4 E2 78 49 44 24 disp8 (or disp32)
    bytes = list()
    push(bytes, 196) // 0xC4 (3-byte VEX)
    push(bytes, 226) // 0xE2 (map 0F38, ~R=1, ~X=1, ~B=1)
    push(bytes, 120) // 0x78 (W=0, vvvv=0, L=0, pp=none)
    push(bytes, 73)  // 0x49 (LDTILECFG opcode)
    // ModRM: [rsp + disp] -> Mod=01 (disp8) or Mod=10 (disp32), reg=000 (/0), rm=100 (SIB)
    push(bytes, 68)  // ModRM = 0x44 [rsp + disp8]
    push(bytes, 36)  // SIB = 0x24 (rsp, no index)
    push(bytes, disp32 & 255)
    return bytes

// STTILECFG [base + disp32]
// VEX.LZ.0F38.W0 49 /1
fn amx_emit_sttilecfg disp32
    bytes = list()
    push(bytes, 196) // 0xC4
    push(bytes, 226) // 0xE2
    push(bytes, 120) // 0x78
    push(bytes, 73)  // 0x49
    // ModRM: reg=001 (/1) -> 0x4C [rsp + disp8]
    push(bytes, 76)  // ModRM = 0x4C
    push(bytes, 36)  // SIB = 0x24
    push(bytes, disp32 & 255)
    return bytes

// TILERELEASE
// VEX.128.0F38.W0 49 C0
fn amx_emit_tilerelease
    // Clears tile state and resets CPU to palette 0
    bytes = list()
    push(bytes, 196) // 0xC4
    push(bytes, 226) // 0xE2
    push(bytes, 120) // 0x78
    push(bytes, 73)  // 0x49
    push(bytes, 192) // 0xC0 (ModRM = 11 000 000)
    return bytes

// TDPBSSD tmm_dst, tmm_src1, tmm_src2
// VEX.128.F2.0F38.W0 5E /r
// Signed 8-bit integer dot product with 32-bit accumulation into dst
fn amx_emit_tdpbssd dst_tmm src1_tmm src2_tmm
    bytes = list()
    push(bytes, 196) // 0xC4
    push(bytes, 226) // 0xE2
    // Byte 2: W=0, ~vvvv = 15 - src1_tmm, L=0, pp=F2 (3)
    inv_v = 15 - (src1_tmm % 8)
    b2 = (inv_v * 8) + 3 // 0x7B for src1=0
    push(bytes, b2)
    push(bytes, 94)  // 0x5E (TDPBSSD opcode)
    // ModRM: 11 [dst:3] [src2:3]
    modrm = 192 + ((dst_tmm % 8) * 8) + (src2_tmm % 8)
    push(bytes, modrm)
    return bytes

// TDPBF16PS tmm_dst, tmm_src1, tmm_src2
// VEX.128.F3.0F38.W0 5C /r
// Bfloat16 dot product with 32-bit single-precision float accumulation
fn amx_emit_tdpbf16ps dst_tmm src1_tmm src2_tmm
    bytes = list()
    push(bytes, 196) // 0xC4
    push(bytes, 226) // 0xE2
    inv_v = 15 - (src1_tmm % 8)
    b2 = (inv_v * 8) + 2 // pp=F3 (2)
    push(bytes, b2)
    push(bytes, 92)  // 0x5C (TDPBF16PS opcode)
    modrm = 192 + ((dst_tmm % 8) * 8) + (src2_tmm % 8)
    push(bytes, modrm)
    return bytes

// ── 4. Hardware AMX Detection via CPUID & XCR0 ────────────────────────────────

fn amx_detect_hardware
    // WHY: In-silicon capability discovery. Checks both CPUID leaf 7 and OS XCR0 state.
    // If the compiler built-in `cpu_has_amx()` is available, call it.
    // On systems without AMX (e.g. Zen 4, older Intel), returns 0 gracefully.
    return cpu_has_amx()

// ── 5. AMX 2D 16x16 Tiled GEMM Engine ─────────────────────────────────────────

// Computes C = A * B using 16x16 tile blocks
// A: M x K, B: K x N, C: M x N (flat arrays)
fn amx_tile_matmul mat_a mat_b m k n
    res_c = list()
    total_elements = m * n
    z = 0
    while z < total_elements
        push(res_c, 0)
        z = z + 1
    end

    // Tile block dimensions (Intel AMX standard tile size: 16 rows)
    TILE_SIZE = 16

    // Iterate over M blocks
    bi = 0
    while bi < m
        bi_max = bi + TILE_SIZE
        if bi_max > m bi_max = m end

        // Iterate over N blocks
        bj = 0
        while bj < n
            bj_max = bj + TILE_SIZE
            if bj_max > n bj_max = n end

            // Iterate over K blocks
            bk = 0
            while bk < k
                bk_max = bk + TILE_SIZE
                if bk_max > k bk_max = k end

                // Inner tile multiply-accumulate: [16x16] += [16x16] * [16x16]
                i = bi
                while i < bi_max
                    kk = bk
                    while kk < bk_max
                        aik = mat_a[(i * k) + kk]
                        // Sparsity bypass: if element is zero, skip row update
                        if aik != 0
                            j = bj
                            while j < bj_max
                                bkj = mat_b[(kk * n) + j]
                                res_c[(i * n) + j] = res_c[(i * n) + j] + (aik * bkj)
                                j = j + 1
                            end
                        end
                        kk = kk + 1
                    end
                    i = i + 1
                end

                bk = bk + TILE_SIZE
            end
            bj = bj + TILE_SIZE
        end
        bi = bi + TILE_SIZE
    end

    return res_c
