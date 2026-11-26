// ==============================================================================
// 👑 LIPI UTSO — SOVEREIGN UEFI FIRMWARE INTERFACE (utso/silicon/uefi.lp)
// ⚡ 100% Pure Lipi | Direct MS x64 ABI EFI_SYSTEM_TABLE Calls | 0% EDK2 / gnu-efi
// ==============================================================================
//
// WHY THIS MODULE:
// Interacts directly with UEFI x86-64 firmware (OVMF / physical BIOS-UEFI) using
// Lipi's built-in `uefi_call(fn_ptr, a1, a2, a3, a4, a5)` MS x64 ABI bridge.
//
// Standard UEFI x86-64 Struct Offsets (UEFI Spec 2.10):
//   EFI_SYSTEM_TABLE:
//     +0x40 (64) = ConOut (EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL*)
//     +0x60 (96) = BootServices (EFI_BOOT_SERVICES*)
//   EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL:
//     +0x00 (0)  = Reset(This, ExtendedVerification)
//     +0x08 (8)  = OutputString(This, CHAR16* String)
//     +0x30 (48) = ClearScreen(This)
//   EFI_BOOT_SERVICES:
//     +0x28 (40) = AllocatePages(Type, MemoryType, Pages, Memory*)
//     +0x38 (56) = GetMemoryMap(MapSize*, Map*, MapKey*, DescSize*, DescVer*)
//     +0xE8 (232)= ExitBootServices(ImageHandle, MapKey)
//     +0xF8 (248)= Stall(Microseconds)
// ==============================================================================

fn silicon_uefi_con_out system_table
    return mmio_r64(system_table + 64)

fn silicon_uefi_boot_services system_table
    return mmio_r64(system_table + 96)

fn silicon_uefi_clear_screen system_table
    con_out = mmio_r64(system_table + 64)
    clear_fn = mmio_r64(con_out + 48)
    return uefi_call(clear_fn, con_out, 0, 0, 0, 0)

fn silicon_uefi_print_ucs2 system_table ucs2_buf
    con_out = mmio_r64(system_table + 64)
    out_fn = mmio_r64(con_out + 8)
    return uefi_call(out_fn, con_out, ucs2_buf, 0, 0, 0)

fn silicon_uefi_print_ascii system_table ascii_ptr scratch_ucs2_buf max_chars
    // Converts ASCII C-string into caller-provided UTF-16LE buffer and calls ConOut->OutputString!
    i = 0
    while i + 1 < max_chars
        b = mem_byte_read(ascii_ptr, i)
        if b == 0 break end
        mmio_w16(scratch_ucs2_buf + (i * 2), b)
        i = i + 1
    end
    mmio_w16(scratch_ucs2_buf + (i * 2), 0)
    return silicon_uefi_print_ucs2(system_table, scratch_ucs2_buf)

fn silicon_uefi_stall system_table usec
    bs = mmio_r64(system_table + 96)
    stall_fn = mmio_r64(bs + 248)
    return uefi_call(stall_fn, usec, 0, 0, 0, 0)

fn silicon_uefi_exit_boot_services system_table image_handle map_key
    bs = mmio_r64(system_table + 96)
    exit_fn = mmio_r64(bs + 232)
    return uefi_call(exit_fn, image_handle, map_key, 0, 0, 0)

// ── UEFI 2.10 BootServices: MemoryMap, AllocatePages, LocateProtocol ─────────
// Standard EFI_BOOT_SERVICES table offsets (UEFI 2.10 x86-64):
//   +0x28 (40)  = AllocatePages(Type, MemoryType, Pages, Memory*)
//   +0x38 (56)  = GetMemoryMap(MapSize*, Map*, MapKey*, DescSize*, DescVer*)
//   +0x140 (320)= LocateProtocol(ProtocolGuid*, Registration, Interface**)

fn silicon_uefi_allocate_pages system_table alloc_type mem_type pages addr_out_ptr
    bs = mmio_r64(system_table + 96)
    fn_p = mmio_r64(bs + 40)
    return uefi_call(fn_p, alloc_type, mem_type, pages, addr_out_ptr, 0)

fn silicon_uefi_get_memory_map system_table map_sz_ptr map_buf map_key_ptr desc_sz_ptr desc_ver_ptr
    bs = mmio_r64(system_table + 96)
    fn_p = mmio_r64(bs + 56)
    return uefi_call(fn_p, map_sz_ptr, map_buf, map_key_ptr, desc_sz_ptr, desc_ver_ptr)

fn silicon_uefi_locate_protocol system_table guid_ptr interface_out_ptr
    bs = mmio_r64(system_table + 96)
    fn_p = mmio_r64(bs + 320)
    return uefi_call(fn_p, guid_ptr, 0, interface_out_ptr, 0, 0)

// ── UEFI Graphics Output Protocol (GOP) Wrapper ──────────────────────────────
// EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID = {9042A9DE-23DC-4A38-96FB-7ADED080516A}
// EFI_GRAPHICS_OUTPUT_PROTOCOL: +24 = Mode* (EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE*)
// Mode: +0 MaxMode(u32), +4 Mode(u32), +8 Info*, +16 SizeOfInfo(u64), +24 FrameBufferBase(u64), +32 FrameBufferSize(u64)
// Info: +0 Ver(u32), +4 HorizontalResolution(u32), +8 VerticalResolution(u32), +12 PixelFormat(u32), +32 PixelsPerScanLine(u32)

fn silicon_uefi_write_gop_guid guid_buf
    // Writes 16-byte little-endian EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID into caller buffer
    mmio_w32(guid_buf + 0, 2420287966) // 0x9042A9DE
    mmio_w16(guid_buf + 4, 9180)       // 0x23DC
    mmio_w16(guid_buf + 6, 19000)      // 0x4A38
    mmio_w8(guid_buf + 8, 150)         // 0x96
    mmio_w8(guid_buf + 9, 251)         // 0xFB
    mmio_w8(guid_buf + 10, 122)        // 0x7A
    mmio_w8(guid_buf + 11, 222)        // 0xDE
    mmio_w8(guid_buf + 12, 208)        // 0xD0
    mmio_w8(guid_buf + 13, 128)        // 0x80
    mmio_w8(guid_buf + 14, 81)         // 0x51
    mmio_w8(guid_buf + 15, 106)        // 0x6A
    return guid_buf

fn silicon_uefi_gop_fb_base gop_ptr
    mode_ptr = mmio_r64(gop_ptr + 24)
    if mode_ptr == 0 return 0 end
    return mmio_r64(mode_ptr + 24)

fn silicon_uefi_gop_fb_size gop_ptr
    mode_ptr = mmio_r64(gop_ptr + 24)
    if mode_ptr == 0 return 0 end
    return mmio_r64(mode_ptr + 32)

fn silicon_uefi_gop_width gop_ptr
    mode_ptr = mmio_r64(gop_ptr + 24)
    if mode_ptr == 0 return 0 end
    info_ptr = mmio_r64(mode_ptr + 8)
    if info_ptr == 0 return 0 end
    return mmio_r32(info_ptr + 4)

fn silicon_uefi_gop_height gop_ptr
    mode_ptr = mmio_r64(gop_ptr + 24)
    if mode_ptr == 0 return 0 end
    info_ptr = mmio_r64(mode_ptr + 8)
    if info_ptr == 0 return 0 end
    return mmio_r32(info_ptr + 8)

fn silicon_uefi_gop_stride gop_ptr
    mode_ptr = mmio_r64(gop_ptr + 24)
    if mode_ptr == 0 return 0 end
    info_ptr = mmio_r64(mode_ptr + 8)
    if info_ptr == 0 return 0 end
    return mmio_r32(info_ptr + 32)

// ── UEFI Simple File System Protocol Wrapper ─────────────────────────────────
// EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID = {964E5B22-6459-11D2-8E39-00A0C969723B}
// EFI_SIMPLE_FILE_SYSTEM_PROTOCOL: +8 = OpenVolume(This, Root**)
// EFI_FILE_PROTOCOL: +8 = Open(This, NewHandle**, FileName16*, OpenMode, Attributes)
//                    +16 = Close(This)
//                    +32 = Read(This, BufferSize*, Buffer*)

fn silicon_uefi_write_sfs_guid guid_buf
    mmio_w32(guid_buf + 0, 2521717538) // 0x964E5B22
    mmio_w16(guid_buf + 4, 25689)      // 0x6459
    mmio_w16(guid_buf + 6, 4562)       // 0x11D2
    mmio_w8(guid_buf + 8, 142)         // 0x8E
    mmio_w8(guid_buf + 9, 57)          // 0x39
    mmio_w8(guid_buf + 10, 0)          // 0x00
    mmio_w8(guid_buf + 11, 160)        // 0xA0
    mmio_w8(guid_buf + 12, 201)        // 0xC9
    mmio_w8(guid_buf + 13, 105)        // 0x69
    mmio_w8(guid_buf + 14, 114)        // 0x72
    mmio_w8(guid_buf + 15, 59)         // 0x3B
    return guid_buf

fn silicon_uefi_sfs_open_volume sfs_ptr root_out_ptr
    open_vol_fn = mmio_r64(sfs_ptr + 8)
    return uefi_call(open_vol_fn, sfs_ptr, root_out_ptr, 0, 0, 0)

fn silicon_uefi_file_open dir_proto file_out_ptr name_ucs2 open_mode attrs
    open_fn = mmio_r64(dir_proto + 8)
    return uefi_call(open_fn, dir_proto, file_out_ptr, name_ucs2, open_mode, attrs)

fn silicon_uefi_file_read file_proto buf_size_ptr dst_buf
    read_fn = mmio_r64(file_proto + 32)
    return uefi_call(read_fn, file_proto, buf_size_ptr, dst_buf, 0, 0)

fn silicon_uefi_file_close file_proto
    close_fn = mmio_r64(file_proto + 16)
    return uefi_call(close_fn, file_proto, 0, 0, 0, 0)
