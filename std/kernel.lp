// ==============================================================================
// 👑 LIPI BARE-METAL MULTIBOOT KERNEL ENGINE (std/kernel.lp)
// ⚡ Zero Linux | Zero POSIX | Multiboot-1 Specification & VGA Framebuffer 0xB8000
// ==============================================================================

// WHY: To achieve ultimate computing sovereignty, Lipi must be capable of running
// directly on bare-metal silicon without a host Linux kernel. std/kernel.lp provides
// the Multiboot-1 header generator (0x1BADB002) and VGA Text Mode drivers (0xB8000).

include "std/mem.lp"

// ১. মাল্টিবুট ১ প্রমিত কনস্ট্যান্টস (Multiboot 1 Specification)
// WHY: Bootloaders compliant with Multiboot 1 require exact magic numbers and flags.
মাল্টিবুট_ম্যাজিক = 464367618  // 0x1BADB002 (Multiboot 1 Magic)
মাল্টিবুট_ফ্ল্যাগস = 3          // 0x00000003 (Align 4KB pages + Memory Map info)
মাল্টিবুট_চেকসাম = 3830599675  // 0xE4524FFB (-(Magic + Flags) mod 2^32)

// Backwards compatibility aliases
MULTIBOOT_MAGIC = মাল্টিবুট_ম্যাজিক
MULTIBOOT_FLAGS = মাল্টিবুট_ফ্ল্যাগস
MULTIBOOT_CHECKSUM = মাল্টিবুট_চেকসাম

// ২. হার্ডওয়্যার ভিজিএ টেক্সট মোড মেমরি (Physical VGA 80x25 Text Mode Memory)
// WHY: In x86 architecture, physical address 0x000B8000 is mapped directly to video display RAM.
ভিজিএ_মেমরি_ঠিকানা = 753664 // 0x000B8000
ভিজিএ_mem_addr = ভিজিএ_মেমরি_ঠিকানা
VGA_FRAMEBUFFER_ADDR = ভিজিএ_মেমরি_ঠিকানা

ভিজিএ_সাদা_রং = 15 // 0x0F (White on Black)
ভিজিএ_সবুজ_রং = 10 // 0x0A (Light Green)
ভিজিএ_সায়ান_রং = 11 // 0x0B (Light Cyan)
VGA_COLOR_WHITE = 15
VGA_COLOR_GREEN = 10
VGA_COLOR_CYAN = 11

// ৩. মাল্টিবুট হেডার তৈরি ও যাচাইকরণ
// WHY: Bootloaders (GRUB/QEMU) search the first 8KB of an ELF binary for this exact 12-byte header.
// Offset 0..3 : Magic (0x1BADB002)
// Offset 4..7 : Flags (0x00000003)
// Offset 8..11: Checksum (0xE4524FFB)
fn মাল্টিবুট_হেডার_তৈরি buffer
    // Offset 0: Magic (0x1BADB002: Little Endian 02 B0 AD 1B)
    mem_write_byte(buffer, 0, 2)   // 0x02
    mem_write_byte(buffer, 1, 176) // 0xB0
    mem_write_byte(buffer, 2, 173) // 0xAD
    mem_write_byte(buffer, 3, 27)  // 0x1B

    // Offset 4: Flags (0x00000003: Little Endian 03 00 00 00)
    mem_write_byte(buffer, 4, 3)   // 0x03
    mem_write_byte(buffer, 5, 0)   // 0x00
    mem_write_byte(buffer, 6, 0)   // 0x00
    mem_write_byte(buffer, 7, 0)   // 0x00

    // Offset 8: Checksum (0xE4524FFB: Little Endian FB 4F 52 E4)
    mem_write_byte(buffer, 8, 251) // 0xFB
    mem_write_byte(buffer, 9, 79)  // 0x4F
    mem_write_byte(buffer, 10, 82) // 0x52
    mem_write_byte(buffer, 11, 228)// 0xE4

    return 12

fn multiboot_header_create buffer
    return মাল্টিবুট_হেডার_তৈরি(buffer)

fn মাল্টিবুট_header_created buffer
    return মাল্টিবুট_হেডার_তৈরি(buffer)

// ৪. ভিজিএ টেক্সট মোড সেল এনকোডার (Character + Attribute)
// WHY: Each VGA character cell is 16 bits: [Character (8-bit ASCII)] + [Color Attribute (8-bit)].
// Example: Character 76 ('L') with cyan color (11) produces 76 + (11 * 256) = 2892 (0x0B4C).
fn ভিজিএ_সেল_তৈরি অক্ষর color
    cell = অক্ষর + (color * 256)
    return cell

fn vga_cell_create char color
    return ভিজিএ_সেল_তৈরি(char, color)

fn ভিজিএ_cell_created অক্ষর color
    return ভিজিএ_সেল_তৈরি(অক্ষর, color)

// ৫. মাল্টিবুট ১ হেডার ম্যাথমেটিক্যাল চেকসাম যাচাইকরণ
// WHY: Verifies (Magic + Flags + Checksum) == 0 (mod 2^32).
// Standard GRUB/QEMU requirement for valid kernel image detection.
fn মাল্টিবুট_চেকসাম_যাচাই ম্যাজিক ফ্ল্যাগস চেকসাম
    sum = ম্যাজিক + ফ্ল্যাগস + চেকসাম
    if sum == 0
        return 1
    if (sum % 4294967296) == 0
        return 1
    return 0

fn multiboot_checksum_verify magic flags checksum
    return মাল্টিবুট_চেকসাম_যাচাই(magic, flags, checksum)

fn মাল্টিবুট_চেকসাম_verify ম্যাজিক ফ্ল্যাগস চেকসাম
    return মাল্টিবুট_চেকসাম_যাচাই(ম্যাজিক, ফ্ল্যাগস, চেকসাম)

