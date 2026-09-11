@! ============================================================================
@! MAYA 4-LEVEL MMU PAGING ENGINE (x86-64) — universe/os/boot/paging.maya
@! 100% Written in Pure Lipi Language — Zero C / Zero Libc Dependencies
@! Features: PML4, PDPT, PD (2MB Huge Pages), PT (4KB Standard Pages),
@! Page Table Entry Encoder/Decoder, Virtual Address Decomposition
@! ============================================================================

@! ----------------------------------------------------------------------------
@! 1. Page Table Flags Constants
@! ----------------------------------------------------------------------------

@fn PAGE_FLAG_PRESENT() return 1 @end
@fn PAGE_FLAG_WRITABLE() return 2 @end
@fn PAGE_FLAG_USER() return 4 @end
@fn PAGE_FLAG_WRITETHROUGH() return 8 @end
@fn PAGE_FLAG_CACHEDISABLE() return 16 @end
@fn PAGE_FLAG_ACCESSED() return 32 @end
@fn PAGE_FLAG_DIRTY() return 64 @end
@fn PAGE_FLAG_HUGE() return 128 @end
@fn PAGE_FLAG_GLOBAL() return 256 @end

@fn PAGE_SIZE_4KB() return 4096 @end
@fn PAGE_SIZE_2MB() return 2097152 @end
@fn PAGE_SIZE_1GB() return 1073741824 @end

@! ----------------------------------------------------------------------------
@! 2. Page Table Entry Encoder & Decoder
@! ----------------------------------------------------------------------------

@fn page_entry_encode(entry)
  val = (entry.frame_addr / 4096) * 4096
  
  @if entry.present == 1
    val = val | 1
  @end
  @if entry.writable == 1
    val = val | 2
  @end
  @if entry.user == 1
    val = val | 4
  @end
  @if entry.write_through == 1
    val = val | 8
  @end
  @if entry.cache_disable == 1
    val = val | 16
  @end
  @if entry.accessed == 1
    val = val | 32
  @end
  @if entry.dirty == 1
    val = val | 64
  @end
  @if entry.huge == 1
    val = val | 128
  @end
  @if entry.global == 1
    val = val | 256
  @end
  
  return val
@end

@fn page_entry_decode(val)
  frame = (val / 4096) * 4096
  
  f_pres = val & 1
  f_writ = (val / 2) & 1
  f_user = (val / 4) & 1
  f_wt = (val / 8) & 1
  f_cd = (val / 16) & 1
  f_acc = (val / 32) & 1
  f_drt = (val / 64) & 1
  f_hug = (val / 128) & 1
  f_glb = (val / 256) & 1
  
  return {
    frame_addr: frame,
    present: f_pres,
    writable: f_writ,
    user: f_user,
    write_through: f_wt,
    cache_disable: f_cd,
    accessed: f_acc,
    dirty: f_drt,
    huge: f_hug,
    global: f_glb
  }
@end

@! ----------------------------------------------------------------------------
@! 3. Virtual Address 4-Level MMU Decomposition
@! ----------------------------------------------------------------------------

@fn paging_decompose_virtual_addr(vaddr)
  offset = vaddr & 4095
  
  pt_val = vaddr / 4096
  pt_idx = pt_val & 511
  
  pd_val = vaddr / 2097152
  pd_idx = pd_val & 511
  
  pdpt_val = vaddr / 1073741824
  pdpt_idx = pdpt_val & 511
  
  pml4_val = vaddr / 549755813888
  pml4_idx = pml4_val & 511
  
  return {
    pml4_idx: pml4_idx,
    pdpt_idx: pdpt_idx,
    pd_idx: pd_idx,
    pt_idx: pt_idx,
    offset: offset
  }
@end

@! ----------------------------------------------------------------------------
@! 4. Kernel 1GB Identity Map Initializer (2MB Huge Pages)
@! ----------------------------------------------------------------------------

@fn paging_create_identity_map_1gb(pml4_phys_base, pdpt_phys_base, pd_phys_base)
  @! PML4 Table (512 entries)
  pml4_entries = []
  pml4_first = page_entry_encode({
    frame_addr: pdpt_phys_base,
    present: 1,
    writable: 1,
    user: 0,
    write_through: 0,
    cache_disable: 0,
    accessed: 0,
    dirty: 0,
    huge: 0,
    global: 0
  })
  pml4_entries = pml4_entries.push(pml4_first)
  
  p = 1
  @while p < 512
    pml4_entries = pml4_entries.push(0)
    p = p + 1
  @end
  
  @! PDPT Table (512 entries)
  pdpt_entries = []
  pdpt_first = page_entry_encode({
    frame_addr: pd_phys_base,
    present: 1,
    writable: 1,
    user: 0,
    write_through: 0,
    cache_disable: 0,
    accessed: 0,
    dirty: 0,
    huge: 0,
    global: 0
  })
  pdpt_entries = pdpt_entries.push(pdpt_first)
  
  d = 1
  @while d < 512
    pdpt_entries = pdpt_entries.push(0)
    d = d + 1
  @end
  
  @! PD Table (512 x 2MB Huge Pages = 1GB identity mapped)
  pd_entries = []
  idx = 0
  @while idx < 512
    page_phys = idx * 2097152 @! 2MB * idx
    entry = page_entry_encode({
      frame_addr: page_phys,
      present: 1,
      writable: 1,
      user: 0,
      write_through: 0,
      cache_disable: 0,
      accessed: 0,
      dirty: 0,
      huge: 1, @! 2MB Huge Page Flag
      global: 1
    })
    pd_entries = pd_entries.push(entry)
    idx = idx + 1
  @end
  
  return {
    pml4_base: pml4_phys_base,
    pdpt_base: pdpt_phys_base,
    pd_base: pd_phys_base,
    pml4: pml4_entries,
    pdpt: pdpt_entries,
    pd: pd_entries
  }
@end

@! ----------------------------------------------------------------------------
@! 5. Page Table Binary Serializer (4096 Bytes per Table)
@! ----------------------------------------------------------------------------

@fn paging_serialize_table(entries)
  bytes = []
  i = 0
  n = entries.len()
  @while i < n
    val = entries[i]
    b0 = val & 255
    b1 = (val / 256) & 255
    b2 = (val / 65536) & 255
    b3 = (val / 16777216) & 255
    b4 = (val / 4294967296) & 255
    b5 = (val / 1099511627776) & 255
    b6 = (val / 281474976710656) & 255
    b7 = (val / 72057594037927936) & 255
    
    bytes = bytes.push(b0.push)(b1).push(b2.push)(b3).push(b4.push)(b5).push(b6.push)(b7)
    i = i + 1
  @end
  
  @while bytes.len() < 4096
    bytes = bytes.push(0)
  @end
  
  return bytes
@end
