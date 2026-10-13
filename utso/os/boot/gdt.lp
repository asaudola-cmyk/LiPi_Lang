@! ============================================================================
@! LIPI 64-BIT LONG MODE GLOBAL DESCRIPTOR TABLE (GDT) — universe/os/boot/gdt.lp
@! 100% Written in Pure Lipi Language — Zero C / Foreign Toolchain Dependencies
@! Features: Long Mode Kernel/User Code & Data Segments, TSS 64-Bit System Descriptors,
@! and GDTR Register Serialization
@! ============================================================================

@! ----------------------------------------------------------------------------
@! 1. Segment Selector Constants
@! ----------------------------------------------------------------------------

@fn GDT_NULL_SEL() return 0 @end          @! 0x00
@fn GDT_KERNEL_CS_SEL() return 8 @end     @! 0x08 (Index 1, RPL 0)
@fn GDT_KERNEL_DS_SEL() return 16 @end    @! 0x10 (Index 2, RPL 0)
@fn GDT_USER_CS_SEL() return 27 @end      @! 0x18 | 3 = 0x1B (Index 3, RPL 3)
@fn GDT_USER_DS_SEL() return 35 @end      @! 0x20 | 3 = 0x23 (Index 4, RPL 3)
@fn GDT_TSS_SEL() return 40 @end          @! 0x28 (Index 5, RPL 0)

@! Access Byte Constants
@fn GDT_ACCESS_KERNEL_CODE() return 154 @end  @! 0x9A (P=1, DPL=0, S=1, Type=0xA)
@fn GDT_ACCESS_KERNEL_DATA() return 146 @end  @! 0x92 (P=1, DPL=0, S=1, Type=0x2)
@fn GDT_ACCESS_USER_CODE() return 250 @end    @! 0xFA (P=1, DPL=3, S=1, Type=0xA)
@fn GDT_ACCESS_USER_DATA() return 242 @end    @! 0xF2 (P=1, DPL=3, S=1, Type=0x2)
@fn GDT_ACCESS_TSS() return 137 @end          @! 0x89 (P=1, DPL=0, S=0, Type=0x9)

@! Flags Constants
@fn GDT_FLAGS_LONG_MODE() return 10 @end      @! 0xA (G=1, L=1, DB=0)
@fn GDT_FLAGS_DATA_64() return 12 @end        @! 0xC (G=1, DB=1)

@! ----------------------------------------------------------------------------
@! 2. 8-Byte GDT Entry Encoder
@! ----------------------------------------------------------------------------

@fn gdt_encode_entry(base, limit, access, flags)
  @! Limit [15:0]
  b0 = limit & 255
  b1 = (limit / 256) & 255
  
  @! Base [23:0]
  b2 = base & 255
  b3 = (base / 256) & 255
  b4 = (base / 65536) & 255
  
  @! Access Byte
  b5 = access & 255
  
  @! Flags (4 bits high) | Limit [19:16] (4 bits low)
  lim_high = (limit / 65536) & 15
  flg_bits = flags & 15
  flg_high = flg_bits * 16
  b6 = flg_high | lim_high
  
  @! Base [31:24]
  b7 = (base / 16777216) & 255
  
  return [b0, b1, b2, b3, b4, b5, b6, b7]
@end

@! ----------------------------------------------------------------------------
@! 3. 64-Bit TSS System Descriptor (16 Bytes)
@! ----------------------------------------------------------------------------

@fn gdt_encode_tss(base, limit)
  @! Low 8 bytes
  low = gdt_encode_entry(base, limit, 137, 0)
  
  @! High 8 bytes: Base [63:32] + Reserved (zeros)
  b8 = (base / 4294967296) & 255
  b9 = (base / 1099511627776) & 255
  b10 = (base / 281474976710656) & 255
  b11 = (base / 72057594037927936) & 255
  
  return [
    low[0], low[1], low[2], low[3],
    low[4], low[5], low[6], low[7],
    b8, b9, b10, b11,
    0, 0, 0, 0
  ]
@end

@! ----------------------------------------------------------------------------
@! 4. GDT Table Creation & Serialization
@! ----------------------------------------------------------------------------

@fn gdt_table_new(tss_base, tss_limit)
  entries = []
  
  @! 0: Null Descriptor
  null_desc = [0, 0, 0, 0, 0, 0, 0, 0]
  entries = entries.push(null_desc)
  
  @! 1: Kernel Code Segment (0x08)
  k_cs = gdt_encode_entry(0, 1048575, 154, 10) @! 0xFFFFF, Access 0x9A, Flags 0xA
  entries = entries.push(k_cs)
  
  @! 2: Kernel Data Segment (0x10)
  k_ds = gdt_encode_entry(0, 1048575, 146, 12) @! 0xFFFFF, Access 0x92, Flags 0xC
  entries = entries.push(k_ds)
  
  @! 3: User Code Segment (0x18 | 3)
  u_cs = gdt_encode_entry(0, 1048575, 250, 10) @! 0xFFFFF, Access 0xFA, Flags 0xA
  entries = entries.push(u_cs)
  
  @! 4: User Data Segment (0x20 | 3)
  u_ds = gdt_encode_entry(0, 1048575, 242, 12) @! 0xFFFFF, Access 0xF2, Flags 0xC
  entries = entries.push(u_ds)
  
  @! 5: TSS Descriptor (0x28, 16 bytes)
  tss_desc = gdt_encode_tss(tss_base, tss_limit)
  
  return {
    entries: entries,
    tss_bytes: tss_desc,
    tss_base: tss_base,
    tss_limit: tss_limit
  }
@end

@fn gdt_serialize(table)
  bytes = []
  
  e = 0
  n = table.entries.len()
  @while e < n
    ent = table.entries[e]
    b = 0
    @while b < 8
      bytes = bytes.push(ent[b])
      b = b + 1
    @end
    e = e + 1
  @end
  
  @! Append 16-byte TSS descriptor
  t = 0
  @while t < 16
    bytes = bytes.push(table.tss_bytes[t])
    t = t + 1
  @end
  
  return bytes @! Total 56 bytes (5*8 + 16)
@end

@! ----------------------------------------------------------------------------
@! 5. GDTR Register Pointer (Limit 16-Bit + Base 64-Bit)
@! ----------------------------------------------------------------------------

@fn gdtr_create(table_base_addr, table_bytes_len)
  limit = table_bytes_len - 1
  return {
    limit: limit,
    base_address: table_base_addr
  }
@end

@fn gdtr_serialize(gdtr)
  @! 2-byte limit (little-endian)
  l0 = gdtr.limit & 255
  l1 = (gdtr.limit / 256) & 255
  
  @! 8-byte base address (little-endian)
  addr = gdtr.base_address
  a0 = addr & 255
  a1 = (addr / 256) & 255
  a2 = (addr / 65536) & 255
  a3 = (addr / 16777216) & 255
  a4 = (addr / 4294967296) & 255
  a5 = (addr / 1099511627776) & 255
  a6 = (addr / 281474976710656) & 255
  a7 = (addr / 72057594037927936) & 255
  
  return [l0, l1, a0, a1, a2, a3, a4, a5, a6, a7] @! 10 bytes
@end
