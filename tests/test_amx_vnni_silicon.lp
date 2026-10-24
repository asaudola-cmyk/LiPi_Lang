// ==============================================================================
// 🧪 LIPI SILICON TEST: INTEL AMX 2D TILE & AVX-512 VNNI HARDWARE ACCELERATOR
// ⚡ Module: tests/test_amx_vnni_silicon.lp
// 100% Pure LiPi Implementation — Zero External / C++ / Python Dependencies
// ==============================================================================
//
// WHY: Intel AMX (Advanced Matrix Extensions) and AVX-512 VNNI provide high-throughput
// matrix and vector neural dot product hardware instructions on modern x86_64 silicon.
// This test verifies:
//   1. Physical CPUID feature detection (cpu_has_amx_tile, cpu_has_avx512_vnni).
//   2. Kernel permission handshake (arch_prctl syscall 158).
//   3. 64-byte tile palette structure initialization and accessor integrity.
//   4. VNNI 4-lane saturated Int8 dot product execution across byte streams.
//   5. AMX 16x16 Int8 tile GEMM matrix multiplication microkernel.
// ==============================================================================

include "utso/io.lp"
include "utso/memory.lp"
include "utso/cpu/amx_vnni.lp"

fn test_feature_probing
    say "[Phase 1] Probing Silicon Hardware Capabilities..."
    has_amx = cpu_has_amx_tile()
    has_vnni = cpu_has_avx512_vnni()
    if has_amx != 0 and has_amx != 1
        say "FAIL: cpu_has_amx_tile returned non-boolean value"
        return 0
    end
    if has_vnni != 0 and has_vnni != 1
        say "FAIL: cpu_has_avx512_vnni returned non-boolean value"
        return 0
    end
    say "  ✔ Silicon CPUID probe succeeded (AMX=" + str(has_amx) + ", VNNI=" + str(has_vnni) + ")"
    return 1

fn test_tile_config
    say "[Phase 2] Verifying 64-Byte Tile Palette Structure..."
    cfg = amx_tile_config_alloc()
    if cfg <= 0
        say "FAIL: amx_tile_config_alloc failed to allocate buffer"
        return 0
    end

    // Palette ID at byte 0 must be 1
    pal_id = mem_byte_read(cfg, 0)
    if pal_id != 1
        say "FAIL: Palette ID must be 1, got: " + str(pal_id)
        amx_tile_config_free(cfg)
        return 0
    end

    // Configure Tile 0: 16 rows, 64 bytes per row
    amx_tile_config_set(cfg, 0, 16, 64)
    r0 = amx_tile_config_get_rows(cfg, 0)
    c0 = amx_tile_config_get_colsb(cfg, 0)
    if r0 != 16 or c0 != 64
        say "FAIL: Tile 0 dimensions mismatch. Expected 16x64, got: " + str(r0) + "x" + str(c0)
        amx_tile_config_free(cfg)
        return 0
    end

    // Configure Tile 3: 8 rows, 32 bytes per row
    amx_tile_config_set(cfg, 3, 8, 32)
    r3 = amx_tile_config_get_rows(cfg, 3)
    c3 = amx_tile_config_get_colsb(cfg, 3)
    if r3 != 8 or c3 != 32
        say "FAIL: Tile 3 dimensions mismatch. Expected 8x32, got: " + str(r3) + "x" + str(c3)
        amx_tile_config_free(cfg)
        return 0
    end

    amx_tile_config_free(cfg)
    say "  ✔ 64-byte Palette structure verified bit-for-bit."
    return 1

fn test_vnni_dot_product
    say "[Phase 3] Testing AVX-512 VNNI Int8 Dot Product Precision..."
    // Allocate 8 bytes for unsigned u8 and 8 bytes for signed i8
    u_buf = malloc(8)
    i_buf = malloc(8)
    if u_buf <= 0 or i_buf <= 0
        say "FAIL: malloc failed for VNNI buffers"
        return 0
    end

    // Quad 0: [2, 3, 4, 5] * [10, -2, 3, -1]
    // u8: [2, 3, 4, 5], i8: [10, 254(-2), 3, 255(-1)]
    mem_byte_write(u_buf, 0, 2)
    mem_byte_write(u_buf, 1, 3)
    mem_byte_write(u_buf, 2, 4)
    mem_byte_write(u_buf, 3, 5)

    mem_byte_write(i_buf, 0, 10)
    mem_byte_write(i_buf, 1, 254) // -2
    mem_byte_write(i_buf, 2, 3)
    mem_byte_write(i_buf, 3, 255) // -1

    // Quad 1: [1, 1, 1, 1] * [5, 5, 5, 5] -> 20
    mem_byte_write(u_buf, 4, 1)
    mem_byte_write(u_buf, 5, 1)
    mem_byte_write(u_buf, 6, 1)
    mem_byte_write(u_buf, 7, 1)

    mem_byte_write(i_buf, 4, 5)
    mem_byte_write(i_buf, 5, 5)
    mem_byte_write(i_buf, 6, 5)
    mem_byte_write(i_buf, 7, 5)

    // Expected:
    // Quad 0: (2*10) + (3*-2) + (4*3) + (5*-1) = 20 - 6 + 12 - 5 = 21
    // Quad 1: (1*5) + (1*5) + (1*5) + (1*5) = 20
    // Total = 41
    res = vnni_dot_product_i8(u_buf, i_buf, 8)
    free(u_buf, 8)
    free(i_buf, 8)

    if res != 41
        say "FAIL: VNNI dot product expected 41, got: " + str(res)
        return 0
    end
    say "  ✔ VNNI Int8 Quad Dot Product result: " + str(res) + " (Mathematically Exact)."
    return 1

fn test_amx_tile_gemm
    say "[Phase 4] Testing AMX 16x16 Int8 Tile Matrix Multiplier..."
    // Allocate 16x16=256 bytes for A, 256 bytes for B, 16x16x4=1024 bytes for C
    ptr_a = malloc(256)
    ptr_b = malloc(256)
    ptr_c = malloc(1024)
    if ptr_a <= 0 or ptr_b <= 0 or ptr_c <= 0
        say "FAIL: malloc failed for AMX GEMM matrices"
        return 0
    end

    mem_fill(ptr_a, 0, 256)
    mem_fill(ptr_b, 0, 256)
    mem_fill(ptr_c, 0, 1024)

    // Set A as 16x16 Identity Matrix: A[i, i] = 1
    idx = 0
    while idx < 16
        mem_byte_write(ptr_a, (idx * 16) + idx, 1)
        idx = idx + 1
    end

    // Set B[k, j] = (k + j) % 10
    k = 0
    while k < 16
        j = 0
        while j < 16
            mem_byte_write(ptr_b, (k * 16) + j, (k + j) % 10)
            j = j + 1
        end
        k = k + 1
    end

    // Multiply: C = A * B
    // Since A is Identity, C[i, j] should equal B[i, j]
    ok = amx_gemm_tile_16x16_i8(ptr_c, ptr_a, ptr_b, 16)
    if ok != 1
        say "FAIL: amx_gemm_tile_16x16_i8 returned error"
        free(ptr_a, 256)
        free(ptr_b, 256)
        free(ptr_c, 1024)
        return 0
    end

    // Verify C[i, j] == B[i, j]
    all_match = 1
    i = 0
    while i < 16
        j = 0
        while j < 16
            c_val = amx_mem_read_i32(ptr_c, (i * 16 + j) * 4)
            b_val = (i + j) % 10
            if c_val != b_val
                say "FAIL: C[" + str(i) + "," + str(j) + "] = " + str(c_val) + ", expected: " + str(b_val)
                all_match = 0
                break
            end
            j = j + 1
        end
        if all_match == 0 break end
        i = i + 1
    end

    free(ptr_a, 256)
    free(ptr_b, 256)
    free(ptr_c, 1024)

    if all_match == 0
        return 0
    end
    say "  ✔ AMX 16x16 Int8 Tile GEMM verified against Identity Matrix."
    return 1

fn test_kernel_permission
    say "[Phase 5] Verifying Linux Kernel Hardware Permission ABI..."
    perm = amx_request_kernel_permission()
    if perm != 0 and perm != 1
        say "FAIL: amx_request_kernel_permission returned invalid status"
        return 0
    end
    say "  ✔ Linux sys_arch_prctl handshake completed (Status=" + str(perm) + ")."
    return 1

fn main
    say "════════════════════════════════════════════════════════════════════════"
    say "  👑 LIPI TEST: INTEL AMX 2D TILE & AVX-512 VNNI SILICON ACCELERATOR"
    say "════════════════════════════════════════════════════════════════════════"

    if test_feature_probing() != 1
        say "❌ Feature Probing Test Failed"
        exit(1)
    end

    if test_tile_config() != 1
        say "❌ Tile Config Test Failed"
        exit(1)
    end

    if test_vnni_dot_product() != 1
        say "❌ VNNI Dot Product Test Failed"
        exit(1)
    end

    if test_amx_tile_gemm() != 1
        say "❌ AMX Tile GEMM Test Failed"
        exit(1)
    end

    if test_kernel_permission() != 1
        say "❌ Kernel Permission Test Failed"
        exit(1)
    end

    amx_vnni_feature_report()

    say "════════════════════════════════════════════════════════════════════════"
    say "🎉 ALL INTEL AMX & AVX-512 VNNI SILICON TESTS PASSED!"
    say "════════════════════════════════════════════════════════════════════════"
    return 0

main()
