// ==============================================================================
// 👑 LIPI UNIVERSE FS: EXT4 SOVEREIGN FILESYSTEM ENGINE (universe/fs/ext4.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign OS Kernel Layer
//
// WHY: Native Ext4 parser enables Lipi bare-metal unikernels and microVMs to mount
//      and read production Linux disk images, rootfs partitions, and raw block devices
//      directly without any host kernel or VFS C drivers.
//
// Architecture & Invariants:
// 1. Superblock Parsing (Offset 1024): Validates 0xEF53 magic, calculates block size
//    (1024 << s_log_block_size), blocks/inodes per group, and volume geometry.
// 2. Block Group Descriptors (BGD): Locates block/inode bitmaps and inode tables.
// 3. Inode & Extent Tree: Traverses Ext4 Extent Tree (Magic 0xF30A) to map logical
//    file offsets to contiguous physical disk block ranges.
// 4. Directory Traversal (ext4_dir_entry_2): Parses variable-length directory entries.
// ==============================================================================

include "universe/core/io.lp"
include "universe/core/memory.lp"
include "universe/core/string.lp"

// ── 1. Ext4 Hardware Constants ────────────────────────────────────────────────
EXT4_SUPERBLOCK_OFFSET     = 1024
EXT4_SUPERBLOCK_MAGIC      = 61267       // 0xEF53
EXT4_EXTENT_HEADER_MAGIC   = 62218       // 0xF30A
EXT4_ROOT_INO              = 2           // Standard root directory inode number

// Inode File Types
EXT4_FT_UNKNOWN            = 0
EXT4_FT_REG_FILE           = 1
EXT4_FT_DIR                = 2
EXT4_FT_CHRDEV             = 3
EXT4_FT_BLKDEV             = 4
EXT4_FT_FIFO               = 5
EXT4_FT_SOCK               = 6
EXT4_FT_SYMLINK            = 7

// ── 2. Data Models (Hardware Aligned) ─────────────────────────────────────────

struct Ext4Superblock
    s_magic
    s_inodes_count
    s_blocks_count
    s_free_blocks_count
    s_free_inodes_count
    s_first_data_block
    s_log_block_size
    s_block_size
    s_blocks_per_group
    s_inodes_per_group
    s_inode_size
    s_volume_name

struct Ext4BlockGroup
    bg_block_bitmap
    bg_inode_bitmap
    bg_inode_table
    bg_free_blocks_count
    bg_free_inodes_count
    bg_used_dirs_count

struct Ext4Extent
    ee_block           // Logical first block of extent
    ee_len             // Number of blocks covered
    ee_start           // Physical block address on disk

struct Ext4Inode
    i_ino
    i_mode             // File type and permissions
    i_size             // 64-bit file size in bytes
    i_links_count
    i_blocks           // 512-byte blocks allocated
    i_flags            // Flags (e.g. 0x80000 = Extents used)
    i_extents          // list of Ext4Extent records
    i_is_extent_tree

struct Ext4DirEntry
    de_inode
    de_rec_len
    de_name_len
    de_file_type
    de_name

struct Ext4FileSystem
    fs_dev_fd
    fs_sb
    fs_block_groups
    fs_bg_count
    fs_is_mounted

// ── 3. Binary Byte Decoding Helpers (Little-Endian) ───────────────────────────

fn ext4_read_u16 buf off
    b0 = mem_byte_read(buf, off) & 255
    b1 = mem_byte_read(buf, off + 1) & 255
    return b0 + (b1 * 256)

fn ext4_read_u32 buf off
    b0 = mem_byte_read(buf, off) & 255
    b1 = mem_byte_read(buf, off + 1) & 255
    b2 = mem_byte_read(buf, off + 2) & 255
    b3 = mem_byte_read(buf, off + 3) & 255
    return b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)

// ── 4. Superblock Parser ──────────────────────────────────────────────────────

fn ext4_parse_superblock buf
    // WHY: Verifies magic 0xEF53 at offset 56 within the superblock buffer (total offset 1080).
    magic = ext4_read_u16(buf, 56)
    if magic != EXT4_SUPERBLOCK_MAGIC
        return 0

    sb = Ext4Superblock()
    sb.s_magic = magic
    sb.s_inodes_count = ext4_read_u32(buf, 0)
    sb.s_blocks_count = ext4_read_u32(buf, 4)
    sb.s_free_blocks_count = ext4_read_u32(buf, 12)
    sb.s_free_inodes_count = ext4_read_u32(buf, 16)
    sb.s_first_data_block = ext4_read_u32(buf, 20)
    log_bs = ext4_read_u32(buf, 24)
    sb.s_log_block_size = log_bs
    
    // Block size = 1024 << log_bs
    bs = 1024
    step = 0
    while step < log_bs
        bs = bs * 2
        step = step + 1
    sb.s_block_size = bs

    sb.s_blocks_per_group = ext4_read_u32(buf, 32)
    sb.s_inodes_per_group = ext4_read_u32(buf, 40)
    
    ino_sz = ext4_read_u16(buf, 88)
    if ino_sz == 0 ino_sz = 128
    sb.s_inode_size = ino_sz

    // Read volume name string (offset 120, max 16 chars)
    vname = ""
    vi = 0
    while vi < 16
        ch = mem_byte_read(buf, 120 + vi)
        if ch == 0 break
        vname = vname + chr(ch)
        vi = vi + 1
    sb.s_volume_name = vname
    return sb

// ── 5. Extent Tree Parser ─────────────────────────────────────────────────────

fn ext4_parse_inode_extents buf ino_off
    // Extent header begins at offset 40 of inode (i_block array)
    hdr_off = ino_off + 40
    eh_magic = ext4_read_u16(buf, hdr_off)
    extents = list()
    if eh_magic != EXT4_EXTENT_HEADER_MAGIC
        return extents

    eh_entries = ext4_read_u16(buf, hdr_off + 2)
    eh_depth = ext4_read_u16(buf, hdr_off + 6)

    // For leaf nodes (eh_depth == 0), parse extent records
    if eh_depth == 0
        ei = 0
        rec_off = hdr_off + 12
        while ei < eh_entries
            ext = Ext4Extent()
            ext.ee_block = ext4_read_u32(buf, rec_off)
            ext.ee_len = ext4_read_u16(buf, rec_off + 4)
            start_hi = ext4_read_u16(buf, rec_off + 6)
            start_lo = ext4_read_u32(buf, rec_off + 8)
            ext.ee_start = start_lo + (start_hi * 4294967296)
            push(extents, ext)
            rec_off = rec_off + 12
            ei = ei + 1
    return extents

// ── 6. Inode Parser ───────────────────────────────────────────────────────────

fn ext4_parse_inode buf ino_off ino_num
    ino = Ext4Inode()
    ino.i_ino = ino_num
    ino.i_mode = ext4_read_u16(buf, ino_off)
    
    sz_lo = ext4_read_u32(buf, ino_off + 4)
    sz_hi = ext4_read_u32(buf, ino_off + 108) // i_size_high for 64-bit sizes
    ino.i_size = sz_lo + (sz_hi * 4294967296)

    ino.i_links_count = ext4_read_u16(buf, ino_off + 26)
    ino.i_blocks = ext4_read_u32(buf, ino_off + 28)
    ino.i_flags = ext4_read_u32(buf, ino_off + 32)
    
    // Check EXT4_EXTENTS_FL (0x80000)
    flags = ino.i_flags
    if (flags & 524288) != 0
        ino.i_is_extent_tree = 1
        ino.i_extents = ext4_parse_inode_extents(buf, ino_off)
    else
        ino.i_is_extent_tree = 0
        ino.i_extents = list()

    return ino

// ── 7. Directory Entry 2 Parser ───────────────────────────────────────────────

fn ext4_parse_directory_entries buf block_len
    // WHY: Traverses linked list of ext4_dir_entry_2 records across a directory block.
    entries = list()
    off = 0
    while off < block_len
        ino = ext4_read_u32(buf, off)
        rec_len = ext4_read_u16(buf, off + 4)
        if rec_len <= 0 or (off + rec_len) > block_len
            break

        if ino > 0 // Active directory entry
            name_len = mem_byte_read(buf, off + 6) & 255
            ftype = mem_byte_read(buf, off + 7) & 255
            dname = ""
            ni = 0
            while ni < name_len
                ch = mem_byte_read(buf, off + 8 + ni)
                dname = dname + chr(ch)
                ni = ni + 1

            de = Ext4DirEntry()
            de.de_inode = ino
            de.de_rec_len = rec_len
            de.de_name_len = name_len
            de.de_file_type = ftype
            de.de_name = dname
            push(entries, de)

        off = off + rec_len
    return entries

// ── 8. High-Level Mount & Inspection Engine ───────────────────────────────────

fn ext4_mount dev_fd
    // WHY: Reads superblock at 1024 bytes and initializes filesystem state.
    sb_buf = malloc(1024)
    // lseek to 1024: syscall 8 (sys_lseek)
    syscall(8, dev_fd, EXT4_SUPERBLOCK_OFFSET, 0, 0, 0, 0)
    bytes_read = syscall(0, dev_fd, sb_buf, 1024, 0, 0, 0)
    if bytes_read < 1024
        free(sb_buf, 1024)
        return 0

    sb = ext4_parse_superblock(sb_buf)
    free(sb_buf, 1024)
    if sb == 0
        return 0

    fs = Ext4FileSystem()
    fs.fs_dev_fd = dev_fd
    fs.fs_sb = sb
    fs.fs_block_groups = list()
    
    // Calculate total block groups
    total_blks = sb.s_blocks_count
    blks_per_grp = sb.s_blocks_per_group
    bg_count = (total_blks + blks_per_grp - 1) / blks_per_grp
    fs.fs_bg_count = bg_count
    fs.fs_is_mounted = 1
    return fs
