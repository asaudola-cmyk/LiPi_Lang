// ==============================================================================
// 👑 LIPI UTSO — REAL ACPI 6.x TABLE PARSER (utso/silicon/acpi.lp)
// ⚡ 100% Pure Lipi | Zero Heap | Zero Linux Syscalls | Ring-0 Freestanding Ready
// ==============================================================================
//
// WHY THIS MODULE:
// Parses genuine ACPI firmware tables (RSDP v1/v2, RSDT, XSDT, MADT/APIC, FADT/FACP,
// MCFG PCIe ECAM) directly from physical/identity-mapped memory via `mmio_r*` intrinsics.
// Every table checksum (sum of all bytes mod 256 == 0) is strictly validated per ACPI 6.5.
// ==============================================================================

fn silicon_acpi_checksum ptr byte_len
    // WHY: ACPI specification requires the 8-bit sum of all bytes in an RSDP/SDT header+body to be 0.
    sum = 0
    i = 0
    while i < byte_len
        sum = (sum + mmio_r8(ptr + i)) & 255
        i = i + 1
    end
    if sum == 0 return 1 end
    return 0

fn silicon_acpi_match_sig ptr b0 b1 b2 b3
    if mmio_r8(ptr + 0) != b0 return 0 end
    if mmio_r8(ptr + 1) != b1 return 0 end
    if mmio_r8(ptr + 2) != b2 return 0 end
    if mmio_r8(ptr + 3) != b3 return 0 end
    return 1

fn silicon_acpi_validate_rsdp rsdp_ptr
    // WHY: Validates 8-byte "RSD PTR " signature + 20-byte ACPI v1 checksum + optional 36-byte v2+ checksum.
    // Returns revision + 1 (1 for ACPI 1.0, 3 for ACPI 2.0+) on success, 0 on failure.
    if rsdp_ptr == 0 return 0 end
    if silicon_acpi_match_sig(rsdp_ptr, 82, 83, 68, 32) == 0 return 0 end     // "RSD "
    if silicon_acpi_match_sig(rsdp_ptr + 4, 80, 84, 82, 32) == 0 return 0 end // "PTR "
    if silicon_acpi_checksum(rsdp_ptr, 20) == 0 return 0 end
    rev = mmio_r8(rsdp_ptr + 15)
    if rev >= 2
        len32 = mmio_r32(rsdp_ptr + 20)
        if len32 < 36 return 0 end
        if silicon_acpi_checksum(rsdp_ptr, len32) == 0 return 0 end
    end
    return rev + 1

fn silicon_acpi_rsdp_rsdt_addr rsdp_ptr
    return mmio_r32(rsdp_ptr + 16)

fn silicon_acpi_rsdp_xsdt_addr rsdp_ptr
    rev = mmio_r8(rsdp_ptr + 15)
    if rev < 2 return 0 end
    return mmio_r64(rsdp_ptr + 24)

fn silicon_acpi_sdt_length sdt_ptr
    return mmio_r32(sdt_ptr + 4)

fn silicon_acpi_validate_sdt sdt_ptr
    if sdt_ptr == 0 return 0 end
    slen = mmio_r32(sdt_ptr + 4)
    if slen < 36 or slen > 1048576 return 0 end
    return silicon_acpi_checksum(sdt_ptr, slen)

fn silicon_acpi_find_table_xsdt xsdt_ptr b0 b1 b2 b3
    // WHY: Walks 64-bit entry pointers inside XSDT (header = 36 bytes, entries = 8 bytes each).
    if silicon_acpi_validate_sdt(xsdt_ptr) == 0 return 0 end
    slen = mmio_r32(xsdt_ptr + 4)
    count = (slen - 36) / 8
    i = 0
    while i < count
        tbl = mmio_r64(xsdt_ptr + 36 + (i * 8))
        if tbl != 0 and silicon_acpi_match_sig(tbl, b0, b1, b2, b3) == 1
            if silicon_acpi_validate_sdt(tbl) == 1
                return tbl
            end
        end
        i = i + 1
    end
    return 0

fn silicon_acpi_find_table_rsdt rsdt_ptr b0 b1 b2 b3
    // WHY: Walks 32-bit entry pointers inside RSDT (header = 36 bytes, entries = 4 bytes each).
    if silicon_acpi_validate_sdt(rsdt_ptr) == 0 return 0 end
    slen = mmio_r32(rsdt_ptr + 4)
    count = (slen - 36) / 4
    i = 0
    while i < count
        tbl = mmio_r32(rsdt_ptr + 36 + (i * 4))
        if tbl != 0 and silicon_acpi_match_sig(tbl, b0, b1, b2, b3) == 1
            if silicon_acpi_validate_sdt(tbl) == 1
                return tbl
            end
        end
        i = i + 1
    end
    return 0

fn silicon_acpi_find_table rsdp_ptr b0 b1 b2 b3
    // WHY: Unified SDT lookup preferring 64-bit XSDT when ACPI revision >= 2, falling back to 32-bit RSDT.
    if silicon_acpi_validate_rsdp(rsdp_ptr) == 0 return 0 end
    xsdt = silicon_acpi_rsdp_xsdt_addr(rsdp_ptr)
    if xsdt != 0
        t = silicon_acpi_find_table_xsdt(xsdt, b0, b1, b2, b3)
        if t != 0 return t end
    end
    rsdt = silicon_acpi_rsdp_rsdt_addr(rsdp_ptr)
    if rsdt != 0
        return silicon_acpi_find_table_rsdt(rsdt, b0, b1, b2, b3)
    end
    return 0

// ── MADT ("APIC") Local APIC & IOAPIC Parser ─────────────────────────────────
// MADT header: +0..35 SDT Header, +36 LocalApicAddress(u32), +40 Flags(u32), +44.. ICS entries
// Entry header: +0 Type(u8), +1 Length(u8)
//   Type 0 = Processor Local APIC (+2 AcpiUid, +3 ApicId, +4 Flags[bit0=enabled])
//   Type 1 = I/O APIC (+2 IoApicId, +4 IoApicAddr(u32), +8 GlobalSysIntBase(u32))
//   Type 2 = Interrupt Source Override (+2 Bus, +3 SourceIrq, +4 GSI(u32), +8 Flags(u16))

fn silicon_acpi_madt_lapic_addr madt_ptr
    return mmio_r32(madt_ptr + 36)

fn silicon_acpi_madt_count_cpus madt_ptr
    if madt_ptr == 0 return 0 end
    total = mmio_r32(madt_ptr + 4)
    off = 44
    cpus = 0
    while off + 2 <= total
        etype = mmio_r8(madt_ptr + off)
        elen = mmio_r8(madt_ptr + off + 1)
        if elen < 2 break end
        if etype == 0 and elen >= 8
            flags = mmio_r32(madt_ptr + off + 4)
            if (flags & 3) != 0
                cpus = cpus + 1
            end
        end
        off = off + elen
    end
    return cpus

fn silicon_acpi_madt_find_ioapic madt_ptr idx
    // Returns physical MMIO base address of the idx-th IOAPIC (0-based), or 0 if not found.
    if madt_ptr == 0 return 0 end
    total = mmio_r32(madt_ptr + 4)
    off = 44
    seen = 0
    while off + 2 <= total
        etype = mmio_r8(madt_ptr + off)
        elen = mmio_r8(madt_ptr + off + 1)
        if elen < 2 break end
        if etype == 1 and elen >= 12
            if seen == idx
                return mmio_r32(madt_ptr + off + 4)
            end
            seen = seen + 1
        end
        off = off + elen
    end
    return 0

// ── FADT ("FACP") Power Management & Reset Extractor ─────────────────────────

fn silicon_acpi_fadt_pm_timer_port fadt_ptr
    return mmio_r32(fadt_ptr + 76)

fn silicon_acpi_fadt_smi_cmd_port fadt_ptr
    return mmio_r32(fadt_ptr + 48)

fn silicon_acpi_fadt_dsdt_addr fadt_ptr
    // Prefers 64-bit X_DSDT (+140) when table length >= 148 and non-zero, else 32-bit DSDT (+40)
    slen = mmio_r32(fadt_ptr + 4)
    if slen >= 148
        xdsdt = mmio_r64(fadt_ptr + 140)
        if xdsdt != 0 return xdsdt end
    end
    return mmio_r32(fadt_ptr + 40)

// ── MCFG PCIe ECAM Base Extractor ("MCFG" +44: 16B entries [BaseAddr:u64, Seg:u16, StartBus:u8, EndBus:u8]) ──

fn silicon_acpi_mcfg_ecam_base mcfg_ptr entry_idx
    if mcfg_ptr == 0 return 0 end
    slen = mmio_r32(mcfg_ptr + 4)
    eoff = 44 + (entry_idx * 16)
    if eoff + 16 > slen return 0 end
    return mmio_r64(mcfg_ptr + eoff)
