@! ============================================================================
@! MAYA E2E TIER 1 — F08.1: Multiboot2 Header Magic & Checksum
@! File: tests/e2e/tier1_features/os/test_f08_boot_multiboot2_header.maya
@! ============================================================================

import "universe/os/boot/multiboot"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F08.1: Multiboot2 Header")

  hdr = multiboot2_create_header(800, 600, 32)
  assert_eq(hdr.magic, 3897741526, "Magic 0xE85250D6")
  assert_eq(hdr.architecture, 0, "Architecture 0")
  assert_eq(hdr.header_length, 44, "Header length 44")
  
  sum = hdr.magic + hdr.architecture + hdr.header_length + hdr.checksum
  assert_eq(sum, 0, "Checksum invariant sum == 0")

  println("✓ PASS: F08.1 Multiboot2 Header")
  return 0
@end
