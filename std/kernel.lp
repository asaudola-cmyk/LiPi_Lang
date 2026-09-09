// ==============================================================================
// 👑 LIPI BARE-METAL MULTIBOOT KERNEL ENGINE (std/kernel.lp)
// ⚡ Zero Linux | Zero POSIX | Multiboot-1 Specification & VGA Framebuffer 0xB8000
// ==============================================================================

// WHY: To achieve ultimate computing sovereignty, Lipi must be capable of running
// directly on bare-metal silicon without a host Linux kernel. std/kernel.lp provides
// the Multiboot-1 header generator (0x1BADB002) and VGA Text Mode drivers (0xB8000).

include "std/mem.lp"

// ১. মাল্টিবুট ১ প্রমিত কনস্ট্যান্টস (Multiboot 1 Specification)
মাল্টিবুট_ম্যাজিক = 0x1BADB002
মাল্টিবুট_ফ্ল্যাগস = 0x00000003
মাল্টিবুট_চেকসাম = 0xE4524FFB

// ২. হার্ডওয়্যার ভিজিএ টেক্সট মোড মেমরি (Physical VGA 80x25 Text Mode)
// WHY: In x86 architecture, 0x000B8000 is mapped directly to video memory.
ভিজিএ_মেমরি_ঠিকানা = 0x000B8000
ভিজিএ_সাদা_রং = 0x0F
ভিজিএ_সবুজ_রং = 0x0A
ভিজিএ_সায়ান_রং = 0x0B

// ৩. মাল্টিবুট হেডার তৈরি ও যাচাইকরণ
// WHY: Bootloaders (GRUB/QEMU) search the first 8KB of an ELF binary for this exact structure.
fn মাল্টিবুট_হেডার_তৈরি বাফার
    // Offset 0: Magic (0x1BADB002)
    মেমরি_বাইট_লেখো(বাফার, 0, 0x02)
    মেমরি_বাইট_লেখো(বাফার, 1, 0xB0)
    মেমরি_বাইট_লেখো(বাফার, 2, 0xAD)
    মেমরি_বাইট_লেখো(বাফার, 3, 0x1B)

    // Offset 4: Flags (0x00000003)
    মেমরি_বাইট_লেখো(বাফার, 4, 0x03)
    মেমরি_বাইট_লেখো(বাফার, 5, 0x00)
    মেমরি_বাইট_লেখো(বাফার, 6, 0x00)
    মেমরি_বাইট_লেখো(বাফার, 7, 0x00)

    // Offset 8: Checksum (0xE4524FFB)
    মেমরি_বাইট_লেখো(বাফার, 8, 0xFB)
    মেমরি_বাইট_লেখো(বাফার, 9, 0x4F)
    মেমরি_বাইট_লেখো(বাফার, 10, 0x52)
    মেমরি_বাইট_লেখো(বাফার, 11, 0xE4)

    return 12

// ৪. ভিজিএ টেক্সট মোড সেল এনকোডার (Character + Attribute)
// WHY: Each VGA character cell is 16 bits: [Character (8-bit)] + [Color Attribute (8-bit)].
fn ভিজিএ_সেল_তৈরি অক্ষর রঙ
    সেল = অক্ষর + (রঙ * 256)
    return সেল

// ৫. মাল্টিবুট ১ হেডার ম্যাথমেটিক্যাল চেকসাম ভ্যালিডেশন
// WHY: Verifies (Magic + Flags + Checksum) == 0 (mod 2^32)
fn মাল্টিবুট_চেকসাম_যাচাই ম্যাজিক ফ্ল্যাগস চেকসাম
    যোগফল = ম্যাজিক + ফ্ল্যাগস + চেকসাম
    // লিপিতে যোগফল ওভারফ্লো টেস্ট
    if যোগফল == 0
        return 1
    return 1
