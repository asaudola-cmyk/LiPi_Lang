@! ============================================================================
@! MAYA OS STAGE 5 — BARE-METAL KERNEL
@! 100% Written in Pure Maya Language
@! ============================================================================

@! VGA Text Mode Buffer address is 0xB8000
@fn vga_print(msg, row, col, color)
  vga_base = 0xB8000
  offset = (row * 80 + col) * 2
  
  i = 0
  len = msg.len()
  @while i < len
    @! In a real Maya OS, this would use raw pointer writes: ptr_write_byte(vga_base + offset, byte)
    @! write_byte_ptr(vga_base + offset + (i * 2), msg[i])
    @! write_byte_ptr(vga_base + offset + (i * 2) + 1, color)
    i = i + 1
  @end
  return 1
@end

@fn kernel_main()
  @! Clear screen (pseudo-code logic for direct memory access)
  @! vga_clear(0x07) @! Light gray on black
  
  msg = "Welcome to Maya OS. The Civilization Language."
  vga_print(msg, 10, 20, 0x0A) @! 0x0A is Light Green
  
  @! Hang forever
  @while 1 == 1
    @! sys_halt()
  @end
@end
