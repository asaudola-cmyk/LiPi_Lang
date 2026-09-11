@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE F08: BARE-METAL BOOT & DRIVERS
@! File: tests/e2e/tier1_features/os/test_f08_boot_drivers.maya
@! Description: Validates Multiboot2, VGA Text/LFB, UART Serial, IDT, Disk & Paging
@! ============================================================================

import "universe/os/boot/multiboot"
import "universe/os/drivers/vga"
import "universe/os/drivers/serial"
import "universe/os/drivers/idt"
import "universe/os/drivers/disk"
import "universe/os/drivers/memory"
import "universe/tools/maya_test"

@fn test_f08_01_multiboot2_checksum()
  hdr = multiboot2_create_header(1024, 768, 32)
  assert_eq(hdr.magic, 3897741526, "Multiboot2 magic must be 0xE85250D6")
  assert_eq(hdr.architecture, 0, "Architecture must be 0 (i386/x86_64)")
  assert_eq(hdr.header_length, 44, "Header length must be 44 bytes")

  @! Checksum invariant: (magic + arch + header_length + checksum) == 0
  sum = hdr.magic + hdr.architecture + hdr.header_length + hdr.checksum
  assert_eq(sum, 0, "Multiboot2 header checksum invariant must sum to 0")

  bytes = multiboot2_serialize_binary(hdr, 1024, 768, 32)
  assert_eq(bytes.len(), 44, "Serialized binary stream must have length 44")
@end

@fn test_f08_02_vga_text_scroll()
  vga_buf = vga_text_buffer_new()
  assert_eq(vga_buf.width, 80, "VGA width is 80")
  assert_eq(vga_buf.height, 25, "VGA height is 25")
  assert_eq(vga_buf.cursor_x, 0, "Initial cursor X is 0")
  assert_eq(vga_buf.cursor_y, 0, "Initial cursor Y is 0")

  @! Print 30 lines (exceeding 25 rows) to trigger scrolling
  line_idx = 0
  @while line_idx < 30
    line_str = "Line " + line_idx.to_str() + "\n"
    vga_buf = vga_print_str(vga_buf, line_str)
    line_idx = line_idx + 1
  @end

  assert_eq(vga_buf.cursor_y, 24, "Cursor Y clamped to bottom row 24 after scroll")
  assert_eq(vga_buf.cursor_x, 0, "Cursor X at line beginning")

  @! Verify LFB pixel offset computation
  lfb = vga_lfb_new(4244635648, 1024, 768, 32) @! 0xFD000000
  off = vga_lfb_pixel_offset(lfb, 100, 50)
  @! pitch = 1024 * 4 = 4096; off = 50 * 4096 + 100 * 4 = 204800 + 400 = 205200
  assert_eq(off, 205200, "LFB pixel byte offset matches 205200")
@end

@fn test_f08_03_uart_serial_tx()
  com1 = serial_com1_init()
  assert_eq(com1.base_port, 1016, "COM1 port base is 0x3F8 (1016)")
  assert_eq(com1.baud_rate, 115200, "COM1 default baud rate is 115200")
  assert_eq(com1.divisor, 1, "Divisor for 115200 is 1")
  assert_eq(com1.is_initialized, 1, "Port is initialized")

  com1 = serial_write_line(com1, "MAYA_SOVEREIGN_OS_BOOT")
  assert_gt(com1.tx_log.len(), 20, "UART TX log contains transmitted bytes")
@end

@fn test_f08_04_idt_64bit_encoding()
  @! 64-bit IDT gate for handler at 0x0000000080001000, selector 8 (0x08), type 142 (0x8E)
  isr_addr = 2147487744 @! 0x80001000
  gate = idt_gate_new(isr_addr, 8, 142)
  assert_eq(gate.selector, 8, "Code segment selector is 8")
  assert_eq(gate.type_attr, 142, "Type attribute is 0x8E (142)")

  bytes16 = idt_gate_serialize_16b(gate)
  assert_eq(bytes16.len(), 16, "Serialized IDT gate is exactly 16 bytes")

  @! PIC vector mapping: IRQ 0 -> Vector 32 (0x20), IRQ 8 -> Vector 40 (0x28)
  pic = pic_init(32, 40)
  v0 = pic_calc_irq_vector(pic, 0)
  v8 = pic_calc_irq_vector(pic, 8)
  assert_eq(v0, 32, "IRQ 0 maps to vector 32")
  assert_eq(v8, 40, "IRQ 8 maps to vector 40")

  @! PIT timer divisor for 100 Hz
  div100 = pit_calc_divisor(100)
  @! 1193182 / 100 = 11931
  assert_eq(div100, 11931, "PIT divisor for 100 Hz matches 11931")
@end

@fn test_f08_05_disk_sectors()
  disk = disk_init()
  assert_eq(disk.sector_size, 512, "Sector size is 512 bytes")
  assert_eq(disk.total_sectors, 2097152, "Total sectors is 2097152 (1GB)")

  @! Read unwritten sector 100 (initial zeroed)
  sec_data = disk_read_sector(disk, 100)
  assert_eq(sec_data.len(), 512, "Read sector has 512 bytes")
  assert_eq(sec_data[0], 0, "Initial sector byte is 0")
@end

@fn test_f08_06_page_allocator_4kb()
  @! 1MB physical memory -> 256 4KB frames
  allocator = page_allocator_new(1048576)
  assert_eq(allocator.total_frames, 256, "Total frames is 256")
  assert_eq(allocator.free_frames, 256, "Initial free frames is 256")

  f0 = page_alloc_frame(allocator)
  assert_eq(f0, 0, "Frame 0 address is 0")
  assert_eq(allocator.free_frames, 255, "Free frames decremented to 255")

  f1 = page_alloc_frame(allocator)
  assert_eq(f1, 4096, "Frame 1 address is 4096")
  assert_eq(allocator.free_frames, 254, "Free frames decremented to 254")

  f2 = page_alloc_frame(allocator)
  assert_eq(f2, 8192, "Frame 2 address is 8192")

  @! Free frame 1
  freed = page_free_frame(allocator, 4096)
  assert_eq(freed, 1, "page_free_frame returns 1 on success")
  assert_eq(allocator.free_frames, 254, "Free frames restored after deallocation")

  @! Next allocation reclaims frame 1 (4096)
  f_reused = page_alloc_frame(allocator)
  assert_eq(f_reused, 4096, "Bitmap allocator reclaims freed frame 4096")

  @! Test 4-level virtual address decomposition
  @! e.g., 0x00007FFFF7DD5000
  va = page_split_virtual_address(4096)
  assert_eq(va.offset_in_page, 0, "Page offset is 0")
  assert_eq(va.pt_index, 1, "PT index for 4096 is 1")
@end

@fn run_all_f08_tests()
  println("=================================================================")
  println("▶ [TIER 1] Feature F08: Bare-Metal Boot & Drivers Suite")
  println("=================================================================")

  total = 0
  passed = 0

  println("  [RUN] test_f08_01_multiboot2_checksum")
  test_f08_01_multiboot2_checksum()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f08_01_multiboot2_checksum")

  println("  [RUN] test_f08_02_vga_text_scroll")
  test_f08_02_vga_text_scroll()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f08_02_vga_text_scroll")

  println("  [RUN] test_f08_03_uart_serial_tx")
  test_f08_03_uart_serial_tx()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f08_03_uart_serial_tx")

  println("  [RUN] test_f08_04_idt_64bit_encoding")
  test_f08_04_idt_64bit_encoding()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f08_04_idt_64bit_encoding")

  println("  [RUN] test_f08_05_disk_sectors")
  test_f08_05_disk_sectors()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f08_05_disk_sectors")

  println("  [RUN] test_f08_06_page_allocator_4kb")
  test_f08_06_page_allocator_4kb()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f08_06_page_allocator_4kb")

  println("-----------------------------------------------------------------")
  println("F08 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  return 0
@end

@fn main()
  return run_all_f08_tests()
@end
