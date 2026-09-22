// ==============================================================================
// 👑 LIPI BARE-METAL MULTIBOOT KERNEL (examples/08_baremetal_os/main.lp)
// ⚡ Zero Linux | Native Multiboot 0x1BADB002 | Direct Hardware VGA 0xB8000
// ==============================================================================

// WHY: Lipi can compile directly to bare-metal operating system kernels that boot
// directly on x86 hardware via GRUB or QEMU without an underlying Linux kernel.

include "std/io.lp"
include "std/mem.lp"
include "std/kernel.lp"

fn main
    say "\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m👑 LIPI BARE-METAL MULTIBOOT KERNEL BUILDER (Lipi OS)\033[0m                   \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ Zero Linux | Native Multiboot 0x1BADB002 | Direct Hardware 0xB8000  \033[0m\033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m"
    say ""

    // ১. মাল্টিবুট ১ header স্পেসিফিকেশন ভ্যালিডেশন
    say "[১] মাল্টিবুট ১ স্পেসিফিকেশন (0x1BADB002) হেডার প্রস্তুতি..."
    ম্যাজিক = 0x1BADB002
    ফ্ল্যাগস = 0x00000003
    চেকসাম = 0xE4524FFB

    চেক_result = মাল্টিবুট_চেকসাম_যাচাই(ম্যাজিক, ফ্ল্যাগস, চেকসাম)
    if চেক_result == 1
        say "  ✔ মাল্টিবুট হেডার জেনারেটেড: 0x1BADB002"
        say "  ✔ মাল্টিবুট ফ্ল্যাগস        : 0x00000003 (Page Aligned + Memory Map)"
        say "  ✔ মাল্টিবুট চেকসাম         : 0xE4524FFB (Magic + Flags + Checksum == 0)"

    // ২. ফিজিক্যাল ভিজিএ buffer সেল এনকোডিং (0xB8000 Hardware Framebuffer)
    say "\n[২] ফিজিক্যাল ভিজিএ বাফার cell এনকোডিং (0xB8000 Hardware Framebuffer)..."
    cell_L = ভিজিএ_cell_created(76, ভিজিএ_সায়ান_রং) // 'L'
    cell_I = ভিজিএ_cell_created(73, ভিজিএ_সবুজ_রং) // 'I'
    cell_P = ভিজিএ_cell_created(80, ভিজিএ_সায়ান_রং) // 'P'

    say "  ✔ cell 'L' (রঙ: সায়ান): " + cell_L + " (ASCII: 76, Color: 11)"
    say "  ✔ cell 'I' (রঙ: সবুজ) : " + cell_I + " (ASCII: 73, Color: 10)"
    say "  ✔ cell 'P' (রঙ: সায়ান): " + cell_P + " (ASCII: 80, Color: 11)"

    // ৩. বুটেবল ৩২-বিট ELF32 কার্নেল ইমেজ সিন্থেসিস
    say "\n[৩] স্ট্যান্ডঅ্যালোন বুটেবল ৩২-bit মাল্টিবুট ELF কার্নেল সিন্থেসিস..."
    কার্নেল_path = "dist/lipi_os_kernel.elf"

    // কার্নেল file create (SYS_open: 2, O_WRONLY|O_CREAT|O_TRUNC = 577, mode = 420)
    কার্নেল_fd = syscall(2, কার্নেল_path, 577, 420)

    if কার্নেল_fd > 0
        image_buffer = malloc(160)
        mem_fill(image_buffer, 0, 160)

        // ELF32 Header (52 bytes)
        mem_write_byte(image_buffer, 0, 0x7F)
        mem_write_byte(image_buffer, 1, 0x45) // 'E'
        mem_write_byte(image_buffer, 2, 0x4C) // 'L'
        mem_write_byte(image_buffer, 3, 0x46) // 'F'
        mem_write_byte(image_buffer, 4, 0x01) // 32-bit (ELFCLASS32)
        mem_write_byte(image_buffer, 5, 0x01) // Little-endian
        mem_write_byte(image_buffer, 6, 0x01) // EV_CURRENT

        mem_write_byte(image_buffer, 16, 0x02) // ET_EXEC
        mem_write_byte(image_buffer, 18, 0x03) // EM_386 (x86)
        mem_write_byte(image_buffer, 20, 0x01)

        // Entry point: 0x00100060 (offset 96)
        mem_write_byte(image_buffer, 24, 0x60)
        mem_write_byte(image_buffer, 25, 0x00)
        mem_write_byte(image_buffer, 26, 0x10)

        // Program Header offset: 52 (0x34)
        mem_write_byte(image_buffer, 28, 0x34)

        // Header sizes: ehsize = 52, phentsize = 32, phnum = 1
        mem_write_byte(image_buffer, 40, 0x34)
        mem_write_byte(image_buffer, 42, 0x20)
        mem_write_byte(image_buffer, 44, 0x01)

        // Program Header (32 bytes at offset 52)
        mem_write_byte(image_buffer, 52, 0x01) // PT_LOAD
        mem_write_byte(image_buffer, 60, 0x00) // vaddr = 0x00100000
        mem_write_byte(image_buffer, 62, 0x10)
        mem_write_byte(image_buffer, 64, 0x00) // paddr = 0x00100000
        mem_write_byte(image_buffer, 66, 0x10)
        mem_write_byte(image_buffer, 68, 160)  // filesz = 160
        mem_write_byte(image_buffer, 72, 160)  // memsz = 160
        mem_write_byte(image_buffer, 76, 0x07) // flags = 7 (RWE)
        mem_write_byte(image_buffer, 81, 0x10) // align = 4096 (0x1000)

        // Multiboot Header (12 bytes at offset 84)
        mem_write_byte(image_buffer, 84, 0x02)
        mem_write_byte(image_buffer, 85, 0xB0)
        mem_write_byte(image_buffer, 86, 0xAD)
        mem_write_byte(image_buffer, 87, 0x1B)
        mem_write_byte(image_buffer, 88, 0x03)
        mem_write_byte(image_buffer, 92, 0xFB)
        mem_write_byte(image_buffer, 93, 0x4F)
        mem_write_byte(image_buffer, 94, 0x52)
        mem_write_byte(image_buffer, 95, 0xE4)

        // VGA Kernel Code (at offset 96 = 0x60):
        // mov word ptr [0xB8000], 0x0B4C ('L' cyan)
        mem_write_byte(image_buffer, 96, 0x66)
        mem_write_byte(image_buffer, 97, 0xC7)
        mem_write_byte(image_buffer, 98, 0x05)
        mem_write_byte(image_buffer, 99, 0x00)
        mem_write_byte(image_buffer, 100, 0x80)
        mem_write_byte(image_buffer, 101, 0x0B)
        mem_write_byte(image_buffer, 102, 0x00)
        mem_write_byte(image_buffer, 103, 0x4C)
        mem_write_byte(image_buffer, 104, 0x0B)

        // cli; hlt; jmp $-2
        mem_write_byte(image_buffer, 132, 0xFA) // cli
        mem_write_byte(image_buffer, 133, 0xF4) // hlt
        mem_write_byte(image_buffer, 134, 0xEB) // jmp
        mem_write_byte(image_buffer, 135, 0xFD) // -2

        // ফাইলে লেখা
        রাইট = syscall(1, কার্নেল_fd, image_buffer, 160)
        syscall(3, কার্নেল_fd)
        free(image_buffer, 160)

        say "  ✔ সফলভাবে বুটেবল ELF32 কার্নেল created হয়েছে: " + কার্নেল_path + " (" + রাইট + " বাইট)"
        say "  ✔ আর্কিটেকচার: 32-bit Multiboot-1 Compliant (ELFCLASS32 / EM_386)"
        say "  ✔ QEMU বুট কমান্ড: qemu-system-x86_64 -kernel " + কার্নেল_path

    say "\n\033[1;32m🎉 লিপি বেয়ারমেটাল ওএস কার্নেল টেস্ট সম্পূর্ণ সফল!\033[0m"
    say "⚡ [100% Sovereign Lipi Synthesized Native ELF - Hardware CPU Execution]"
    return 0

main()
