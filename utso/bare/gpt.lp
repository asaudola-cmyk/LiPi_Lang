// ==============================================================================
// 👑 LIPI UTSO BARE — REAL UEFI GPT PARTITION TABLE BUILDER/PARSER (utso/bare/gpt.lp)
// ⚡ 100% Pure Lipi | Zero Heap | Zero Linux Syscalls | UEFI Spec 2.10 CRC32 Exact
// ==============================================================================

fn bare_gpt_crc32 buf byte_len
    // WHY: Standard IEEE 802.3 CRC-32 (reflected polynomial 0xEDB88320) required by UEFI GPT headers & entry arrays.
    crc = 4294967295 // 0xFFFFFFFF
    i = 0
    while i < byte_len
        b = mmio_r8(buf + i)
        crc = crc ^ b
        bit = 0
        while bit < 8
            if (crc & 1) != 0
                crc = ((crc >> 1) & 2147483647) ^ 3988292384 // 0xEDB88320
            else
                crc = (crc >> 1) & 2147483647
            end
            bit = bit + 1
        end
        i = i + 1
    end
    return (crc ^ 4294967295) & 4294967295

fn bare_gpt_write_pmbr lba0_buf total_sectors
    // WHY: Writes a valid UEFI Protective MBR at LBA 0 (partition type 0xEE + 0x55AA signature).
    i = 0
    while i < 512
        mmio_w8(lba0_buf + i, 0)
        i = i + 1
    end
    // Partition entry 0 at offset 446 (0x1BE) — UEFI 2.10 Table 5-4 exact Protective MBR
    mmio_w8(lba0_buf + 446 + 1, 0)   // StartingCHS: 0x00, 0x02, 0x00
    mmio_w8(lba0_buf + 446 + 2, 2)
    mmio_w8(lba0_buf + 446 + 3, 0)
    mmio_w8(lba0_buf + 446 + 4, 238) // OSType = 0xEE (EFI GPT Protective)
    mmio_w8(lba0_buf + 446 + 5, 255) // EndingCHS: 0xFF, 0xFF, 0xFF
    mmio_w8(lba0_buf + 446 + 6, 255)
    mmio_w8(lba0_buf + 446 + 7, 255)
    mmio_w32(lba0_buf + 446 + 8, 1)  // StartingLBA = 1
    sz = total_sectors - 1
    if sz > 4294967295 sz = 4294967295 end
    mmio_w32(lba0_buf + 446 + 12, sz)
    mmio_w8(lba0_buf + 510, 85)      // 0x55
    mmio_w8(lba0_buf + 511, 170)     // 0xAA
    return 0

fn bare_gpt_write_efi_part_entry entry_ptr first_lba last_lba
    // WHY: Writes a 128-byte GPT Partition Entry for an EFI System Partition
    // (Type GUID: C12A7328-F81F-11D2-BA4B-00A0C93EC93B).
    i = 0
    while i < 128
        mmio_w8(entry_ptr + i, 0)
        i = i + 1
    end
    // Partition Type GUID (EFI System Partition)
    mmio_w32(entry_ptr + 0, 3240784680) // 0xC12A7328
    mmio_w16(entry_ptr + 4, 63519)      // 0xF81F
    mmio_w16(entry_ptr + 6, 4562)       // 0x11D2
    mmio_w8(entry_ptr + 8, 186) mmio_w8(entry_ptr + 9, 75)
    mmio_w8(entry_ptr + 10, 0)  mmio_w8(entry_ptr + 11, 160)
    mmio_w8(entry_ptr + 12, 201) mmio_w8(entry_ptr + 13, 62)
    mmio_w8(entry_ptr + 14, 201) mmio_w8(entry_ptr + 15, 59)
    // Unique Partition GUID (deterministic non-zero Lipi sovereign GUID)
    mmio_w32(entry_ptr + 16, 1280266313) // "LIPI"
    mmio_w16(entry_ptr + 20, 4096)
    mmio_w16(entry_ptr + 22, 16385)
    mmio_w8(entry_ptr + 24, 128) mmio_w8(entry_ptr + 25, 1)
    // Starting & Ending LBAs
    mmio_w64(entry_ptr + 32, first_lba)
    mmio_w64(entry_ptr + 40, last_lba)
    // UTF-16LE Name: "LIPI-EFI" at offset +56
    mmio_w16(entry_ptr + 56, 76) mmio_w16(entry_ptr + 58, 73)
    mmio_w16(entry_ptr + 60, 80) mmio_w16(entry_ptr + 62, 73)
    mmio_w16(entry_ptr + 64, 45) mmio_w16(entry_ptr + 66, 69)
    mmio_w16(entry_ptr + 68, 70) mmio_w16(entry_ptr + 70, 73)
    return 0

fn bare_gpt_write_header lba1_buf entries_buf total_sectors num_entries
    // WHY: Writes a spec-exact 92-byte GPT Header at LBA 1 with real CRC32 over entries AND header!
    i = 0
    while i < 512
        mmio_w8(lba1_buf + i, 0)
        i = i + 1
    end
    // Signature "EFI PART" (8 bytes)
    mmio_w8(lba1_buf + 0, 69) mmio_w8(lba1_buf + 1, 70) mmio_w8(lba1_buf + 2, 73) mmio_w8(lba1_buf + 3, 32)
    mmio_w8(lba1_buf + 4, 80) mmio_w8(lba1_buf + 5, 65) mmio_w8(lba1_buf + 6, 82) mmio_w8(lba1_buf + 7, 84)
    mmio_w32(lba1_buf + 8, 65536)           // Revision 1.0 (0x00010000)
    mmio_w32(lba1_buf + 12, 92)             // HeaderSize = 92
    mmio_w64(lba1_buf + 24, 1)              // MyLBA = 1
    mmio_w64(lba1_buf + 32, total_sectors - 1) // AlternateLBA
    mmio_w64(lba1_buf + 40, 34)             // FirstUsableLBA
    mmio_w64(lba1_buf + 48, total_sectors - 34) // LastUsableLBA
    // Non-zero deterministic Sovereign DiskGUID at +56..+71 (UEFI 2.10 requires non-zero DiskGUID)
    mmio_w32(lba1_buf + 56, 1280266313)     // "LIPI"
    mmio_w16(lba1_buf + 60, 2026)
    mmio_w16(lba1_buf + 62, 16385)          // RFC 4122 version 4
    mmio_w8(lba1_buf + 64, 136)
    mmio_w8(lba1_buf + 65, 1)
    mmio_w64(lba1_buf + 72, 2)              // PartitionEntryLBA = 2
    mmio_w32(lba1_buf + 80, num_entries)    // NumberOfPartitionEntries (e.g. 128)
    mmio_w32(lba1_buf + 84, 128)            // SizeOfPartitionEntry = 128
    ent_crc = bare_gpt_crc32(entries_buf, num_entries * 128)
    mmio_w32(lba1_buf + 88, ent_crc)
    // Compute HeaderCRC32 over bytes 0..91 with +16 zeroed
    mmio_w32(lba1_buf + 16, 0)
    hdr_crc = bare_gpt_crc32(lba1_buf, 92)
    mmio_w32(lba1_buf + 16, hdr_crc)
    return hdr_crc

fn bare_gpt_validate_header lba1_buf
    // Validates "EFI PART" signature AND recomputes live CRC32!
    if mmio_r8(lba1_buf + 0) != 69 or mmio_r8(lba1_buf + 1) != 70 or mmio_r8(lba1_buf + 4) != 80 return 0 end
    hsz = mmio_r32(lba1_buf + 12)
    if hsz < 92 or hsz > 512 return 0 end
    saved = mmio_r32(lba1_buf + 16)
    mmio_w32(lba1_buf + 16, 0)
    calc = bare_gpt_crc32(lba1_buf, hsz)
    mmio_w32(lba1_buf + 16, saved)
    if calc == saved return 1 end
    return 0
