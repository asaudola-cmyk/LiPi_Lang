import "universe/b_core/io"
import "universe/b_core/string"
import "universe/b_core/fs"

@fn emit_char(buf, offset, char)
  @! mov al, char (B0 XX)
  sys_poke8(buf + offset + 0, 176)
  sys_poke8(buf + offset + 1, char)
  @! int 0x10 (CD 10)
  sys_poke8(buf + offset + 2, 205)
  sys_poke8(buf + offset + 3, 16)
  return offset + 4
@end

@fn main()
  string_println("=== Native Maya OS Bootloader Generator ===")
  
  @! Allocate exactly 512 bytes (1 sector)
  buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  
  @! Initialize all bytes to 0
  i = 0
  @while i < 512
    sys_poke8(buf + i, 0)
    i = i + 1
  @end
  
  offset = 0
  
  @! mov ah, 0x0e (Teletype output) -> B4 0E
  sys_poke8(buf + offset + 0, 180)
  sys_poke8(buf + offset + 1, 14)
  offset = offset + 2
  
  @! Print "MAYA OS"
  offset = emit_char(buf, offset, 77)  @! M
  offset = emit_char(buf, offset, 65)  @! A
  offset = emit_char(buf, offset, 89)  @! Y
  offset = emit_char(buf, offset, 65)  @! A
  offset = emit_char(buf, offset, 32)  @! ' '
  offset = emit_char(buf, offset, 79)  @! O
  offset = emit_char(buf, offset, 83)  @! S
  
  @! jmp $ (Infinite loop) -> EB FE
  sys_poke8(buf + offset + 0, 235)
  sys_poke8(buf + offset + 1, 254)
  
  @! Boot Signature (0x55 0xAA) at bytes 510 and 511
  sys_poke8(buf + 510, 85)  @! 0x55
  sys_poke8(buf + 511, 170) @! 0xAA
  
  @! Write to boot.bin
  fd = fs_open_write("boot.bin")
  sys_syscall(1, fd, buf, 512, 0, 0, 0)
  fs_close(fd)
  
  string_println("Successfully generated boot.bin!")
  string_println("Run with: qemu-system-x86_64 -drive format=raw,file=boot.bin")
  
  sys_exit(0)
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end
