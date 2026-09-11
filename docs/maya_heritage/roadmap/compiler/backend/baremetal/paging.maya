@! ============================================================================
@! MAYA OS KERNEL — 4-LEVEL x86-64 PAGING & VIRTUAL MEMORY (paging.my)
@! 100% Written in Pure Maya Language — Complete MMU Page Table Architecture
@! ============================================================================

@! Page Entry Flags:
@! Present = 1, Writable = 2, User = 4, WriteThrough = 8, CacheDisable = 16, HugePage = 128

@fn page_entry(phys_addr, flags)
  @! Aligns address to 4096 (0x1000) and ORs flags
  aligned = (phys_addr / 4096) * 4096
  return aligned | flags
@end

@fn init_kernel_page_tables()
  @! Create 4-level Identity Paging for first 1GB of physical RAM
  @! PML4 -> PDPT -> Page Directory (2MB Huge Pages)
  
  pml4_table = []
  pdpt_table = []
  pd_table = []
  
  @! Setup first 512 entries of 2MB Huge Pages in Page Directory (covers 1GB)
  i = 0
  @while i < 512
    phys_addr = i * 2097152 @! 2MB = 2097152 bytes
    @! Flags: Present(1) | Writable(2) | HugePage(128) = 131 (0x83)
    entry = page_entry(phys_addr, 131)
    pd_table = pd_table.push(entry)
    i = i + 1
  @end
  
  @! PDPT[0] points to PD
  pdpt_entry = page_entry(0x2000, 3) @! Present | Writable
  pdpt_table = pdpt_table.push(pdpt_entry)
  
  @! PML4[0] points to PDPT
  pml4_entry = page_entry(0x1000, 3) @! Present | Writable
  pml4_table = pml4_table.push(pml4_entry)
  
  return {
    pml4: pml4_table,
    pdpt: pdpt_table,
    page_directories: pd_table,
    mapped_memory_mb: 1024,
    huge_pages_enabled: 1
  }
@end
