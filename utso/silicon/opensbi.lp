// ==============================================================================
// 👑 LIPI UTSO — REAL RISC-V 64 SILICON PLATFORM: NS16550A, CLINT, PLIC & OPENSBI
// ⚡ 100% Pure Lipi | Direct RV64 MMIO | 0% Linux ECALL | 0% Heap | 0% Simulation
// 🏛️ Module: utso/silicon/opensbi.lp
// ==============================================================================
//
// WHY THIS MODULE:
// Complete Ring-0 / Supervisor-Mode bare-metal platform drivers for RISC-V 64
// (`qemu-system-riscv64 -machine virt`, SiFive Unmatched, StarFive VisionFive 2):
//   1. NS16550A MMIO UART (base 0x10000000) — zero-heap serial console I/O.
//   2. CLINT (Core-Local Interruptor, base 0x02000000) — MSIP IPI + MTIME/MTIMECMP timer.
//   3. PLIC (Platform-Level Interrupt Controller, base 0x0C000000) — external IRQ routing,
//      priority, threshold, claim, and complete.
//   4. SiFive Test Syscon (base 0x00100000) — hardware poweroff / reboot.
//   5. OpenSBI v2.0 Extension & Function ID constants (BASE, TIME, IPI, RFENCE, HSM, SRST, DBCN).
// ==============================================================================

// ── 1. Canonical QEMU RISC-V `virt` Physical Base Addresses ───────────────────

fn RV_SYSCON_BASE()  return 1048576 end    // 0x00100000 (SiFive Test Finisher)
fn RV_CLINT_BASE()   return 33554432 end   // 0x02000000 (CLINT)
fn RV_PLIC_BASE()    return 201326592 end  // 0x0C000000 (PLIC)
fn RV_UART0_BASE()   return 268435456 end  // 0x10000000 (NS16550A UART0)

// ── 2. OpenSBI v2.0 Standard Extension IDs (EID) & Function IDs (FID) ─────────

fn SBI_EXT_BASE()    return 16 end         // 0x10
fn SBI_EXT_TIME()    return 1414090053 end // 0x54494D45 ("TIME")
fn SBI_EXT_IPI()     return 7565385 end    // 0x00735049 ("sPI")
fn SBI_EXT_RFENCE()  return 1380339278 end // 0x52464E43 ("RFNC")
fn SBI_EXT_HSM()     return 4739917 end    // 0x0048534D ("HSM")
fn SBI_EXT_SRST()    return 1397904212 end // 0x53525354 ("SRST")
fn SBI_EXT_DBCN()    return 1145193294 end // 0x4442434E ("DBCN")

fn SBI_FID_BASE_GET_SPEC_VERSION() return 0 end
fn SBI_FID_BASE_GET_IMPL_ID()      return 1 end
fn SBI_FID_BASE_PROBE_EXT()        return 3 end
fn SBI_FID_TIME_SET_TIMER()        return 0 end
fn SBI_FID_SRST_SYSTEM_RESET()     return 0 end
fn SBI_FID_DBCN_CONSOLE_WRITE()    return 0 end
fn SBI_FID_DBCN_CONSOLE_WRITE_BYTE() return 2 end

// ── 3. NS16550A MMIO UART Driver (0x10000000) ─────────────────────────────────
//   +0 = RBR/THR (RX/TX), +1 = IER, +2 = FCR/IIR, +3 = LCR, +4 = MCR, +5 = LSR

fn silicon_rv_uart_init base
    // Disable interrupts
    mmio_w8(base + 1, 0)
    // Enable DLAB (bit 7 = 0x80) to set baud divisor = 3 (38400 baud @ 1.8432MHz)
    mmio_w8(base + 3, 128)
    mmio_w8(base + 0, 3)
    mmio_w8(base + 1, 0)
    // 8N1 (8-bit word, no parity, 1 stop bit = 0x03)
    mmio_w8(base + 3, 3)
    // Enable & clear RX/TX FIFOs (0x07)
    mmio_w8(base + 2, 7)
    cpu_fence()
    return 1
end

fn silicon_rv_uart_tx_ready base
    // LSR bit 5 (0x20 = 32) = Transmitter Holding Register Empty (THRE)
    if (mmio_r8(base + 5) & 32) != 0
        return 1
    end
    return 0
end

fn silicon_rv_uart_rx_ready base
    // LSR bit 0 (0x01 = 1) = Data Ready (DR)
    if (mmio_r8(base + 5) & 1) != 0
        return 1
    end
    return 0
end

fn silicon_rv_uart_write_byte base ch
    while (mmio_r8(base + 5) & 32) == 0
        cpu_nop()
    end
    mmio_w8(base + 0, ch & 255)
    return 1
end

fn silicon_rv_uart_read_byte base
    while (mmio_r8(base + 5) & 1) == 0
        cpu_nop()
    end
    return mmio_r8(base + 0) & 255
end

fn silicon_rv_uart_write_cstr base str_ptr
    i = 0
    while 1 == 1
        ch = mem_byte_read(str_ptr, i)
        if ch == 0
            break
        end
        if ch == 10
            silicon_rv_uart_write_byte(base, 13)
        end
        silicon_rv_uart_write_byte(base, ch)
        i = i + 1
    end
    return i
end

fn silicon_rv_uart_write_u64 base val
    if val == 0
        silicon_rv_uart_write_byte(base, 48)
        return 1
    end
    div = 1
    tmp = val
    while tmp >= 10
        tmp = tmp / 10
        div = div * 10
    end
    v = val
    cnt = 0
    while div > 0
        d = v / div
        silicon_rv_uart_write_byte(base, 48 + d)
        v = v % div
        div = div / 10
        cnt = cnt + 1
    end
    return cnt
end

// ── 4. CLINT (Core-Local Interruptor: MSIP + MTIME + MTIMECMP) ────────────────
//   MSIP[hart]     = base + 0x0000 + (hart * 4)
//   MTIMECMP[hart] = base + 0x4000 + (hart * 8)
//   MTIME          = base + 0xBFF8 (49144)

fn silicon_rv_clint_mtime clint_base
    return mmio_r64(clint_base + 49144)
end

fn silicon_rv_clint_set_timer clint_base hart_id cmp_val
    mmio_w64(clint_base + 16384 + (hart_id * 8), cmp_val)
    cpu_fence()
    return 1
end

fn silicon_rv_clint_send_ipi clint_base hart_id
    mmio_w32(clint_base + (hart_id * 4), 1)
    cpu_fence()
    return 1
end

fn silicon_rv_clint_clear_ipi clint_base hart_id
    mmio_w32(clint_base + (hart_id * 4), 0)
    cpu_fence()
    return 1
end

// ── 5. PLIC (Platform-Level Interrupt Controller: 0x0C000000) ─────────────────
//   Priority[irq]             = base + (irq * 4)
//   Enable[ctx][irq/32]       = base + 0x002000 + (ctx * 0x80) + ((irq / 32) * 4)
//   Threshold[ctx]            = base + 0x200000 + (ctx * 0x1000)
//   Claim/Complete[ctx]       = base + 0x200004 + (ctx * 0x1000)
//   NOTE: On QEMU virt, S-mode context for hart H is `ctx = (H * 2) + 1`.

fn silicon_rv_plic_set_priority plic_base irq prio
    mmio_w32(plic_base + (irq * 4), prio & 7)
    return 1
end

fn silicon_rv_plic_enable_irq plic_base ctx_id irq
    en_addr = plic_base + 8192 + (ctx_id * 128) + ((irq / 32) * 4)
    cur = mmio_r32(en_addr)
    mmio_w32(en_addr, cur | (1 << (irq & 31)))
    cpu_fence()
    return 1
end

fn silicon_rv_plic_disable_irq plic_base ctx_id irq
    en_addr = plic_base + 8192 + (ctx_id * 128) + ((irq / 32) * 4)
    cur = mmio_r32(en_addr)
    mmio_w32(en_addr, cur & (4294967295 ^ (1 << (irq & 31))))
    cpu_fence()
    return 1
end

fn silicon_rv_plic_set_threshold plic_base ctx_id thresh
    mmio_w32(plic_base + 2097152 + (ctx_id * 4096), thresh & 7)
    cpu_fence()
    return 1
end

fn silicon_rv_plic_claim plic_base ctx_id
    return mmio_r32(plic_base + 2097156 + (ctx_id * 4096))
end

fn silicon_rv_plic_complete plic_base ctx_id irq
    mmio_w32(plic_base + 2097156 + (ctx_id * 4096), irq)
    cpu_fence()
    return 1
end

// ── 6. SiFive Test Syscon Poweroff / Reboot (QEMU virt 0x00100000) ────────────

fn silicon_rv_syscon_poweroff syscon_base
    // FINISHER_PASS = 0x5555 (21845) cleanly powers off QEMU virt with exit status 0
    mmio_w32(syscon_base, 21845)
    cpu_fence()
    while 1 == 1
        cpu_wfi()
    end
    return 0
end

fn silicon_rv_syscon_reboot syscon_base
    // FINISHER_RESET = 0x7777 (30583) triggers clean hardware reset
    mmio_w32(syscon_base, 30583)
    cpu_fence()
    while 1 == 1
        cpu_wfi()
    end
    return 0
end

// ── 7. Callable S-Mode OpenSBI v2.0 ECALL Wrappers (Zero Linux Syscalls!) ─────
// WHY: Invokes genuine RISC-V Supervisor Binary Interface (SBI) firmware traps:
//   - a7 = EID, a6 = FID, a0..a5 = args, architectural HINT `addi x0, x0, 0x5B1` + `ecall`.
//   - Passes LiPi's Bare-Metal Purity Gate while strictly rejecting Linux syscalls.

fn silicon_sbi_call eid fid a0 a1 a2 a3 a4 a5
    return sbi_ecall(eid, fid, a0, a1, a2, a3, a4, a5)
end

fn silicon_sbi_call_val eid fid a0 a1 a2 a3 a4 a5
    return sbi_ecall_val(eid, fid, a0, a1, a2, a3, a4, a5)
end

fn silicon_sbi_call_ret eid fid out_val_ptr a0 a1 a2 a3 a4 a5
    return sbi_ecall_ret(eid, fid, out_val_ptr, a0, a1, a2, a3, a4, a5)
end

fn silicon_sbi_get_spec_version
    return sbi_ecall_val(SBI_EXT_BASE(), SBI_FID_BASE_GET_SPEC_VERSION())
end

fn silicon_sbi_get_impl_id
    return sbi_ecall_val(SBI_EXT_BASE(), SBI_FID_BASE_GET_IMPL_ID())
end

fn silicon_sbi_probe_ext ext_id
    return sbi_ecall_val(SBI_EXT_BASE(), SBI_FID_BASE_PROBE_EXT(), ext_id)
end

fn silicon_sbi_set_timer stime_val
    return sbi_ecall(SBI_EXT_TIME(), SBI_FID_TIME_SET_TIMER(), stime_val)
end

fn silicon_sbi_console_write_byte ch
    return sbi_ecall(SBI_EXT_DBCN(), SBI_FID_DBCN_CONSOLE_WRITE_BYTE(), ch & 255)
end

fn silicon_sbi_console_write num_bytes base_lo base_hi
    return sbi_ecall(SBI_EXT_DBCN(), SBI_FID_DBCN_CONSOLE_WRITE(), num_bytes, base_lo, base_hi)
end

fn silicon_sbi_system_reset reset_type reset_reason
    return sbi_ecall(SBI_EXT_SRST(), SBI_FID_SRST_SYSTEM_RESET(), reset_type, reset_reason)
end

fn silicon_sbi_shutdown
    return silicon_sbi_system_reset(0, 0)
end

fn silicon_sbi_reboot
    return silicon_sbi_system_reset(1, 0)
end
