// ==============================================================================
// 👑 LIPI UTSO BARE — REAL ISO 9660 + EL TORITO IMAGE BUILDER (utso/bare/iso9660.lp)
// ⚡ 100% Pure Lipi | Zero Heap | Zero Linux Syscalls | ECMA-119 + El Torito Spec
// ==============================================================================

fn bare_iso_write_both_u16 ptr val
    // WHY: ISO 9660 uses dual-endian ("both-byte order") 16-bit fields: LE then BE.
    mmio_w8(ptr + 0, val & 255)
    mmio_w8(ptr + 1, (val >> 8) & 255)
    mmio_w8(ptr + 2, (val >> 8) & 255)
    mmio_w8(ptr + 3, val & 255)
    return 0

fn bare_iso_write_both_u32 ptr val
    // WHY: ISO 9660 dual-endian 32-bit fields: 4-byte LE followed by 4-byte BE.
    b0 = val & 255
    b1 = (val >> 8) & 255
    b2 = (val >> 16) & 255
    b3 = (val >> 24) & 255
    mmio_w8(ptr + 0, b0) mmio_w8(ptr + 1, b1) mmio_w8(ptr + 2, b2) mmio_w8(ptr + 3, b3)
    mmio_w8(ptr + 4, b3) mmio_w8(ptr + 5, b2) mmio_w8(ptr + 6, b1) mmio_w8(ptr + 7, b0)
    return 0

fn bare_iso_write_pvd pvd_sec vol_space_blocks root_dir_lba root_dir_size
    // WHY: Builds a 2048-byte ISO 9660 Primary Volume Descriptor (sector 16, type=1, "CD001", ver=1).
    i = 0
    while i < 2048
        mmio_w8(pvd_sec + i, 0)
        i = i + 1
    end
    mmio_w8(pvd_sec + 0, 1) // Type 1 = Primary Volume Descriptor
    // Standard Identifier "CD001" + Version 1
    mmio_w8(pvd_sec + 1, 67) mmio_w8(pvd_sec + 2, 68) mmio_w8(pvd_sec + 3, 48)
    mmio_w8(pvd_sec + 4, 48) mmio_w8(pvd_sec + 5, 49) mmio_w8(pvd_sec + 6, 1)
    // Fill Volume Identifier (+40..71) with spaces then "LIPI_OS"
    j = 40
    while j < 72
        mmio_w8(pvd_sec + j, 32)
        j = j + 1
    end
    mmio_w8(pvd_sec + 40, 76) mmio_w8(pvd_sec + 41, 73) mmio_w8(pvd_sec + 42, 80)
    mmio_w8(pvd_sec + 43, 73) mmio_w8(pvd_sec + 44, 95) mmio_w8(pvd_sec + 45, 79) mmio_w8(pvd_sec + 46, 83)
    bare_iso_write_both_u32(pvd_sec + 80, vol_space_blocks) // Volume Space Size
    bare_iso_write_both_u16(pvd_sec + 120, 1)               // Volume Set Size
    bare_iso_write_both_u16(pvd_sec + 124, 1)               // Volume Sequence Number
    bare_iso_write_both_u16(pvd_sec + 128, 2048)            // Logical Block Size = 2048
    // Root Directory Record (34 bytes) at offset +156
    mmio_w8(pvd_sec + 156 + 0, 34)
    bare_iso_write_both_u32(pvd_sec + 156 + 2, root_dir_lba)
    bare_iso_write_both_u32(pvd_sec + 156 + 10, root_dir_size)
    mmio_w8(pvd_sec + 156 + 25, 2)  // Flags = Directory (0x02)
    bare_iso_write_both_u16(pvd_sec + 156 + 28, 1)
    mmio_w8(pvd_sec + 156 + 32, 1)  // File ID Len = 1
    mmio_w8(pvd_sec + 156 + 33, 0)  // Root ID = 0x00
    mmio_w8(pvd_sec + 881, 1)       // File Structure Version = 1
    return 0

fn bare_iso_write_eltorito_catalog cat_sec boot_img_lba sector_count platform_id
    // WHY: Builds a 2048-byte El Torito Boot Catalog (Validation Entry with 16-bit checksum + Initial Entry).
    // platform_id: 0 = 80x86 BIOS, 0xEF (239) = UEFI!
    i = 0
    while i < 2048
        mmio_w8(cat_sec + i, 0)
        i = i + 1
    end
    // Validation Entry (bytes 0..31)
    mmio_w8(cat_sec + 0, 1)                  // Header ID = 0x01
    mmio_w8(cat_sec + 1, platform_id & 255)  // Platform ID (0x00 BIOS / 0xEF UEFI)
    mmio_w8(cat_sec + 30, 85)                // Key byte 0x55
    mmio_w8(cat_sec + 31, 170)               // Key byte 0xAA
    // Compute 16-bit two's-complement checksum across words 0..15 so sum == 0 mod 65536
    wsum = 0
    wi = 0
    while wi < 32
        if wi != 28
            wsum = (wsum + mmio_r16(cat_sec + wi)) & 65535
        end
        wi = wi + 2
    end
    chk = (65536 - wsum) & 65535
    mmio_w16(cat_sec + 28, chk)
    // Initial/Default Entry (bytes 32..63): Bootable (0x88), No Emulation (0x00), sector_count, load_rba
    mmio_w8(cat_sec + 32, 136)               // 0x88 = Bootable
    mmio_w8(cat_sec + 33, 0)                 // 0x00 = No Emulation
    mmio_w16(cat_sec + 38, sector_count & 65535)
    mmio_w32(cat_sec + 40, boot_img_lba)
    return chk

fn bare_iso_validate_pvd pvd_sec
    if mmio_r8(pvd_sec + 0) != 1 return 0 end
    if mmio_r8(pvd_sec + 1) != 67 or mmio_r8(pvd_sec + 2) != 68 or mmio_r8(pvd_sec + 5) != 49 return 0 end
    if mmio_r16(pvd_sec + 128) != 2048 return 0 end
    return 1
