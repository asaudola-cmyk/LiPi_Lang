// ==============================================================================
// 👑 LIPI UTSO — REAL RING-0 CPU, IDT, GDT, PIC8259 & LAPIC DRIVER (utso/silicon/cpu.lp)
// ⚡ 100% Pure Lipi | Real x86-64 Hardware Instructions | 0% Linux | 0% Simulation
// ==============================================================================

@packed
struct SiliconDescriptorPtr
    dp_limit: u16
    dp_base: u64
end

@packed
struct SiliconIdtGate64
    ig_off_low: u16
    ig_selector: u16
    ig_ist: u8
    ig_type_attr: u8
    ig_off_mid: u16
    ig_off_high: u32
    ig_zero: u32
end

fn silicon_idt_set_gate idt_base vec handler_addr selector type_attr
    // WHY: Writes exact 16-byte x86-64 hardware Interrupt Gate descriptor directly into IDT RAM.
    gate = idt_base + (vec * 16)
    mmio_w16(gate + 0, handler_addr & 65535)
    mmio_w16(gate + 2, selector & 65535)
    mmio_w8(gate + 4, 0)
    mmio_w8(gate + 5, type_attr & 255)
    mmio_w16(gate + 6, (handler_addr >> 16) & 65535)
    mmio_w32(gate + 8, (handler_addr >> 32) & 4294967295)
    mmio_w32(gate + 12, 0)
    return 1

fn silicon_load_idt idtr_buf idt_base num_entries
    // Writes 10-byte packed IDTR [limit:u16, base:u64] and executes hardware `lidt [rdi]`!
    mmio_w16(idtr_buf, (num_entries * 16) - 1)
    mmio_w64(idtr_buf + 2, idt_base)
    cpu_lidt(idtr_buf)
    return 1

fn silicon_load_gdt gdtr_buf gdt_base byte_len
    mmio_w16(gdtr_buf, byte_len - 1)
    mmio_w64(gdtr_buf + 2, gdt_base)
    cpu_lgdt(gdtr_buf)
    return 1

// ── Real Hardware 8259A Programmable Interrupt Controller (Ports 0x20/0xA0) ───

fn silicon_pic8259_remap offset1 offset2
    m1 = port_in8(33)   // 0x21 Master data
    m2 = port_in8(161)  // 0xA1 Slave data
    port_out8(32, 17)   // 0x20 ICW1_INIT | ICW1_ICW4
    io_wait()
    port_out8(160, 17)  // 0xA0
    io_wait()
    port_out8(33, offset1 & 255)
    io_wait()
    port_out8(161, offset2 & 255)
    io_wait()
    port_out8(33, 4)    // Slave PIC at IRQ2
    io_wait()
    port_out8(161, 2)   // Cascade identity
    io_wait()
    port_out8(33, 1)    // 8086 mode
    io_wait()
    port_out8(161, 1)
    io_wait()
    port_out8(33, m1)
    port_out8(161, m2)
    return 1

fn silicon_pic8259_send_eoi irq
    if irq >= 8
        port_out8(160, 32) // Slave EOI (0xA0 <- 0x20)
    end
    port_out8(32, 32)      // Master EOI (0x20 <- 0x20)
    return 1

fn silicon_pic8259_disable
    port_out8(33, 255)
    port_out8(161, 255)
    return 1

// ── Real Hardware Local APIC (MMIO @ 0xFEE00000, single-instruction 32-bit) ───

fn silicon_lapic_read lapic_base reg_off
    return mmio_r32(lapic_base + reg_off)

fn silicon_lapic_write lapic_base reg_off val
    mmio_w32(lapic_base + reg_off, val)
    return 1

fn silicon_lapic_eoi lapic_base
    mmio_w32(lapic_base + 176, 0) // 0xB0 EOI register
    return 1

// ── Real Hardware 8254 PIT Timer (Channel 0, Port 0x40/0x43) ──────────────────

fn silicon_pit_init hz
    divisor = 1193182 / hz
    port_out8(67, 54)                   // 0x43: Channel 0, lobyte/hibyte, mode 3 square wave
    port_out8(64, divisor & 255)        // 0x40: low byte
    port_out8(64, (divisor >> 8) & 255) // 0x40: high byte
    return divisor

// ── QEMU ISA Debug Exit / ACPI Shutdown Helper ────────────────────────────────

fn silicon_qemu_exit code
    // Works with QEMU `-device isa-debug-exit,iobase=0xf4,iosize=0x04`
    port_out32(244, code) // 0xF4
    // Fallback Bochs/QEMU ACPI shutdown ports
    port_out16(1540, 8192) // 0x604 <- 0x2000
    cpu_cli()
    cpu_hlt()
    return 0
