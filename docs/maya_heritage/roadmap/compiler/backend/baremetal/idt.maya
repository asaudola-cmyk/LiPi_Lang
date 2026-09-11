@! ============================================================================
@! MAYA OS KERNEL — INTERRUPT DESCRIPTOR TABLE (idt.my)
@! 100% Written in Pure Maya Language — x86-64 64-bit IDT Handler Setup
@! ============================================================================

@! IDT Gate Descriptor (16 bytes on x86-64)
@! offset_1 (16 bit), selector (16 bit), ist (8 bit), type_attr (8 bit), offset_2 (16 bit), offset_3 (32 bit), zero (32 bit)

@fn create_idt_gate(handler_address, selector, type_attr)
  o1 = handler_address % 65536
  o2 = (handler_address / 65536) % 65536
  o3 = (handler_address / 4294967296) % 4294967296
  
  gate = [
    o1 % 256, (o1 / 256) % 256,
    selector % 256, (selector / 256) % 256,
    0, @! IST
    type_attr, @! 0x8E = 64-bit Interrupt Gate Present Ring 0
    o2 % 256, (o2 / 256) % 256,
    o3 % 256, (o3 / 256) % 256, 0, 0,
    0, 0, 0, 0
  ]
  return gate
@end

@fn init_maya_idt()
  idt_entries = []
  
  @! Register 256 default interrupt gates
  @! 0-31: CPU Exceptions (Divide error, Page fault, General Protection Fault)
  @! 32-47: Hardware IRQs (Timer 32, Keyboard 33, Serial 36)
  @! 128: Maya System Call Vector (0x80)
  
  i = 0
  @while i < 256
    dummy_handler = 0x401000 + (i * 16)
    gate = create_idt_gate(dummy_handler, 0x08, 0x8E)
    @for b in gate
      idt_entries = idt_entries.push(b)
    @end
    i = i + 1
  @end
  
  return {
    table: idt_entries,
    total_vectors: 256,
    size_bytes: idt_entries.len()
  }
@end
