// ==============================================================================
// 👑 LIPI UTSO — REAL AHCI SATA HBA DRIVER (utso/silicon/ahci.lp)
// ⚡ 100% Pure Lipi | Zero Heap | Zero Linux Syscalls | AHCI 1.3.1 ABAR MMIO
// ==============================================================================

// AHCI Generic Host Control (ABAR + 0x00..0x2B):
//   +0x00 CAP(u32), +0x04 GHC(u32: bit31=AE), +0x0C PI(u32: Ports Implemented)
// Port N registers start at ABAR + 0x100 + (N * 0x80):
//   +0x00 CLB(u32), +0x04 CLBU(u32), +0x08 FB(u32), +0x0C FBU(u32)
//   +0x10 IS(u32),  +0x18 CMD(u32: bit0=ST, bit4=FRE, bit14=FR, bit15=CR)
//   +0x20 TFD(u32), +0x24 SIG(u32), +0x28 SSTS(u32), +0x38 CI(u32)

fn silicon_ahci_port_base abar port_idx
    return abar + 256 + (port_idx * 128)

fn silicon_ahci_enable abar
    ghc = mmio_r32(abar + 4)
    mmio_w32(abar + 4, ghc | 2147483648) // GHC.AE = 1
    return mmio_r32(abar + 12)           // Return Ports Implemented bitmask

fn silicon_ahci_port_present abar port_idx
    p = silicon_ahci_port_base(abar, port_idx)
    ssts = mmio_r32(p + 40)
    det = ssts & 15
    ipm = (ssts >> 8) & 15
    if det == 3 and ipm == 1 return 1 end
    return 0

fn silicon_ahci_port_stop abar port_idx max_spins
    p = silicon_ahci_port_base(abar, port_idx)
    cmd = mmio_r32(p + 24)
    // Clear ST (bit 0) and FRE (bit 4)
    mmio_w32(p + 24, cmd & (0 - 18))
    sp = 0
    while sp < max_spins
        st = mmio_r32(p + 24)
        if (st & 49152) == 0 return 1 end // Both FR (bit14) & CR (bit15) cleared
        sp = sp + 1
    end
    return 0

fn silicon_ahci_port_rebase abar port_idx clb_phys fb_phys max_spins
    if silicon_ahci_port_stop(abar, port_idx, max_spins) == 0 return 0 end
    p = silicon_ahci_port_base(abar, port_idx)
    mmio_w32(p + 0, clb_phys & 4294967295)
    mmio_w32(p + 4, (clb_phys >> 32) & 4294967295)
    mmio_w32(p + 8, fb_phys & 4294967295)
    mmio_w32(p + 12, (fb_phys >> 32) & 4294967295)
    mmio_w32(p + 16, 4294967295) // Clear pending PxIS
    // Re-enable FRE (bit 4) and ST (bit 0)
    cmd = mmio_r32(p + 24)
    mmio_w32(p + 24, cmd | 17)
    return 1

fn silicon_ahci_build_dma_read_cmd cmd_hdr_ptr cmd_tbl_ptr cmd_tbl_phys lba sector_cnt dst_phys
    // WHY: Builds AHCI Command Header (32B) + Register H2D FIS (0x27, ATA READ DMA EXT 0x25) + 1 PRDT entry.
    // Command Header DW0: CFL=5 dwords (20B H2D FIS) | PRDTL=1 (<<16)
    mmio_w32(cmd_hdr_ptr + 0, 5 | (1 << 16))
    mmio_w32(cmd_hdr_ptr + 4, 0)
    mmio_w32(cmd_hdr_ptr + 8, cmd_tbl_phys & 4294967295)
    mmio_w32(cmd_hdr_ptr + 12, (cmd_tbl_phys >> 32) & 4294967295)

    // Zero CFIS (0..63) and populate 20-byte FIS_REG_H2D (type 0x27)
    ci = 0
    while ci < 64
        mmio_w32(cmd_tbl_ptr + ci, 0)
        ci = ci + 4
    end
    mmio_w8(cmd_tbl_ptr + 0, 39)  // FIS_TYPE_REG_H2D (0x27)
    mmio_w8(cmd_tbl_ptr + 1, 128) // C=1 (Command)
    mmio_w8(cmd_tbl_ptr + 2, 37)  // ATA_CMD_READ_DMA_EX (0x25)
    mmio_w8(cmd_tbl_ptr + 4, lba & 255)
    mmio_w8(cmd_tbl_ptr + 5, (lba >> 8) & 255)
    mmio_w8(cmd_tbl_ptr + 6, (lba >> 16) & 255)
    mmio_w8(cmd_tbl_ptr + 7, 64)  // LBA mode (bit 6)
    mmio_w8(cmd_tbl_ptr + 8, (lba >> 24) & 255)
    mmio_w8(cmd_tbl_ptr + 9, (lba >> 32) & 255)
    mmio_w8(cmd_tbl_ptr + 10, (lba >> 40) & 255)
    mmio_w8(cmd_tbl_ptr + 12, sector_cnt & 255)
    mmio_w8(cmd_tbl_ptr + 13, (sector_cnt >> 8) & 255)

    // PRDT[0] starts at cmd_tbl + 0x80 (128): DBA(u32), DBAU(u32), rsvd(u32), DBC(bytes-1)
    prdt = cmd_tbl_ptr + 128
    mmio_w32(prdt + 0, dst_phys & 4294967295)
    mmio_w32(prdt + 4, (dst_phys >> 32) & 4294967295)
    mmio_w32(prdt + 8, 0)
    mmio_w32(prdt + 12, ((sector_cnt * 512) - 1) | 2147483648) // DBC + Interrupt on Completion
    return 0

fn silicon_ahci_issue_slot abar port_idx slot_idx
    p = silicon_ahci_port_base(abar, port_idx)
    mmio_w32(p + 56, 1 << (slot_idx & 31)) // PxCI (+0x38)
    return 0
