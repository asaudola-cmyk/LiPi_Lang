// ==============================================================================
// 👑 LIPI UTSO BARE — REAL FAT32 FILESYSTEM BUILDER/READER (utso/bare/fat32.lp)
// ⚡ 100% Pure Lipi | Zero Heap | Zero Linux Syscalls | UEFI ESP FAT32 Compliant
// ==============================================================================

fn bare_fat32_write_bpb boot_sec total_sectors sectors_per_fat
    // WHY: Formats a standards-compliant FAT32 BIOS Parameter Block (512B LBA 0 of partition)
    // with 512B/sector, 1 sector/cluster, 32 reserved sectors, 2 FATs, root cluster 2, and 0x55AA signature.
    i = 0
    while i < 512
        mmio_w8(boot_sec + i, 0)
        i = i + 1
    end
    // Jump boot: EB 58 90
    mmio_w8(boot_sec + 0, 235) mmio_w8(boot_sec + 1, 88) mmio_w8(boot_sec + 2, 144)
    // OEM Name: "LIPIFS32"
    mmio_w8(boot_sec + 3, 76) mmio_w8(boot_sec + 4, 73) mmio_w8(boot_sec + 5, 80) mmio_w8(boot_sec + 6, 73)
    mmio_w8(boot_sec + 7, 70) mmio_w8(boot_sec + 8, 83) mmio_w8(boot_sec + 9, 51) mmio_w8(boot_sec + 10, 50)
    mmio_w16(boot_sec + 11, 512)              // BPB_BytsPerSec = 512
    mmio_w8(boot_sec + 13, 1)                 // BPB_SecPerClus = 1
    mmio_w16(boot_sec + 14, 32)               // BPB_RsvdSecCnt = 32
    mmio_w8(boot_sec + 16, 2)                 // BPB_NumFATs = 2
    mmio_w8(boot_sec + 21, 248)               // BPB_Media = 0xF8 (fixed disk)
    mmio_w32(boot_sec + 32, total_sectors)    // BPB_TotSec32
    mmio_w32(boot_sec + 36, sectors_per_fat)  // BPB_FATSz32
    mmio_w32(boot_sec + 44, 2)                // BPB_RootClus = 2
    mmio_w16(boot_sec + 48, 1)                // BPB_FSInfo = 1
    mmio_w16(boot_sec + 50, 6)                // BPB_BkBootSec = 6
    mmio_w8(boot_sec + 66, 41)                // BS_BootSig = 0x29
    // BS_FilSysType = "FAT32   " at offset 82
    mmio_w8(boot_sec + 82, 70) mmio_w8(boot_sec + 83, 65) mmio_w8(boot_sec + 84, 84)
    mmio_w8(boot_sec + 85, 51) mmio_w8(boot_sec + 86, 50)
    mmio_w8(boot_sec + 87, 32) mmio_w8(boot_sec + 88, 32) mmio_w8(boot_sec + 89, 32)
    mmio_w8(boot_sec + 510, 85)               // 0x55
    mmio_w8(boot_sec + 511, 170)              // 0xAA
    return 0

fn bare_fat32_write_fsinfo fsinfo_sec free_clusters next_free
    i = 0
    while i < 512
        mmio_w8(fsinfo_sec + i, 0)
        i = i + 1
    end
    mmio_w32(fsinfo_sec + 0, 1096897106)   // FSI_LeadSig = 0x41615252
    mmio_w32(fsinfo_sec + 484, 1631679090) // FSI_StrucSig = 0x61417272
    mmio_w32(fsinfo_sec + 488, free_clusters)
    mmio_w32(fsinfo_sec + 492, next_free)
    mmio_w32(fsinfo_sec + 508, 2857697280) // FSI_TrailSig = 0xAA550000
    return 0

fn bare_fat32_init_fat fat_buf
    // Initializes FAT[0] (media), FAT[1] (EOC), FAT[2] (Root Directory EOC)
    mmio_w32(fat_buf + 0, 268435448) // 0x0FFFFFF8
    mmio_w32(fat_buf + 4, 268435455) // 0x0FFFFFFF
    mmio_w32(fat_buf + 8, 268435455) // Cluster 2 EOC
    return 0

fn bare_fat32_set_cluster fat_buf cluster next_val
    mmio_w32(fat_buf + (cluster * 4), next_val & 268435455)
    return 0

fn bare_fat32_get_cluster fat_buf cluster
    return mmio_r32(fat_buf + (cluster * 4)) & 268435455

fn bare_fat32_write_dirent ent_ptr name11_ptr attr first_cluster file_size
    // Writes a 32-byte FAT32 8.3 directory entry (zero-initialized to prevent dirty NTRes/timestamp leaks)
    z = 0
    while z < 32
        mmio_w8(ent_ptr + z, 0)
        z = z + 1
    end
    i = 0
    while i < 11
        mmio_w8(ent_ptr + i, mmio_r8(name11_ptr + i))
        i = i + 1
    end
    mmio_w8(ent_ptr + 11, attr & 255)
    mmio_w16(ent_ptr + 20, (first_cluster >> 16) & 65535) // FstClusHI
    mmio_w16(ent_ptr + 26, first_cluster & 65535)         // FstClusLO
    mmio_w32(ent_ptr + 28, file_size & 4294967295)
    return 0

fn bare_fat32_data_start_lba boot_sec
    rsvd = mmio_r16(boot_sec + 14)
    nfats = mmio_r8(boot_sec + 16)
    fatsz = mmio_r32(boot_sec + 36)
    return rsvd + (nfats * fatsz)

fn bare_fat32_cluster_to_lba boot_sec cluster
    spc = mmio_r8(boot_sec + 13)
    return bare_fat32_data_start_lba(boot_sec) + ((cluster - 2) * spc)
