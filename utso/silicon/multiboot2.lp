// ==============================================================================
// 👑 LIPI UTSO — REAL MULTIBOOT2 BOOT INFO TAG PARSER (utso/silicon/multiboot2.lp)
// ⚡ 100% Pure Lipi | Zero Heap | Zero Linux Syscalls | Ring-0 Freestanding Ready
// ==============================================================================
//
// WHY THIS MODULE:
// Parses genuine Multiboot2 Boot Information Structures passed in EBX/RSI by GRUB2,
// Limine, or QEMU (`magic == 0x36D76289`), walking 8-byte-aligned tags to extract:
//   - Tag 1: Boot Command Line
//   - Tag 2: Bootloader Name
//   - Tag 6: Physical Memory Map (e820 usable RAM regions)
//   - Tag 8: Linear Framebuffer (physical addr, pitch, width, height, bpp)
//   - Tag 14/15: ACPI Old (v1) / New (v2+) RSDP pointer
// ==============================================================================

fn silicon_mb2_magic_valid magic
    // Multiboot2 bootloader magic = 0x36D76289 (919036553)
    if (magic & 4294967295) == 919036553 return 1 end
    return 0

fn silicon_mb2_total_size mb_info_ptr
    if mb_info_ptr == 0 return 0 end
    return mmio_r32(mb_info_ptr + 0)

fn silicon_mb2_find_tag mb_info_ptr target_type
    // WHY: Multiboot2 tags start at offset +8 and each tag is padded up to an 8-byte boundary.
    // Tag header: +0 type(u32), +4 size(u32). Terminated by type==0, size==8.
    if mb_info_ptr == 0 return 0 end
    total = mmio_r32(mb_info_ptr + 0)
    if total < 16 return 0 end
    off = 8
    while off + 8 <= total
        ttype = mmio_r32(mb_info_ptr + off)
        tsize = mmio_r32(mb_info_ptr + off + 4)
        if ttype == 0 and tsize == 8
            return 0
        end
        if ttype == target_type
            return mb_info_ptr + off
        end
        if tsize < 8 return 0 end
        // Align step up to 8-byte boundary
        step = (tsize + 7) & (0 - 8)
        off = off + step
    end
    return 0

// ── Tag 8: Framebuffer Accessors ─────────────────────────────────────────────
// Layout: +8 addr(u64), +16 pitch(u32), +20 width(u32), +24 height(u32), +28 bpp(u8), +29 fb_type(u8)

fn silicon_mb2_fb_addr fb_tag
    if fb_tag == 0 return 0 end
    return mmio_r64(fb_tag + 8)

fn silicon_mb2_fb_pitch fb_tag
    if fb_tag == 0 return 0 end
    return mmio_r32(fb_tag + 16)

fn silicon_mb2_fb_width fb_tag
    if fb_tag == 0 return 0 end
    return mmio_r32(fb_tag + 20)

fn silicon_mb2_fb_height fb_tag
    if fb_tag == 0 return 0 end
    return mmio_r32(fb_tag + 24)

fn silicon_mb2_fb_bpp fb_tag
    if fb_tag == 0 return 0 end
    return mmio_r8(fb_tag + 28)

// ── Tag 6: Memory Map Iterator ───────────────────────────────────────────────
// Layout: +4 size(u32), +8 entry_size(u32), +12 entry_version(u32), +16 entries[]
// Entry: +0 base_addr(u64), +8 length(u64), +16 type(u32: 1=AVAILABLE RAM)

fn silicon_mb2_mmap_entry_count mmap_tag
    if mmap_tag == 0 return 0 end
    tsize = mmio_r32(mmap_tag + 4)
    esz = mmio_r32(mmap_tag + 8)
    if esz < 24 or tsize <= 16 return 0 end
    return (tsize - 16) / esz

fn silicon_mb2_mmap_entry_ptr mmap_tag idx
    if mmap_tag == 0 return 0 end
    esz = mmio_r32(mmap_tag + 8)
    return mmap_tag + 16 + (idx * esz)

fn silicon_mb2_mmap_total_usable_ram mmap_tag
    cnt = silicon_mb2_mmap_entry_count(mmap_tag)
    total = 0
    i = 0
    while i < cnt
        ep = silicon_mb2_mmap_entry_ptr(mmap_tag, i)
        if mmio_r32(ep + 16) == 1
            total = total + mmio_r64(ep + 8)
        end
        i = i + 1
    end
    return total

// ── Tag 14/15: ACPI RSDP & Tag 1: Cmdline ────────────────────────────────────

fn silicon_mb2_find_rsdp mb_info_ptr
    // Prefers ACPI v2+ Tag 15, falls back to ACPI v1 Tag 14; RSDP begins at tag + 8!
    t15 = silicon_mb2_find_tag(mb_info_ptr, 15)
    if t15 != 0 return t15 + 8 end
    t14 = silicon_mb2_find_tag(mb_info_ptr, 14)
    if t14 != 0 return t14 + 8 end
    return 0

fn silicon_mb2_cmdline_ptr mb_info_ptr
    t1 = silicon_mb2_find_tag(mb_info_ptr, 1)
    if t1 == 0 return 0 end
    return t1 + 8
