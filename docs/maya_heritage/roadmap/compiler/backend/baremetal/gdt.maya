@! ============================================================================
@! MAYA OS KERNEL — GLOBAL DESCRIPTOR TABLE (gdt.my)
@! 100% Written in Pure Maya Language — x86-64 Long Mode GDT Setup
@! ============================================================================

@! GDT Entry Descriptor Structure (8 bytes per entry)
@! Segment Selector Offsets:
@! 0x00: Null Descriptor
@! 0x08: Kernel 64-bit Code Segment (Ring 0)
@! 0x10: Kernel 64-bit Data Segment (Ring 0)
@! 0x18: User 64-bit Code Segment (Ring 3)
@! 0x20: User 64-bit Data Segment (Ring 3)
@! 0x28: Task State Segment (TSS)

@fn create_gdt_entry(base, limit, access, flags)
  @! Encodes an 8-byte GDT entry
  b0 = limit % 256
  b1 = (limit / 256) % 256
  b2 = base % 256
  b3 = (base / 256) % 256
  b4 = (base / 65536) % 256
  b5 = access
  b6 = ((limit / 65536) % 16) | (flags * 16)
  b7 = (base / 16777216) % 256
  
  return [b0, b1, b2, b3, b4, b5, b6, b7]
@end

@fn init_maya_gdt()
  gdt_table = []
  
  @! 1. Null Descriptor
  null_entry = [0, 0, 0, 0, 0, 0, 0, 0]
  @for b in null_entry
    gdt_table = gdt_table.push(b)
  @end
  
  @! 2. Kernel Code Segment (Access: 0x9A, Flags: 0xA -> Long mode)
  kcode = create_gdt_entry(0, 0xFFFFF, 0x9A, 0xA)
  @for b in kcode
    gdt_table = gdt_table.push(b)
  @end
  
  @! 3. Kernel Data Segment (Access: 0x92, Flags: 0xC)
  kdata = create_gdt_entry(0, 0xFFFFF, 0x92, 0xC)
  @for b in kdata
    gdt_table = gdt_table.push(b)
  @end
  
  @! 4. User Code Segment (Access: 0xFA, Flags: 0xA)
  ucode = create_gdt_entry(0, 0xFFFFF, 0xFA, 0xA)
  @for b in ucode
    gdt_table = gdt_table.push(b)
  @end
  
  @! 5. User Data Segment (Access: 0xF2, Flags: 0xC)
  udata = create_gdt_entry(0, 0xFFFFF, 0xF2, 0xC)
  @for b in udata
    gdt_table = gdt_table.push(b)
  @end
  
  return {
    entries: gdt_table,
    size_bytes: gdt_table.len(),
    kernel_cs: 0x08,
    kernel_ds: 0x10,
    user_cs: 0x18 | 3,
    user_ds: 0x20 | 3
  }
@end
