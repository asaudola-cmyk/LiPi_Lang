@! ============================================================================
@! MAYA E2E TIER 1 — F08.2: 64-Bit GDT / IDT Segment Descriptors
@! File: tests/e2e/tier1_features/os/test_f08_boot_gdt_descriptors.maya
@! ============================================================================

import "universe/os/drivers/idt"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F08.2: 64-bit IDT Descriptors")

  gate = idt_gate_new(2147487744, 8, 142) @! 0x80001000, CS=8, 0x8E
  assert_eq(gate.selector, 8, "Selector is 8")
  assert_eq(gate.type_attr, 142, "Type attr is 142 (0x8E)")

  bytes16 = idt_gate_serialize_16b(gate)
  assert_eq(bytes16.len(), 16, "Serialized descriptor is 16 bytes")

  println("✓ PASS: F08.2 64-bit IDT Descriptors")
  return 0
@end
