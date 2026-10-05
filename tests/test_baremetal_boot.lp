// ==============================================================================
// 🧪 LIPI TEST SUITE: BARE-METAL BOOTLOADER & SOVEREIGN DESKTOP KERNEL
// File: tests/test_baremetal_boot.lp
// Standard: UEFI 2.10 PE32+ Specification & x86_64 Baremetal Long Mode
// 100% Pure LiPi Implementation — Zero External / C Dependencies
// ==============================================================================
//
// WHY: Validates the complete bare-metal execution chain for Milestone 1:
// 1. UEFI PE32+ application generation with exact DOS/COFF/Optional headers.
// 2. UEFI GOP protocol locator and linear framebuffer MMIO aperture geometry.
// 3. Physical Memory Map querying and ExitBootServices transition sequence.
// 4. x86_64 Long Mode 64-bit GDT table serialization (CS 0x08, DS 0x10, TSS 0x28).
// 5. 256-entry 64-bit Interrupt Descriptor Table (IDT) with exception trap gates.
// 6. Direct hardware Linear Framebuffer MMIO rasterization and double-buffering.
// 7. Direct bootstrap into LiPi's sovereign desktop graphics environment.
// 8. Raw machine code bootstrap payload emission for firmware/hypervisor boot.
// ==============================================================================

include "universe/boot/uefi_boot.lp"
include "universe/boot/baremetal_kernel.lp"

fn main
    say "================================================================="
    say "🛸 LIPI SOVEREIGN BARE-METAL KERNEL & UEFI BOOTLOADER SUITE 🛸"
    say "================================================================="

    // ── Part 1: UEFI PE32+ Bootloader Engine Verification ─────────────────────
    say "\n▶ [PART 1]: Executing Bare-Metal UEFI Bootloader Verification..."
    u_ok = uefi_boot_verify()
    if u_ok != 1
        say "❌ [FAIL]: UEFI bootloader verification failed!"
        exit(1)

    // ── Part 2: x86_64 Long Mode Kernel & Desktop GUI Verification ────────────
    say "\n▶ [PART 2]: Executing Bare-Metal Long-Mode Kernel & Desktop Verification..."
    k_ok = baremetal_kernel_verify()
    if k_ok != 1
        say "❌ [FAIL]: Bare-metal kernel verification failed!"
        exit(1)

    // ── Part 3: Image & Payload Binary Export Verification ─────────────────────
    say "\n▶ [PART 3]: Executing Bootloader & Kernel Binary Exporters..."
    efi_path = "/tmp/test_bootx64.efi"
    esp_path = "/tmp/test_lipi_esp.img"
    kern_path = "/tmp/test_kernel.bin"

    // 1. Export UEFI PE32+ application
    e1 = uefi_export_efi_image(efi_path)
    if e1 != 1
        say "❌ [FAIL]: Failed to export UEFI EFI application"
        exit(1)

    fd1 = syscall(2, efi_path, 0, 0, 0, 0, 0)
    if fd1 < 0
        say "❌ [FAIL]: Exported EFI file does not exist"
        exit(1)
    buf1 = malloc(512)
    n1 = syscall(0, fd1, buf1, 512, 0, 0, 0)
    syscall(3, fd1, 0, 0, 0, 0, 0)
    if n1 < 512
        say "❌ [FAIL]: Exported EFI file too small"
        exit(1)
    m0 = mem_read_byte(buf1, 0)
    m1 = mem_read_byte(buf1, 1)
    if m0 != 77 or m1 != 90
        say "❌ [FAIL]: Exported EFI file missing MZ magic signature"
        exit(1)
    free(buf1, 512)
    syscall(87, efi_path, 0, 0, 0, 0, 0)

    // 2. Export FAT ESP disk image
    e2 = uefi_export_esp_disk(esp_path)
    if e2 != 1
        say "❌ [FAIL]: Failed to export ESP disk image"
        exit(1)
    fd2 = syscall(2, esp_path, 0, 0, 0, 0, 0)
    if fd2 < 0
        say "❌ [FAIL]: Exported ESP disk file does not exist"
        exit(1)
    buf2 = malloc(512)
    n2 = syscall(0, fd2, buf2, 512, 0, 0, 0)
    syscall(3, fd2, 0, 0, 0, 0, 0)
    if n2 < 512
        say "❌ [FAIL]: Exported ESP disk file too small"
        exit(1)
    s0 = mem_read_byte(buf2, 510)
    s1 = mem_read_byte(buf2, 511)
    if s0 != 85 or s1 != 170
        say "❌ [FAIL]: Exported ESP disk missing 0x55AA boot sector signature"
        exit(1)
    free(buf2, 512)
    syscall(87, esp_path, 0, 0, 0, 0, 0)

    // 3. Export baremetal kernel binary
    e3 = baremetal_export_kernel_image(kern_path)
    if e3 != 1
        say "❌ [FAIL]: Failed to export baremetal kernel image"
        exit(1)
    fd3 = syscall(2, kern_path, 0, 0, 0, 0, 0)
    if fd3 < 0
        say "❌ [FAIL]: Exported kernel binary does not exist"
        exit(1)
    buf3 = malloc(64)
    n3 = syscall(0, fd3, buf3, 64, 0, 0, 0)
    syscall(3, fd3, 0, 0, 0, 0, 0)
    if n3 < 15
        say "❌ [FAIL]: Exported kernel binary too small"
        exit(1)
    b0 = mem_read_byte(buf3, 0)
    b1 = mem_read_byte(buf3, 1)
    if b0 != 250 or b1 != 252
        say "❌ [FAIL]: Exported kernel binary missing cli/cld bootstrap instructions"
        exit(1)
    free(buf3, 64)
    syscall(87, kern_path, 0, 0, 0, 0, 0)

    say "✔ [PASS]: All bootloader & kernel binary image exports verified on disk!"

    say "\n================================================================="
    say "🎉 ALL SOVEREIGN BARE-METAL BOOTLOADER & KERNEL TESTS PASSED (100%)!"
    say "================================================================="
    return 0

main()
