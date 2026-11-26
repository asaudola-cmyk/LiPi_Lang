// ==============================================================================
// 👑 LIPI UTSO — REAL x86-64 LOCAL APIC & I/O APIC DRIVER (utso/silicon/apic.lp)
// ⚡ 100% Pure Lipi | Zero Heap | Zero Linux Syscalls | Direct xAPIC/IOAPIC MMIO
// ==============================================================================
//
// WHY THIS MODULE:
// Controls Intel/AMD xAPIC (default base 0xFEE00000) and I/O APIC (default 0xFEC00000)
// directly via 32-bit MMIO registers for SMP interrupt routing, APIC timer ticks,
// EOI acknowledgement, and Inter-Processor Interrupts (IPI / INIT-SIPI).
// ==============================================================================

// ── Local APIC Register Offsets ──────────────────────────────────────────────
//   +0x020 (32)  = LAPIC ID
//   +0x030 (48)  = LAPIC Version
//   +0x080 (128) = Task Priority Register (TPR)
//   +0x0B0 (176) = End of Interrupt (EOI)
//   +0x0F0 (240) = Spurious Interrupt Vector Register (SVR)
//   +0x300 (768) = Interrupt Command Register Low (ICR_LO)
//   +0x310 (784) = Interrupt Command Register High (ICR_HI)
//   +0x320 (800) = LVT Timer Register
//   +0x380 (896) = Timer Initial Count Register
//   +0x390 (912) = Timer Current Count Register
//   +0x3E0 (992) = Timer Divide Configuration Register

fn silicon_lapic_read lapic_base reg_off
    return mmio_r32(lapic_base + reg_off)

fn silicon_lapic_write lapic_base reg_off val
    mmio_w32(lapic_base + reg_off, val)
    return 0

fn silicon_lapic_id lapic_base
    return (mmio_r32(lapic_base + 32) >> 24) & 255

fn silicon_lapic_enable lapic_base spurious_vec
    // Clear Task Priority (accept all interrupts) and set SVR bit 8 (APIC Software Enable = 0x100)
    mmio_w32(lapic_base + 128, 0)
    mmio_w32(lapic_base + 240, 256 | (spurious_vec & 255))
    return 0

fn silicon_lapic_eoi lapic_base
    mmio_w32(lapic_base + 176, 0)
    return 0

fn silicon_lapic_timer_setup lapic_base vector divide_cfg init_count periodic
    // WHY: Programs LAPIC LVT Timer (0x320): bit 17 = periodic mode (0x20000), bits 0..7 = vector.
    mmio_w32(lapic_base + 992, divide_cfg & 15)
    lvt = vector & 255
    if periodic != 0
        lvt = lvt | 131072 // 0x20000 periodic mode
    end
    mmio_w32(lapic_base + 800, lvt)
    mmio_w32(lapic_base + 896, init_count)
    return 0

fn silicon_lapic_send_ipi lapic_base dest_apic_id icr_lo
    // Writes destination APIC ID into ICR_HI[31:24], then triggers delivery via ICR_LO
    mmio_w32(lapic_base + 784, (dest_apic_id & 255) << 24)
    mmio_w32(lapic_base + 768, icr_lo)
    return 0

// ── I/O APIC Indirect Register Access (IOREGSEL=+0x00, IOWIN=+0x10) ──────────

fn silicon_ioapic_read ioapic_base reg_idx
    mmio_w32(ioapic_base + 0, reg_idx & 255)
    return mmio_r32(ioapic_base + 16)

fn silicon_ioapic_write ioapic_base reg_idx val
    mmio_w32(ioapic_base + 0, reg_idx & 255)
    mmio_w32(ioapic_base + 16, val)
    return 0

fn silicon_ioapic_max_redirs ioapic_base
    ver = silicon_ioapic_read(ioapic_base, 1)
    return ((ver >> 16) & 255) + 1

fn silicon_ioapic_route_irq ioapic_base irq vector dest_apic_id masked
    // WHY: Programs 64-bit IOREDTBL[irq] at indirect registers (0x10 + 2*irq) and (0x11 + 2*irq).
    lo = vector & 255
    if masked != 0
        lo = lo | 65536 // bit 16 = Interrupt Mask
    end
    hi = (dest_apic_id & 255) << 24
    reg_lo = 16 + (irq * 2)
    silicon_ioapic_write(ioapic_base, reg_lo, lo)
    silicon_ioapic_write(ioapic_base, reg_lo + 1, hi)
    return 0
