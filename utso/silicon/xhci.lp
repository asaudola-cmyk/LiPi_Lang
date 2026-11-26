// ==============================================================================
// 👑 LIPI UTSO — REAL xHCI USB 3.x HOST CONTROLLER DRIVER (utso/silicon/xhci.lp)
// ⚡ 100% Pure Lipi | Zero Heap | Zero Linux Syscalls | xHCI 1.2 MMIO + TRB Rings
// ==============================================================================

// xHCI Capability Regs (bar0):
//   +0x00 CAPLENGTH(u8), +0x02 HCIVERSION(u16), +0x04 HCSPARAMS1(u32)
//   +0x14 DBOFF(u32), +0x18 RTSOFF(u32)
// Operational Regs (op_base = bar0 + CAPLENGTH):
//   +0x00 USBCMD(u32: bit0=R/S, bit1=HCRST), +0x04 USBSTS(u32: bit0=HCH, bit11=CNR)
//   +0x18 CRCR(u64), +0x30 DCBAAP(u64), +0x38 CONFIG(u32)

fn silicon_xhci_op_base bar0
    cap_len = mmio_r8(bar0 + 0)
    return bar0 + cap_len

fn silicon_xhci_db_base bar0
    return bar0 + (mmio_r32(bar0 + 20) & 4294967292)

fn silicon_xhci_rt_base bar0
    return bar0 + (mmio_r32(bar0 + 24) & 4294967264)

fn silicon_xhci_max_slots bar0
    return mmio_r32(bar0 + 4) & 255

fn silicon_xhci_max_ports bar0
    return (mmio_r32(bar0 + 4) >> 24) & 255

fn silicon_xhci_reset bar0 max_spins
    op = silicon_xhci_op_base(bar0)
    // Halt controller (clear R/S bit 0)
    cmd = mmio_r32(op + 0)
    mmio_w32(op + 0, cmd & (0 - 2))
    sp = 0
    while sp < max_spins
        if (mmio_r32(op + 4) & 1) != 0 break end // Wait for HCHalted
        sp = sp + 1
    end
    // Trigger HCRST (bit 1)
    mmio_w32(op + 0, 2)
    sp = 0
    while sp < max_spins
        if (mmio_r32(op + 0) & 2) == 0 and (mmio_r32(op + 4) & 2048) == 0
            return 1
        end
        sp = sp + 1
    end
    return 0

fn silicon_xhci_configure bar0 max_slots dcbaa_phys cmd_ring_phys
    op = silicon_xhci_op_base(bar0)
    mmio_w32(op + 56, max_slots & 255)      // CONFIG (+0x38)
    mmio_w64(op + 48, dcbaa_phys)           // DCBAAP (+0x30)
    mmio_w64(op + 24, cmd_ring_phys | 1)    // CRCR (+0x18) with RCS=1
    return 0

fn silicon_xhci_start bar0
    op = silicon_xhci_op_base(bar0)
    cmd = mmio_r32(op + 0)
    mmio_w32(op + 0, cmd | 5) // R/S (bit0) | INTE (bit2)
    return 0

fn silicon_xhci_write_trb trb_ptr param64 status32 trb_type cycle_bit flags
    // WHY: Writes a 16-byte xHCI Transfer/Command/Event Request Block (Spec 4.11).
    mmio_w64(trb_ptr + 0, param64)
    mmio_w32(trb_ptr + 8, status32)
    ctrl = (cycle_bit & 1) | ((trb_type & 63) << 10) | flags
    mmio_w32(trb_ptr + 12, ctrl)
    return 0

fn silicon_xhci_ring_doorbell bar0 slot_id target
    db = silicon_xhci_db_base(bar0)
    mmio_w32(db + (slot_id * 4), target & 255)
    return 0
