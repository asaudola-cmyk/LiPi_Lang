// ==============================================================================
// 👑 LIPI UTSO — REAL PCI / PCIe ECAM ENUMERATOR & BAR DECODER (utso/silicon/pcie.lp)
// ⚡ 100% Pure Lipi | Zero Heap | Zero Linux Syscalls | Ring-0 Hardware I/O
// ==============================================================================
//
// WHY THIS MODULE:
// Implements BOTH legacy x86 PCI Configuration Mechanism #1 (I/O Ports 0xCF8/0xCFC)
// AND modern PCIe Extended Configuration Access Mechanism (ECAM MMIO 4KB/function),
// BAR address/size decoding, bus master/MMIO enable, and MSI capability scanning.
// ==============================================================================

fn silicon_pci_cfg_addr bus dev func reg_off
    // WHY: PCI Config Address format: bit31=Enable | bus[23:16] | dev[15:11] | func[10:8] | reg[7:2]<<2
    return 2147483648 | ((bus & 255) << 16) | ((dev & 31) << 11) | ((func & 7) << 8) | (reg_off & 252)

fn silicon_pci_read32 bus dev func reg_off
    port_out32(3320, silicon_pci_cfg_addr(bus, dev, func, reg_off)) // 0xCF8 CONFIG_ADDRESS
    return port_in32(3324)                                          // 0xCFC CONFIG_DATA

fn silicon_pci_write32 bus dev func reg_off val
    port_out32(3320, silicon_pci_cfg_addr(bus, dev, func, reg_off))
    port_out32(3324, val)
    return 0

fn silicon_pci_read16 bus dev func reg_off
    d = silicon_pci_read32(bus, dev, func, reg_off)
    shift = (reg_off & 2) * 8
    return (d >> shift) & 65535

fn silicon_pci_read8 bus dev func reg_off
    d = silicon_pci_read32(bus, dev, func, reg_off)
    shift = (reg_off & 3) * 8
    return (d >> shift) & 255

// ── PCIe ECAM Memory-Mapped Configuration Space (4096 bytes per function) ────

fn silicon_pcie_ecam_addr ecam_base bus dev func reg_off
    return ecam_base + ((bus & 255) << 20) + ((dev & 31) << 15) + ((func & 7) << 12) + (reg_off & 4092)

fn silicon_pcie_ecam_read32 ecam_base bus dev func reg_off
    return mmio_r32(silicon_pcie_ecam_addr(ecam_base, bus, dev, func, reg_off))

fn silicon_pcie_ecam_write32 ecam_base bus dev func reg_off val
    mmio_w32(silicon_pcie_ecam_addr(ecam_base, bus, dev, func, reg_off), val)
    return 0

fn silicon_pcie_ecam_read16 ecam_base bus dev func reg_off
    return mmio_r16(silicon_pcie_ecam_addr(ecam_base, bus, dev, func, reg_off) + (reg_off & 2))

fn silicon_pcie_ecam_read8 ecam_base bus dev func reg_off
    return mmio_r8(silicon_pcie_ecam_addr(ecam_base, bus, dev, func, reg_off) + (reg_off & 3))

// ── Device Identification, BAR Decoding & Bus Mastering ──────────────────────

fn silicon_pci_vendor_id bus dev func
    return silicon_pci_read16(bus, dev, func, 0)

fn silicon_pci_device_id bus dev func
    return silicon_pci_read16(bus, dev, func, 2)

fn silicon_pci_class_code bus dev func
    // Returns (base_class << 16) | (subclass << 8) | prog_if
    return (silicon_pci_read32(bus, dev, func, 8) >> 8) & 16777215

fn silicon_pci_enable_bus_master bus dev func
    // Sets Command register bits: IO Space (0x1) | Memory Space (0x2) | Bus Master (0x4)
    cmd = silicon_pci_read32(bus, dev, func, 4)
    silicon_pci_write32(bus, dev, func, 4, cmd | 7)
    return 0

fn silicon_pci_read_bar64 bus dev func bar_idx
    // Decodes 32-bit or 64-bit MMIO BAR base address (bar_idx 0..5)
    reg = 16 + (bar_idx * 4)
    lo = silicon_pci_read32(bus, dev, func, reg)
    if (lo & 1) != 0
        // I/O space BAR: mask bottom 2 bits
        return lo & 4294967292
    end
    bar_type = (lo >> 1) & 3
    base = lo & 4294967280 // mask low 4 flag bits (0xFFFFFFF0)
    if bar_type == 2 and bar_idx < 5
        hi = silicon_pci_read32(bus, dev, func, reg + 4)
        base = base | ((hi & 4294967295) << 32)
    end
    return base

fn silicon_pcie_ecam_find_cap ecam_base bus dev func target_cap_id
    // WHY: Walks PCI Express Capability Linked List starting at Config +0x34 (status bit 4 = Cap List).
    status = silicon_pcie_ecam_read16(ecam_base, bus, dev, func, 6)
    if (status & 16) == 0 return 0 end
    cap_ptr = silicon_pcie_ecam_read8(ecam_base, bus, dev, func, 52) & 252
    hops = 0
    while cap_ptr >= 64 and hops < 48
        cid = silicon_pcie_ecam_read8(ecam_base, bus, dev, func, cap_ptr)
        if cid == target_cap_id
            return cap_ptr
        end
        cap_ptr = silicon_pcie_ecam_read8(ecam_base, bus, dev, func, cap_ptr + 1) & 252
        hops = hops + 1
    end
    return 0

fn silicon_pcie_ecam_find_device ecam_base max_bus want_class want_subclass
    // Scans PCIe ECAM buses [0..max_bus-1], devices [0..31], functions [0..7] for class/subclass.
    // Returns packed (bus << 16) | (dev << 8) | func, or -1 if not found.
    bus = 0
    while bus < max_bus
        dev = 0
        while dev < 32
            func = 0
            while func < 8
                vid = silicon_pcie_ecam_read16(ecam_base, bus, dev, func, 0)
                if vid != 65535 and vid != 0
                    cc = (silicon_pcie_ecam_read32(ecam_base, bus, dev, func, 8) >> 16) & 65535
                    bc = (cc >> 8) & 255
                    sc = cc & 255
                    if bc == want_class and sc == want_subclass
                        return (bus << 16) | (dev << 8) | func
                    end
                    if func == 0
                        htype = silicon_pcie_ecam_read8(ecam_base, bus, dev, 0, 14)
                        if (htype & 128) == 0
                            break
                        end
                    end
                elif func == 0
                    break
                end
                func = func + 1
            end
            dev = dev + 1
        end
        bus = bus + 1
    end
    return 0 - 1
