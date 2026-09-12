// ==============================================================================
// 🧪 LIPI TEST SUITE: SILICON GPU DRM & COMPUTE DRIVER
// File: tests/test_gpu_silicon.lp
// Standard: Linux DRM / KMS Subsystem & SPIR-V Compute Pipeline
// 100% Pure Lipi — Zero C | Zero Vulkan SDK | Zero External Drivers
// ==============================================================================

include "universe/gpu/drm.lp"

fn assert_true cond msg
    if cond == 0
        say "  ❌ [FAIL] Assertion failed: " + msg
        exit(1)
    say "  ✔ [PASS] " + msg

fn assert_eq_int actual expected msg
    if actual != expected
        say "  ❌ [FAIL] " + msg + " (Expected " + str(expected) + ", got " + str(actual) + ")"
        exit(1)
    say "  ✔ [PASS] " + msg

fn main
    say "================================================================="
    say "⚡ LIPI SILICON GPU DRM & COMPUTE DRIVER TEST SUITE ⚡"
    say "================================================================="

    total_tests = 0
    passed_tests = 0

    // ── Section 1: GPU Device Ingestion & Sandbox Resilience ──────────────────
    say "▶ Section 1: GPU Silicon Device Initialization..."
    total_tests = total_tests + 1

    dev = gpu_device_open()
    assert_true(dev != 0, "GPU Device instance instantiated")
    assert_true(len(dev.driver_name) > 0, "Driver name identifier populated")
    say "    • Active Device: " + dev.driver_name + " (HW: " + str(dev.is_hardware) + ")"
    passed_tests = passed_tests + 1

    // ── Section 2: Shared Silicon Buffer Allocation ────────────────────────────
    say "\n▶ Section 2: Shared Compute Memory Allocation (mmap/DUMB)..."
    total_tests = total_tests + 1

    buf_size = 4096
    buf_ptr = gpu_buffer_alloc(dev, buf_size)
    assert_true(buf_ptr > 0, "Compute memory buffer allocated successfully")
    assert_true(dev.buffer_size_bytes >= buf_size, "Buffer size satisfied page boundary")
    passed_tests = passed_tests + 1

    // ── Section 3: SPIR-V Binary Header Validation ─────────────────────────────
    say "\n▶ Section 3: SPIR-V 1.0 Binary Shader Words Synthesis..."
    total_tests = total_tests + 1

    spirv = list()
    push(spirv, SPIRV_MAGIC())          // Word 0: Magic 0x07230203
    push(spirv, SPIRV_VERSION_1_0())    // Word 1: Version 1.0 (0x00010000)
    push(spirv, SPIRV_GENERATOR_MAYA()) // Word 2: Generator
    push(spirv, 10)                     // Word 3: Bound ID
    push(spirv, 0)                      // Word 4: Schema

    assert_eq_int(get(spirv, 0), 119734787, "SPIR-V Magic 0x07230203 verified")
    assert_eq_int(get(spirv, 1), 65536, "SPIR-V Version 1.0 verified")
    passed_tests = passed_tests + 1

    // ── Section 4: Compute Pipeline Kernel Dispatch ────────────────────────────
    say "\n▶ Section 4: Silicon Compute Pipeline Dispatch & Kernel Execution..."
    total_tests = total_tests + 1

    in_buf = malloc(64)
    out_buf = malloc(64)

    // Populate input elements: [10, 20, 30, 40]
    mem_write_u32(in_buf, 0, 10)
    mem_write_u32(in_buf, 4, 20)
    mem_write_u32(in_buf, 8, 30)
    mem_write_u32(in_buf, 12, 40)

    processed = gpu_dispatch_compute(dev, spirv, 5, in_buf, out_buf, 4)
    assert_eq_int(processed, 4, "Kernel executed across 4 vector elements")

    // Expected transformation: (x * 2) + 1
    // 10*2+1 = 21, 20*2+1 = 41, 30*2+1 = 61, 40*2+1 = 81
    assert_eq_int(mem_read_u32(out_buf, 0), 21, "Element 0 transformed to 21")
    assert_eq_int(mem_read_u32(out_buf, 4), 41, "Element 1 transformed to 41")
    assert_eq_int(mem_read_u32(out_buf, 8), 61, "Element 2 transformed to 61")
    assert_eq_int(mem_read_u32(out_buf, 12), 81, "Element 3 transformed to 81")

    free(in_buf, 64)
    free(out_buf, 64)
    passed_tests = passed_tests + 1

    // Cleanup
    gpu_device_close(dev)

    say "\n-----------------------------------------------------------------"
    say "RESULTS: " + str(passed_tests) + "/" + str(total_tests) + " sections passed."
    say "🎉 ALL SILICON GPU DRM & COMPUTE TESTS PASSED!"
    return 0

main()
