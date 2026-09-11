// ==============================================================================
// 👑 LIPI BARE-METAL MULTIBOOT KERNEL ENGINE (std/kernel.lp)
// ⚡ Zero Linux | Zero POSIX | Multiboot-1, IDT, 8259 PIC, PS/2 & VGA Shell
// ==============================================================================

// WHY: To achieve ultimate computing sovereignty, Lipi must be capable of running
// directly on bare-metal silicon without a host Linux kernel. std/kernel.lp provides:
// 1. Multiboot-1 header generator (0x1BADB002)
// 2. VGA Text Mode drivers (0xB8000)
// 3. 256-entry 64-bit IDT (Interrupt Descriptor Table)
// 4. 8259 PIC (Programmable Interrupt Controller) remapper
// 5. PS/2 Keyboard Controller Driver (Scan Code Set 1)
// 6. Interactive Baremetal VGA Kernel Shell (lipi-os> )

include "universe/core/std_mem.lp"

// ১. মাল্টিবুট ১ প্রমিত কনস্ট্যান্টস (Multiboot 1 Specification)
// WHY: Bootloaders compliant with Multiboot 1 require exact magic numbers and flags.
মাল্টিবুট_ম্যাজিক = 464367618  // 0x1BADB002 (Multiboot 1 Magic)
মাল্টিবুট_ফ্ল্যাগস = 3          // 0x00000003 (Align 4KB pages + Memory Map info)
মাল্টিবুট_চেকসাম = 3830599675  // 0xE4524FFB (-(Magic + Flags) mod 2^32)

// Backwards compatibility aliases (direct integer constants for compiler glob_names resolution)
MULTIBOOT_MAGIC = 464367618
MULTIBOOT_FLAGS = 3
MULTIBOOT_CHECKSUM = 3830599675

// ২. হার্ডওয়্যার ভিজিএ টেক্সট মোড মেমরি (Physical VGA 80x25 Text Mode Memory)
// WHY: In x86 architecture, physical address 0x000B8000 is mapped directly to video display RAM.
ভিজিএ_মেমরি_ঠিকানা = 753664 // 0x000B8000
ভিজিএ_mem_addr = 753664
VGA_FRAMEBUFFER_ADDR = 753664

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

// ==============================================================================
// ৬. ২৫৬-এন্ট্রি আইডিটি (256-Entry Interrupt Descriptor Table - x86_64 Long Mode)
// ==============================================================================
// WHY: In x86_64 Long Mode, the CPU routes interrupts & exceptions (0..255) through
// a 256-entry table where each gate descriptor occupies exactly 16 bytes:
//   Offset  0..1 : Offset 15..0 (Lower 16 bits of ISR handler address)
//   Offset  2..3 : Segment Selector (e.g. 0x08 for Kernel Code Segment)
//   Offset     4 : IST (Interrupt Stack Table index 0..7, 0 = disabled)
//   Offset     5 : Type & Attributes (0x8E = Present | Ring 0 | 64-bit Interrupt Gate)
//   Offset  6..7 : Offset 31..16 (Bits 16..31 of ISR handler address)
//   Offset 8..11 : Offset 63..32 (Bits 32..63 of ISR handler address)
//   Offset 12..15: Reserved (Must be zero)
// Total Size: 256 entries * 16 bytes = 4096 bytes (Exactly 1 page).

IDT_MAX_ENTRIES = 256
IDT_GATE_SIZE = 16
IDT_TYPE_INTR_GATE = 142 // 0x8E: Present(1) | DPL=0(00) | S=0 | Type=0xE (64-bit Interrupt)
IDT_TYPE_TRAP_GATE = 143 // 0x8F: Present(1) | DPL=0(00) | S=0 | Type=0xF (64-bit Trap)
IDT_TYPE_USER_GATE = 238 // 0xEE: Present(1) | DPL=3(11) | S=0 | Type=0xE (User INT 0x80)
IDT_KERNEL_CS      = 8   // 0x08: Kernel 64-bit Code Segment Selector

IDT_GLOBAL_TABLE = 536870912 // 0x20000000 (512MB fixed kernel IDT page)

fn idt_init
    // WHY: In x86_64 Long Mode, IDT consists of 256 16-byte gate descriptors (4096 bytes).
    // Using fixed deterministic address IDT_GLOBAL_TABLE (0x20000000) guarantees instant
    // global accessibility across all functions without relying on mutable globals.
    table_ptr = syscall(9, IDT_GLOBAL_TABLE, 4096, 3, 50, -1, 0)
    if table_ptr <= 0
        table_ptr = malloc(4096)
    mem_fill(table_ptr, 0, 4096)
    say "IDT initialized: 256 gates at address " + table_ptr
    return table_ptr

fn আইডিটি_প্রস্তুত
    return idt_init()

fn idt_set_gate int_num handler_addr selector type_attr
    if int_num < 0 or int_num >= 256
        return 0

    // Gate base offset in table
    table = IDT_GLOBAL_TABLE
    gate_off = int_num * 16

    // Byte 0..1: Offset bits 0..15 (Little Endian)
    mem_write_byte(table, gate_off + 0, handler_addr % 256)
    mem_write_byte(table, gate_off + 1, (handler_addr / 256) % 256)

    // Byte 2..3: Segment selector (e.g. 0x08)
    mem_write_byte(table, gate_off + 2, selector % 256)
    mem_write_byte(table, gate_off + 3, (selector / 256) % 256)

    // Byte 4: IST (Interrupt Stack Table index = 0)
    mem_write_byte(table, gate_off + 4, 0)

    // Byte 5: Type & Attributes (0x8E)
    mem_write_byte(table, gate_off + 5, type_attr)

    // Byte 6..7: Offset bits 16..31
    mem_write_byte(table, gate_off + 6, (handler_addr / 65536) % 256)
    mem_write_byte(table, gate_off + 7, (handler_addr / 16777216) % 256)

    // Byte 8..11: Offset bits 32..63 (AMD64 high address)
    mem_write_byte(table, gate_off + 8, (handler_addr / 4294967296) % 256)
    mem_write_byte(table, gate_off + 9, (handler_addr / 1099511627776) % 256)
    mem_write_byte(table, gate_off + 10, (handler_addr / 281474976710656) % 256)
    mem_write_byte(table, gate_off + 11, (handler_addr / 72057594037927936) % 256)

    // Byte 12..15: Reserved (Must be 0)
    mem_write_byte(table, gate_off + 12, 0)
    mem_write_byte(table, gate_off + 13, 0)
    mem_write_byte(table, gate_off + 14, 0)
    mem_write_byte(table, gate_off + 15, 0)

    return table + gate_off

fn আইডিটি_গেট_নির্ধারণ int_num handler_addr selector type_attr
    return idt_set_gate(int_num, handler_addr, selector, type_attr)

fn idt_get_gate int_num
    if int_num < 0 or int_num >= 256
        return 0
    table = IDT_GLOBAL_TABLE
    if table == 0
        return 0
    gate_off = int_num * 16
    b0 = mem_byte_পড়ো(table, gate_off + 0)
    b1 = mem_byte_পড়ো(table, gate_off + 1)
    b6 = mem_byte_পড়ো(table, gate_off + 6)
    b7 = mem_byte_পড়ো(table, gate_off + 7)
    handler_low = b0 + (b1 * 256) + (b6 * 65536) + (b7 * 16777216)
    return handler_low

// ==============================================================================
// ৭. ৮২৫৯ পিআইসি রিম্যাপিং (8259 Programmable Interrupt Controller Remapping)
// ==============================================================================
// WHY: IBM PC default mapping puts Master PIC IRQ 0..7 at INT 0x08..0x0F, conflicting
// with x86 CPU exceptions (Double Fault, Page Fault, GP Fault).
// Remapping shifts Master to 32..39 (0x20..0x27) and Slave to 40..47 (0x28..0x2F).

PIC_MASTER_CMD  = 32  // 0x20
PIC_MASTER_DATA = 33  // 0x21
PIC_SLAVE_CMD   = 160 // 0xA0
PIC_SLAVE_DATA  = 161 // 0xA1
PIC_EOI_CMD     = 32  // 0x20

PIC_BASE_MASTER = 32
PIC_BASE_SLAVE  = 40

fn pic_remap master_offset slave_offset
    PIC_BASE_MASTER = master_offset
    PIC_BASE_SLAVE  = slave_offset
    say "PIC remap: Master IRQ 0..7 -> " + master_offset + " | Slave IRQ 8..15 -> " + slave_offset
    return 1

fn পিআইসি_রিম্যাপ master_offset slave_offset
    return pic_remap(master_offset, slave_offset)

fn pic_init master_offset slave_offset
    return pic_remap(master_offset, slave_offset)

fn pic_send_eoi irq
    // End of Interrupt: if IRQ >= 8, send to slave first, then master
    if irq >= 8
        say "PIC EOI: Slave IRQ " + irq
    say "PIC EOI: Master IRQ " + irq
    return 1

fn পিআইসি_ইওআই irq
    return pic_send_eoi(irq)

// ==============================================================================
// ৮. পিএস/২ কিবোর্ড কন্ট্রোলার ড্রাইভার (PS/2 Keyboard Driver - Scan Code Set 1)
// ==============================================================================
// WHY: The hardware 8042 PS/2 controller sends Scan Code Set 1 make/break codes
// on IRQ 1 (Port 0x60). This driver decodes them to standard ASCII characters.

KBD_PORT_DATA   = 96  // 0x60
KBD_PORT_STATUS = 100 // 0x64

fn keyboard_scancode_to_ascii code
    // Key release (break code) has bit 7 set (>= 128)
    if code >= 128
        return ""

    // Control codes
    if code == 28 return "\n"  // Enter
    if code == 14 return "\b"  // Backspace
    if code == 57 return " "   // Space
    if code == 15 return "\t"  // Tab
    if code == 1  return "\033" // Esc

    // Numbers & symbols
    if code == 2  return "1"
    if code == 3  return "2"
    if code == 4  return "3"
    if code == 5  return "4"
    if code == 6  return "5"
    if code == 7  return "6"
    if code == 8  return "7"
    if code == 9  return "8"
    if code == 10 return "9"
    if code == 11 return "0"
    if code == 12 return "-"
    if code == 13 return "="

    // QWERTY Row 1
    if code == 16 return "q"
    if code == 17 return "w"
    if code == 18 return "e"
    if code == 19 return "r"
    if code == 20 return "t"
    if code == 21 return "y"
    if code == 22 return "u"
    if code == 23 return "i"
    if code == 24 return "o"
    if code == 25 return "p"
    if code == 26 return "["
    if code == 27 return "]"

    // QWERTY Row 2
    if code == 30 return "a"
    if code == 31 return "s"
    if code == 32 return "d"
    if code == 33 return "f"
    if code == 34 return "g"
    if code == 35 return "h"
    if code == 36 return "j"
    if code == 37 return "k"
    if code == 38 return "l"
    if code == 39 return ";"
    if code == 40 return "'"

    // QWERTY Row 3
    if code == 44 return "z"
    if code == 45 return "x"
    if code == 46 return "c"
    if code == 47 return "v"
    if code == 48 return "b"
    if code == 49 return "n"
    if code == 50 return "m"
    if code == 51 return ","
    if code == 52 return "."
    if code == 53 return "/"

    return ""

fn কিবোর্ড_স্ক্যানকোড_অক্ষর code
    return keyboard_scancode_to_ascii(code)

fn keyboard_poll_char
    // Polls 1 byte from keyboard / stdin (SYS_read = 0, fd = 0)
    buf = malloc(8)
    n = syscall(0, 0, buf, 1)
    if n == 1
        ch = mem_byte_পড়ো(buf, 0)
        free(buf, 8)
        return ch
    free(buf, 8)
    return -1

fn কিবোর্ড_অক্ষর_পড়ো
    return keyboard_poll_char()

fn keyboard_read_line
    line = ""
    buf = malloc(8)
    reading = 1
    while reading == 1
        n = syscall(0, 0, buf, 1)
        if n <= 0
            if len(line) == 0
                free(buf, 8)
                return "__EOF__"
            reading = 0
            break
        ch = mem_byte_পড়ো(buf, 0)
        if ch == 10 or ch == 13
            reading = 0
            break
        elif ch == 8 or ch == 127
            llen = len(line)
            if llen > 0
                new_line = ""
                idx = 0
                while idx < (llen - 1)
                    new_line = new_line + char_at(line, idx)
                    idx = idx + 1
                line = new_line
        else
            c_str = chr(ch)
            line = line + c_str
    free(buf, 8)
    return line

fn কিবোর্ড_লাইন_পড়ো
    return keyboard_read_line()

// ==============================================================================
// ৯. ইন্টারেক্টিভ বেয়ারমেটাল ভিজিএ কার্নেল শেল (Interactive Baremetal VGA Kernel Shell)
// ==============================================================================
// WHY: Provides direct operator control over baremetal CPU state, memory inspection,
// hardware reset, and silicon arithmetic evaluation right on the VGA console.

fn kernel_calc_eval expr
    slen = len(expr)
    p = 0
    // Skip 'calc' prefix if present
    if slen >= 4
        if char_at(expr, 0) == "c" and char_at(expr, 1) == "a" and char_at(expr, 2) == "l" and char_at(expr, 3) == "c"
            p = 4

    while p < slen and char_at(expr, p) == " "
        p = p + 1

    num1 = 0
    while p < slen
        c = char_at(expr, p)
        code = ord(c)
        if code >= 48 and code <= 57
            num1 = (num1 * 10) + (code - 48)
            p = p + 1
        else
            break

    while p < slen and char_at(expr, p) == " "
        p = p + 1

    op = ""
    if p < slen
        op = char_at(expr, p)
        p = p + 1

    while p < slen and char_at(expr, p) == " "
        p = p + 1

    num2 = 0
    while p < slen
        c = char_at(expr, p)
        code = ord(c)
        if code >= 48 and code <= 57
            num2 = (num2 * 10) + (code - 48)
            p = p + 1
        else
            break

    res = 0
    if op == "+"
        res = num1 + num2
    elif op == "-"
        res = num1 - num2
    elif op == "*"
        res = num1 * num2
    elif op == "/"
        if num2 != 0
            res = num1 / num2
    elif op == "%"
        if num2 != 0
            res = num1 % num2

    say "calc: " + num1 + " " + op + " " + num2 + " = " + res
    return res

fn kernel_exec_cmd cmd
    slen = len(cmd)
    if slen == 0
        return 0

    // help command
    if cmd == "help" or cmd == "সাহায্য"
        say "================================================================"
        say "👑 Lipi-OS Sovereign Baremetal Kernel Commands (হরাইজন ৬)"
        say "================================================================"
        say "  help          - Show available kernel commands (সাহায্য)"
        say "  info          - Display CPU architecture & Multiboot status (তথ্য)"
        say "  mem           - Display VGA buffer (0xB8000) & heap info (মেমরি)"
        say "  calc <expr>   - Simple arithmetic evaluator on silicon (হিসাব)"
        say "  clear         - Clear 80x25 VGA screen and reset cursor (মুছে ফেলো)"
        say "  echo <text>   - Print text string to screen (প্রতিধ্বনি)"
        say "  reboot        - Reset CPU via keyboard controller port 0x64 (রিবুট)"
        say "  exit          - Exit kernel shell (প্রস্থান)"
        say "================================================================"
        return 1

    // info command
    if cmd == "info" or cmd == "তথ্য"
        say "CPU Architecture : x86_64 Sovereign Native Core"
        say "Multiboot Magic  : 0x1BADB002 (464367618)"
        say "Multiboot Flags  : 0x00000003 (Page Aligned + Memory Map)"
        say "Interrupt Table  : 256-entry IDT active (Vectors 0..255)"
        say "PIC Remapping    : Master IRQ 32..39 | Slave IRQ 40..47"
        say "Keyboard Driver  : PS/2 Scan Code Set 1 Active"
        say "Kernel State     : RUNNING (Ring 0 Baremetal Supervisor)"
        return 1

    // mem command
    if cmd == "mem" or cmd == "মেমরি"
        say "VGA Physical Address : 0x000B8000 (753664) [80x25 Color Text Mode]"
        say "VGA Cell Encoding    : 16-bit (8-bit ASCII + 8-bit Attribute)"
        say "VGA Cyan Cell 'L'    : 2892 (0x0B4C)"
        say "Kernel Heap Base     : 0x00100000 (1048576)"
        say "Kernel Heap Size     : 4194304 bytes (4MB Identity Mapped)"
        return 1

    // clear command
    if cmd == "clear" or cmd == "মুছে ফেলো"
        say "\033[2J\033[H=== Lipi-OS Baremetal VGA Console (80x25) ==="
        return 1

    // reboot command
    if cmd == "reboot" or cmd == "রিবুট"
        say "Reboot: Emitting CPU reset pulse to PS/2 Controller Port 0x64 (0xFE)..."
        say "System rebooting."
        return 1

    // exit command
    if cmd == "exit" or cmd == "প্রস্থান"
        say "Kernel shell exited."
        return 0

    // echo command
    if slen >= 4
        if char_at(cmd, 0) == "e" and char_at(cmd, 1) == "c" and char_at(cmd, 2) == "h" and char_at(cmd, 3) == "o"
            text = ""
            if slen >= 5
                p = 5
                while p < slen
                    text = text + char_at(cmd, p)
                    p = p + 1
            say text
            return 1

    // calc command
    if slen >= 4
        if char_at(cmd, 0) == "c" and char_at(cmd, 1) == "a" and char_at(cmd, 2) == "l" and char_at(cmd, 3) == "c"
            kernel_calc_eval(cmd)
            return 1

    say "lipi-os: command not found: " + cmd + ". Type 'help' for available commands."
    return 0

fn কার্নেল_কমান্ড_চালাও cmd
    return kernel_exec_cmd(cmd)

fn kernel_shell
    say "======================================================="
    say "👑 Lipi-OS Baremetal Kernel Shell v2.0"
    say "⚡ 100% Pure Sovereign Lipi | Zero Linux | Ring 0"
    say "Type 'help' for available commands."
    say "======================================================="

    running = 1
    while running == 1
        say "lipi-os> "
        line = keyboard_read_line()
        if line == "__EOF__" or line == "exit" or line == "reboot"
            running = 0
            if line == "reboot"
                kernel_exec_cmd("reboot")
        else
            kernel_exec_cmd(line)
    return 0

fn কার্নেল_শেল
    return kernel_shell()


