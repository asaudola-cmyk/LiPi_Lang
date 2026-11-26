// ==============================================================================
// 👑 LIPI UTSO — REAL ARM64 GICv2 / GICv3 INTERRUPT CONTROLLER (utso/silicon/gic.lp)
// ⚡ 100% Pure Lipi | Direct AArch64 MMIO | 0% Linux SVC | 0% Heap | 0% Simulation
// ==============================================================================
//
// WHY THIS MODULE:
// Controls the ARM Generic Interrupt Controller (GICv2 Distributor + CPU Interface
// and GICv3 Redistributor wake sequence) directly via 32-bit MMIO registers on
// QEMU `virt` (GICD=0x08000000, GICC=0x08010000, GICR=0x080A0000) and real ARM64 SoCs.
// Supports SPI/PPI/SGI routing, interrupt priority, edge/level trigger config,
// IRQ acknowledgement, EOI completion, and SMP Software Generated Interrupts (IPIs).
// ==============================================================================

fn GICD_QEMU_VIRT_BASE() return 134217728 end // 0x08000000
fn GICC_QEMU_VIRT_BASE() return 134283264 end // 0x08010000
fn GICR_QEMU_VIRT_BASE() return 134873088 end // 0x080A0000

// ── GICv2 Distributor Register Offsets ────────────────────────────────────────
//   +0x000 (0)    = GICD_CTLR       (Distributor Control)
//   +0x004 (4)    = GICD_TYPER      (Controller Type: ITLinesNumber = bits[4:0])
//   +0x008 (8)    = GICD_IIDR       (Implementer Identification)
//   +0x100 (256)  = GICD_ISENABLERn (Interrupt Set-Enable, 32 IRQs per u32)
//   +0x180 (384)  = GICD_ICENABLERn (Interrupt Clear-Enable)
//   +0x200 (512)  = GICD_ISPENDRn   (Interrupt Set-Pending)
//   +0x280 (640)  = GICD_ICPENDRn   (Interrupt Clear-Pending)
//   +0x400 (1024) = GICD_IPRIORITYRn (Interrupt Priority, 4 IRQs per u32)
//   +0x800 (2048) = GICD_ITARGETSRn  (Interrupt Processor Targets, 4 IRQs per u32)
//   +0xC00 (3072) = GICD_ICFGRn      (Interrupt Configuration, 16 IRQs per u32)
//   +0xF00 (3840) = GICD_SGIR        (Software Generated Interrupt Register)
//
// ── GICv2 CPU Interface Register Offsets ──────────────────────────────────────
//   +0x000 (0)    = GICC_CTLR       (CPU Interface Control)
//   +0x004 (4)    = GICC_PMR        (Interrupt Priority Mask)
//   +0x008 (8)    = GICC_BPR        (Binary Point)
//   +0x00C (12)   = GICC_IAR        (Interrupt Acknowledge)
//   +0x010 (16)   = GICC_EOIR       (End of Interrupt)
//   +0x014 (20)   = GICC_RPR        (Running Priority)
//   +0x018 (24)   = GICC_HPPIR      (Highest Priority Pending Interrupt)

fn silicon_gic_max_irqs gicd_base
    typer = mmio_r32(gicd_base + 4)
    lines = (typer & 31) + 1
    max_irqs = lines * 32
    if max_irqs > 1020
        max_irqs = 1020
    end
    return max_irqs
end

fn silicon_gic_dist_init gicd_base
    // Disable distributor during global reset
    mmio_w32(gicd_base + 0, 0)
    cpu_dsb()
    max_irqs = silicon_gic_max_irqs(gicd_base)
    // Disable and clear pending state for all SPIs (IRQ >= 32)
    irq = 32
    while irq < max_irqs
        reg_off = (irq / 32) * 4
        mmio_w32(gicd_base + 384 + reg_off, 4294967295) // ICENABLER
        mmio_w32(gicd_base + 640 + reg_off, 4294967295) // ICPENDR
        irq = irq + 32
    end
    // Set default mid-priority (0xA0) and target CPU0 (0x01) for all SPIs
    irq = 32
    while irq < max_irqs
        reg_off = (irq / 4) * 4
        mmio_w32(gicd_base + 1024 + reg_off, 2694881440) // 0xA0A0A0A0
        mmio_w32(gicd_base + 2048 + reg_off, 16843009)   // 0x01010101 (CPU 0)
        irq = irq + 4
    end
    // Configure all SPIs as level-sensitive by default (ICFGR = 0)
    irq = 32
    while irq < max_irqs
        reg_off = (irq / 16) * 4
        mmio_w32(gicd_base + 3072 + reg_off, 0)
        irq = irq + 16
    end
    // Enable Group 0 + Group 1 forwarding in GICD_CTLR
    mmio_w32(gicd_base + 0, 3)
    cpu_dsb()
    return max_irqs
end

fn silicon_gic_cpu_init gicc_base prio_mask
    // Set Interrupt Priority Mask (typically 0xFF = accept all priorities)
    mmio_w32(gicc_base + 4, prio_mask & 255)
    // Binary Point = 0 (no preemption subpriority grouping)
    mmio_w32(gicc_base + 8, 0)
    // Enable CPU interface (Group 0 + Group 1 = 3)
    mmio_w32(gicc_base + 0, 3)
    cpu_dsb()
    return 1
end

fn silicon_gic_enable_irq gicd_base irq
    reg_off = 256 + ((irq / 32) * 4)
    bit = 1 << (irq & 31)
    mmio_w32(gicd_base + reg_off, bit)
    cpu_dsb()
    return 1
end

fn silicon_gic_disable_irq gicd_base irq
    reg_off = 384 + ((irq / 32) * 4)
    bit = 1 << (irq & 31)
    mmio_w32(gicd_base + reg_off, bit)
    cpu_dsb()
    return 1
end

fn silicon_gic_set_priority gicd_base irq prio
    // Read-modify-write 8-bit priority byte inside 32-bit GICD_IPRIORITYRn
    reg_off = 1024 + ((irq / 4) * 4)
    shift = (irq & 3) * 8
    cur = mmio_r32(gicd_base + reg_off)
    mask = 255 << shift
    next_v = (cur & (4294967295 ^ mask)) | ((prio & 255) << shift)
    mmio_w32(gicd_base + reg_off, next_v)
    return 1
end

fn silicon_gic_set_target gicd_base irq cpu_mask
    // Read-modify-write 8-bit CPU target bitmask inside GICD_ITARGETSRn (for SPIs >= 32)
    reg_off = 2048 + ((irq / 4) * 4)
    shift = (irq & 3) * 8
    cur = mmio_r32(gicd_base + reg_off)
    mask = 255 << shift
    next_v = (cur & (4294967295 ^ mask)) | ((cpu_mask & 255) << shift)
    mmio_w32(gicd_base + reg_off, next_v)
    return 1
end

fn silicon_gic_set_edge_triggered gicd_base irq is_edge
    // GICD_ICFGRn: 2 bits per IRQ; bit 1 (0x2) selects edge-triggered vs level-sensitive
    reg_off = 3072 + ((irq / 16) * 4)
    shift = (irq & 15) * 2
    cur = mmio_r32(gicd_base + reg_off)
    bit = 2 << shift
    if is_edge != 0
        mmio_w32(gicd_base + reg_off, cur | bit)
    else
        mmio_w32(gicd_base + reg_off, cur & (4294967295 ^ bit))
    end
    return 1
end

fn silicon_gic_ack_irq gicc_base
    // Returns full GICC_IAR value (bits[9:0] = INTID; 1023 = spurious)
    return mmio_r32(gicc_base + 12)
end

fn silicon_gic_iar_intid iar_val
    return iar_val & 1023
end

fn silicon_gic_eoi gicc_base iar_val
    mmio_w32(gicc_base + 16, iar_val)
    cpu_dsb()
    return 1
end

fn silicon_gic_send_sgi gicd_base target_cpu_mask sgi_id
    // GICD_SGIR (+0xF00): bits[23:16] = CPUTargetList, bits[3:0] = SGIINTID (0..15)
    val = ((target_cpu_mask & 255) << 16) | (sgi_id & 15)
    mmio_w32(gicd_base + 3840, val)
    cpu_dsb()
    return 1
end

fn silicon_gicv3_wake_redist gicr_base
    // WHY: Wakes a GICv3 Redistributor (GICR_WAKER at +0x0014): clears ProcessorSleep (bit 1)
    // and waits until ChildrenAsleep (bit 2) transitions to 0.
    waker = mmio_r32(gicr_base + 20)
    waker = waker & (4294967295 ^ 2)
    mmio_w32(gicr_base + 20, waker)
    cpu_dsb()
    while (mmio_r32(gicr_base + 20) & 4) != 0
        cpu_nop()
    end
    return 1
end

// ── ARM64 PSCI v0.2+ Power Management (HVC #0 — Zero Linux SVC) ──────────────
fn PSCI_SYSTEM_OFF()   return 2214592520 end // 0x84000008
fn PSCI_SYSTEM_RESET() return 2214592521 end // 0x84000009

fn silicon_arm64_psci_poweroff
    // WHY: Cleanly powers off QEMU `virt` and ARMv8 PSCI-compliant firmware from EL1 via HVC #0.
    psci_call(PSCI_SYSTEM_OFF(), 0, 0, 0)
    cpu_halt()
    return 0
end

fn silicon_arm64_psci_reboot
    psci_call(PSCI_SYSTEM_RESET(), 0, 0, 0)
    cpu_halt()
    return 0
end
