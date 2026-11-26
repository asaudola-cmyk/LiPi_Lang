// ==============================================================================
// 👑 LIPI UTSO — REAL NVMe 1.4/2.0 CONTROLLER DRIVER (utso/silicon/nvme.lp)
// ⚡ 100% Pure Lipi | Zero Heap | Zero Linux Syscalls | Direct BAR0 MMIO + Queues
// ==============================================================================
//
// WHY THIS MODULE:
// Implements NVMe Base Specification 1.4/2.0 BAR0 register access (CAP, VS, CC, CSTS,
// AQA, ASQ, ACQ, Submission/Completion Doorbells), 64-byte SQE construction for
// Identify/Read/Write, and 16-byte CQE phase-tag completion polling.
// ==============================================================================

// NVMe BAR0 Register Offsets:
//   +0x00 CAP(u64), +0x08 VS(u32), +0x14 CC(u32), +0x1C CSTS(u32)
//   +0x24 AQA(u32), +0x28 ASQ(u64), +0x30 ACQ(u64), +0x1000 Doorbells

fn silicon_nvme_cap bar0
    return mmio_r64(bar0 + 0)

fn silicon_nvme_version bar0
    return mmio_r32(bar0 + 8)

fn silicon_nvme_doorbell_stride bar0
    cap = mmio_r64(bar0 + 0)
    dstrd = (cap >> 32) & 15
    return 4 << dstrd

fn silicon_nvme_disable bar0 max_spins
    // Clears CC.EN (bit 0) and polls CSTS.RDY (bit 0) until 0
    cc = mmio_r32(bar0 + 20)
    mmio_w32(bar0 + 20, cc & (0 - 2))
    sp = 0
    while sp < max_spins
        if (mmio_r32(bar0 + 28) & 1) == 0 return 1 end
        sp = sp + 1
    end
    return 0

fn silicon_nvme_init_admin_queues bar0 asq_phys acq_phys q_entries max_spins
    // WHY: Configures AQA, ASQ, ACQ, then enables controller with 64B SQE (IOSQES=6) & 16B CQE (IOCQES=4).
    if silicon_nvme_disable(bar0, max_spins) == 0 return 0 end
    qsz = (q_entries - 1) & 4095
    aqa = (qsz << 16) | qsz
    mmio_w32(bar0 + 36, aqa)       // AQA (+0x24)
    mmio_w64(bar0 + 40, asq_phys)  // ASQ (+0x28)
    mmio_w64(bar0 + 48, acq_phys)  // ACQ (+0x30)
    // CC: EN=1 | CSS=0 | MPS=0 (4KB) | AMS=0 | SHN=0 | IOSQES=6 (<<16) | IOCQES=4 (<<20)
    cc_val = 1 | (6 << 16) | (4 << 20)
    mmio_w32(bar0 + 20, cc_val)
    sp = 0
    while sp < max_spins
        if (mmio_r32(bar0 + 28) & 1) != 0 return 1 end
        sp = sp + 1
    end
    return 0

fn silicon_nvme_build_sqe sq_entry_ptr opcode cid nsid prp1 prp2 cdw10 cdw11 cdw12
    // WHY: Populates a 64-byte NVMe Submission Queue Entry (16 dwords, spec Fig. 35).
    i = 0
    while i < 64
        mmio_w32(sq_entry_ptr + i, 0)
        i = i + 4
    end
    mmio_w32(sq_entry_ptr + 0, (opcode & 255) | ((cid & 65535) << 16))
    mmio_w32(sq_entry_ptr + 4, nsid)
    mmio_w64(sq_entry_ptr + 24, prp1)
    mmio_w64(sq_entry_ptr + 32, prp2)
    mmio_w32(sq_entry_ptr + 40, cdw10)
    mmio_w32(sq_entry_ptr + 44, cdw11)
    mmio_w32(sq_entry_ptr + 48, cdw12)
    return 0

fn silicon_nvme_ring_sq_doorbell bar0 qid new_tail
    stride = silicon_nvme_doorbell_stride(bar0)
    db_off = 4096 + ((2 * qid) * stride)
    mmio_w32(bar0 + db_off, new_tail & 65535)
    return 0

fn silicon_nvme_ring_cq_doorbell bar0 qid new_head
    stride = silicon_nvme_doorbell_stride(bar0)
    db_off = 4096 + (((2 * qid) + 1) * stride)
    mmio_w32(bar0 + db_off, new_head & 65535)
    return 0

fn silicon_nvme_cqe_ready cq_entry_ptr expected_phase
    // WHY: CQE DW3 (+12) bit 16 is Phase Tag (P); bits 31..17 are Status Field (0 = success).
    dw3 = mmio_r32(cq_entry_ptr + 12)
    phase = (dw3 >> 16) & 1
    if phase == (expected_phase & 1) return 1 end
    return 0

fn silicon_nvme_cqe_status cq_entry_ptr
    dw3 = mmio_r32(cq_entry_ptr + 12)
    return (dw3 >> 17) & 32767
