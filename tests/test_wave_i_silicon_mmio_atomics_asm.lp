// ==============================================================================
// Wave I Test: Sovereign Ring-0 Silicon Intrinsics, Volatile MMIO, Hardware
// Atomics, Fences, CPUID/RDTSC/RFLAGS, @naked, @interrupt & Inline @asm
// ==============================================================================

@naked
fn naked_nop_ret()
    @asm { nop; ret }
end

@interrupt
fn sample_isr_frame()
    @asm { nop }
end

fn main()
    // 1. Exact-width volatile MMIO reads & writes (zero adjacent byte clobbering)
    buf = malloc(64)
    mmio_w64(buf, 0)
    mmio_w64(buf + 8, 0)

    mmio_w8(buf + 0, 171)       // 0xAB
    mmio_w8(buf + 1, 205)       // 0xCD
    mmio_w16(buf + 2, 4660)     // 0x1234
    mmio_w32(buf + 4, 305419896)// 0x12345678
    mmio_w64(buf + 8, 1311768467463790320) // 0x123456789ABCDEF0

    if mmio_r8(buf + 0) != 171
        say "FAIL mmio_r8[0]"
        exit(1)
    end
    if mmio_r8(buf + 1) != 205
        say "FAIL mmio_r8[1]"
        exit(1)
    end
    if mmio_r16(buf + 2) != 4660
        say "FAIL mmio_r16[2]"
        exit(1)
    end
    if mmio_r32(buf + 4) != 305419896
        say "FAIL mmio_r32[4]"
        exit(1)
    end
    if mmio_r64(buf + 8) != 1311768467463790320
        say "FAIL mmio_r64[8]"
        exit(1)
    end

    // Verify sys_peek16/32/64 & sys_poke16/32/64 inline lowering
    sys_poke16(buf + 16, 65001)
    sys_poke32(buf + 20, 3735928559) // 0xDEADBEEF
    sys_poke64(buf + 24, 9876543210123)
    if sys_peek16(buf + 16) != 65001
        say "FAIL sys_peek16"
        exit(1)
    end
    if sys_peek32(buf + 20) != 3735928559
        say "FAIL sys_peek32"
        exit(1)
    end
    if sys_peek64(buf + 24) != 9876543210123
        say "FAIL sys_peek64"
        exit(1)
    end

    // 2. Hardware 32-bit & 64-bit atomics + memory fences
    mmio_w32(buf + 32, 100)
    ok_cas32 = atomic_cas32(buf + 32, 100, 250)
    fail_cas32 = atomic_cas32(buf + 32, 100, 999)
    old_x32 = atomic_xchg32(buf + 32, 500)
    old_a32 = atomic_add32(buf + 32, 25)
    if ok_cas32 != 1 or fail_cas32 != 0 or old_x32 != 250 or old_a32 != 500 or mmio_r32(buf + 32) != 525
        say "FAIL atomic32"
        exit(1)
    end

    mmio_w64(buf + 40, 1000)
    ok_cas64 = atomic_cas64(buf + 40, 1000, 2000)
    old_x64 = atomic_xchg64(buf + 40, 3000)
    old_a64 = atomic_add64(buf + 40, 777)
    if ok_cas64 != 1 or old_x64 != 2000 or old_a64 != 3000 or mmio_r64(buf + 40) != 3777
        say "FAIL atomic64"
        exit(1)
    end

    fence_full()
    fence_store()
    fence_load()

    // 3. Real CPU silicon queries & inline @asm + @naked + @interrupt address
    t1 = cpu_rdtsc()
    cpu_pause()
    @asm [144, 144]
    @asm { nop; mfence; pause }
    naked_nop_ret()
    t2 = cpu_rdtsc()
    cpuid_out = malloc(16)
    mmio_w64(cpuid_out, 0)
    mmio_w64(cpuid_out + 8, 0)
    max_leaf = cpu_cpuid(0, 0, cpuid_out)
    max_leaf2 = cpu_cpuid(0, 0, 0)
    rf = cpu_read_rflags()
    sp_now = cpu_read_rsp()
    isr_addr = fn_ptr(sample_isr_frame)

    if t1 == 0 or t2 < t1 or max_leaf <= 0 or max_leaf != max_leaf2 or mmio_r32(cpuid_out) != max_leaf or rf == 0 or sp_now == 0 or isr_addr == 0
        say "FAIL cpu_silicon"
        exit(1)
    end

    say "PASS_WAVE_I_SILICON_MMIO_ATOMICS_ASM"
    return 0
end
