@! ============================================================================
@! MAYA OS STAGE 5 — BARE-METAL MULTIBOOT HEADER
@! 100% Written in Pure Maya Language
@! ============================================================================

@fn generate_multiboot_header()
  @! Multiboot 1 Magic: 0x1BADB002
  @! Flags: 0x00000003 (Align modules, mem info)
  @! Checksum: -(magic + flags)
  
  magic = 0x1BADB002
  flags = 0x00000003
  checksum = 0 - (magic + flags)
  
  header = [
    @! Magic
    magic % 256, (magic / 256) % 256, (magic / 65536) % 256, (magic / 16777216) % 256,
    @! Flags
    flags % 256, (flags / 256) % 256, (flags / 65536) % 256, (flags / 16777216) % 256,
    @! Checksum
    checksum % 256, (checksum / 256) % 256, (checksum / 65536) % 256, (checksum / 16777216) % 256
  ]
  
  return header
@end

@fn emit_bootloader_stub(out_path)
  mb_header = generate_multiboot_header()
  
  @! Extremely simple stub that halts
  @! cli (0xFA), hlt (0xF4), jmp -2 (0xEB, 0xFD)
  boot_code = [
    0xFA, 0xF4, 0xEB, 0xFD
  ]
  
  final_bin = []
  @for b in mb_header
    final_bin = final_bin.push(b)
  @end
  @for b in boot_code
    final_bin = final_bin.push(b)
  @end
  
  return final_bin
@end
