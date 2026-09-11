@! ============================================================================
@! MAYA E2E TIER 1 — F08.4: VGA 80x25 Text Buffer Driver
@! File: tests/e2e/tier1_features/os/test_f08_driver_vga_text_buffer.maya
@! ============================================================================

import "universe/os/drivers/vga"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F08.4: VGA Text Buffer")

  vga = vga_text_buffer_new()
  assert_eq(vga.width, 80, "Width is 80")
  assert_eq(vga.height, 25, "Height is 25")

  vga = vga_print_str(vga, "MAYA_VGA_TEST\n")
  assert_eq(vga.cursor_y, 1, "Cursor Y moved to line 1")
  assert_eq(vga.cursor_x, 0, "Cursor X at 0")

  println("✓ PASS: F08.4 VGA Text Buffer")
  return 0
@end
