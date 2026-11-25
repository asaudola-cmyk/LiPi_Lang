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
