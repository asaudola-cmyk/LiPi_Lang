@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — BARE-METAL KERNEL & DRIVERS TEST SUITE
@! File: tests/os/test_baremetal_kernel_drivers.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/boot/multiboot"
import "universe/os/drivers/vga"
import "universe/os/drivers/serial"
import "universe/os/drivers/ps2"
import "universe/os/drivers/idt"
import "universe/os/drivers/memory"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🐧 MAYA BARE-METAL OS KERNEL & HARDWARE DRIVERS TEST SUITE 🐧")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Multiboot 1 & Multiboot 2 Boot Specification
  println("▶ Section 1: Multiboot 1 & 2 Specification & Framebuffer Tags...")
  total_tests = total_tests + 1
  mb1: Multiboot1Header = multiboot1_create_header(1048576, 1024, 768, 32)
  ok1 = assert_eq_int(mb1.magic, 464367618, "Multiboot 1 Magic is 0x1BADB002")
  ok2 = assert_eq_int(mb1.magic + mb1.flags + mb1.checksum, 0, "Multiboot 1 Checksum satisfies identity (magic+flags+checksum = 0)")

  mb2: Multiboot2Header = multiboot2_create_header(1920, 1080, 32)
  ok3 = assert_eq_int(mb2.magic, 3897741526, "Multiboot 2 Magic is 0xE85250D6")
  mb2_bin = multiboot2_serialize_binary(mb2, 1920, 1080, 32)
  ok4 = assert_eq_int(mb2_bin.len(), 44, "Serialized Multiboot 2 binary header is 44 bytes")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Multiboot 1 & 2 boot headers verified")
  @end

  @! SECTION 2: VGA 80x25 Text Buffer & Cursor CRTC Driver
  println("▶ Section 2: VGA Text Mode (0xB8000) & CRTC Cursor Driver...")
  total_tests = total_tests + 1
  vga: VGATextBuffer = vga_text_buffer_new()
  vga = vga_clear(vga, 15, 0)
  vga = vga_print_str(vga, "Hello Maya OS!\nLine 2")
  ok1 = assert_eq_int(vga.cursor_x, 6, "Cursor X is 6 after Line 2")
  ok2 = assert_eq_int(vga.cursor_y, 1, "Cursor Y is 1 after newline")
  c_off = vga_get_cursor_offset(vga)
  ok3 = assert_eq_int(c_off, 86, "CRTC Cursor offset is (1 * 80) + 6 = 86")
  
  lfb = vga_lfb_new(4244635648, 1024, 768, 32) @! 0xFD000000
  lfb_off = vga_lfb_pixel_offset(lfb, 100, 50)
  ok4 = assert_eq_int(lfb_off, (50 * 1024 * 4) + (100 * 4), "LFB 32-bit pixel byte offset math verified")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] VGA text buffer, cursor math & LFB driver verified")
  @end

  @! SECTION 3: UART 16550 COM1 Serial Port Logger
  println("▶ Section 3: UART 16550 COM1 Serial Port & Baud Rate Divisor...")
  total_tests = total_tests + 1
  com1 = serial_com1_init()
  ok1 = assert_eq_int(com1.base_port, 1016, "COM1 base port is 0x3F8")
  ok2 = assert_eq_int(com1.divisor, 1, "115200 baud divisor is 1")
  
  com1 = serial_write_line(com1, "[KERNEL] Booting Pure Maya Sovereign OS...")
  ok3 = assert_true(com1.tx_log.len() > 20, "Serial port TX buffer contains kernel log bytes")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] UART 16550 serial driver & logging pipeline verified")
  @end

  @! SECTION 4: PS/2 Keyboard & Mouse Packet Decoder
  println("▶ Section 4: PS/2 Keyboard Scancodes & 3-Byte Mouse Packet Stream...")
  total_tests = total_tests + 1
  kb = ps2_keyboard_new()
  kb = ps2_process_byte(kb, 30) @! Scancode 0x1E = 'a'
  ok1 = assert_eq_int(kb.last_ascii, 97, "Decodes scancode 0x1E to lowercase 'a'")
  
  kb = ps2_process_byte(kb, 42) @! Left Shift pressed
  kb = ps2_process_byte(kb, 30) @! 'A' with shift
  ok2 = assert_eq_int(kb.last_ascii, 65, "Decodes scancode 0x1E with Shift to uppercase 'A'")
  
  kb = ps2_process_byte(kb, 170) @! 42 + 128 = 170 (Shift released break code)
  ok3 = assert_eq_int(kb.shift_pressed, 0, "Shift released state tracked")

  @! Mouse packet: Left button pressed (1), dx = 15, dy = -5 (251 with sign bit)
  mouse = ps2_mouse_decode_packet(33, 15, 251) @! b0 = 1 | (pow2(5)) = 33 (Y sign negative)
  ok4 = assert_eq_int(mouse.left_button, 1, "Mouse left button detected")
  ok5 = assert_eq_int(mouse.delta_x, 15, "Mouse delta_x is +15")
  ok6 = assert_eq_int(mouse.delta_y, -5, "Mouse delta_y sign-extended to -5")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] PS/2 keyboard scancode & mouse packet decoder verified")
  @end

  @! SECTION 5: Interrupt Descriptor Table (IDT) & PIC 8259A Remapping
  println("▶ Section 5: IDT 64-Bit Gate Serialization & PIC 8259A IRQ Vectors...")
  total_tests = total_tests + 1
  isr_addr = 140737488355328 @! 0x7FFF00000000
  gate = idt_gate_new(isr_addr, 8, 142) @! 0x8E = 142
  gate_bytes = idt_gate_serialize_16b(gate)
  ok1 = assert_eq_int(gate_bytes.len(), 16, "Serialized 64-bit IDT gate descriptor is exactly 16 bytes")
  ok2 = assert_eq_int(gate_bytes[2], 8, "Code segment selector is 0x08")
  ok3 = assert_eq_int(gate_bytes[5], 142, "Type attribute is 0x8E (Present Interrupt Gate)")

  pic = pic_init(32, 40) @! Master 0x20, Slave 0x28
  timer_vec = pic_calc_irq_vector(pic, 0)
  kbd_vec = pic_calc_irq_vector(pic, 1)
  ok4 = assert_eq_int(timer_vec, 32, "IRQ0 (PIT Timer) maps to vector 0x20 (32)")
  ok5 = assert_eq_int(kbd_vec, 33, "IRQ1 (PS/2 Keyboard) maps to vector 0x21 (33)")
  
  pit_div = pit_calc_divisor(1000) @! 1000 Hz timer ticks
  ok6 = assert_eq_int(pit_div, 1193, "1000 Hz PIT timer divisor is 1193")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] IDT 64-bit gate descriptors & PIC/PIT configuration verified")
  @end

  @! SECTION 6: Physical Page Allocator & 4-Level Paging Math
  println("▶ Section 6: Physical Page Frame Allocator (4KB) & 4-Level Paging...")
  total_tests = total_tests + 1
  @! 64MB memory space = 16384 4KB page frames
  mem_alloc = page_allocator_new(67108864)
  ok1 = assert_eq_int(mem_alloc.free_frames, 16384, "Allocator initialized with 16384 free page frames")
  
  f1 = page_alloc_frame(mem_alloc)
  ok2 = assert_eq_int(f1, 0, "First allocated frame is at physical address 0x0")
  ok3 = assert_eq_int(mem_alloc.free_frames, 16383, "Free frame count decremented to 16383")
  
  f2 = page_alloc_frame(mem_alloc)
  ok4 = assert_eq_int(f2, 4096, "Second allocated frame is at physical address 0x1000 (4096)")
  
  freed = page_free_frame(mem_alloc, f1)
  ok5 = assert_eq_int(freed, 1, "Successfully freed frame 0x0")
  ok6 = assert_eq_int(mem_alloc.free_frames, 16383, "Free frame count restored after free")

  @! 4-Level Paging Address Split
  @! Virtual Address: 0x00007FFFF7DCB042
  virt_addr = 140737351823426
  vsplit = page_split_virtual_address(virt_addr)
  ok7 = assert_eq_int(vsplit.offset_in_page, 66, "Offset in page is 0x42 (66)")
  
  pte = {
    present: 1,
    writable: 1,
    user_access: 0,
    write_through: 0,
    cache_disabled: 0,
    accessed: 0,
    dirty: 0,
    page_size_huge: 0,
    frame_address: 8388608 @! 8MB physical address
  }
  pte_val = page_entry_encode(pte)
  ok8 = assert_eq_int(pte_val, 8388611, "PTE encoded value (Frame 0x800000 | Present 1 | Writable 2 = 8388611)")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Physical page frame allocator & 4-level paging math verified")
  @end

  s_pass = to_str(passed_tests)
  s_tot = to_str(total_tests)
  res_msg = str_concat("📊 BARE-METAL KERNEL & DRIVERS TEST RESULTS: ", str_concat(s_pass, str_concat(" / ", str_concat(s_tot, " passed"))))
  println(res_msg)
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 6 PURE MAYA BARE-METAL OS TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME BARE-METAL OS TESTS FAILED")
    return 1
  @end
@end
