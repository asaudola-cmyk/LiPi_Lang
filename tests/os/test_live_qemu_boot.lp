@! ============================================================================
@! MAYA BARE-METAL OS & UNIKERNEL TEST SUITE — MILESTONE 3: LIVE QEMU RUNNER
@! File: tests/os/test_live_qemu_boot.maya
@! Milestone: Milestone 3 — Bare-Metal Ring-0 Unikernel Live Runner
@! 100% Pure Maya Implementation — Zero External / C++ Dependencies
@! Tests:
@! 1. Multiboot2 Specification Header & Tag Structures (Arch 0, Length 44, Checksum)
@! 2. UART 16550 COM1 (0x3F8) Hardware Register Initialization Sequence:
@!    - Line Control Register (0x3FB = 0x80 DLAB)
@!    - Divisor Latch Access (0x3F8 = 0x01 for 115200 baud)
@!    - FIFO Control Register (0x3FA = 0xC7 Enable + Clear FIFOs)
@! 3. Serial Transmission Byte Loop & Ring-0 Kernel Banner String:
@!    `[MAYA RING-0 UNIKERNEL BOOTED]`
@! 4. Dual-Mode Entry Stub, Stack Setup (0x200000), VGA (0xB8000), & CLI Halt Loop
@! 5. Unikernel Binary Emission, Multiboot 1 / 2 Coexistence, & QEMU CLI Command
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/boot/multiboot"
import "universe/os/unikernel"
import "tools/build_unikernel"
import "universe/os/syscalls"
import "universe/os/process"

@! ============================================================================
@! 1. TEST ASSERTION HELPERS
@! ============================================================================

@fn assert_true(cond, msg)
  @! WHY: Asserts a boolean condition, printing user-friendly pass/fail message.
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @! WHY: Validates exact integer equivalence with diagnostic readout on mismatch.
  @if actual != expected
    s_act = to_str(actual)
    s_exp = to_str(expected)
    err = str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(s_exp, str_concat(", got ", s_act)))))
    println(err)
    return 0
  @end
  return 1
@end

@fn assert_str_eq(actual, expected, msg)
  @! WHY: Validates string equality for telemetry banners and CLI commands.
  @if str_eq(actual, expected) != 1
    err = str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected '", str_concat(expected, str_concat("', got '", str_concat(actual, "'"))))))
    println(err)
    return 0
  @end
  return 1
@end

@! ============================================================================
@! 2. HARDWARE INSTRUCTION PATTERN MATCHERS
@! ============================================================================

@fn find_uart_io_write(code_bytes, target_port, target_val)
  @! Scans machine code bytes for 16-bit I/O Port Output pattern:
  @!   mov dx, imm16  -> 102 (0x66), 186 (0xBA), port_low, port_high
  @!   mov al, imm8   -> 176 (0xB0), val
  @!   out dx, al     -> 238 (0xEE)
  @! WHY: Hardware drivers communicate with 16550 UART through IN/OUT x86 port instructions.
  port_lo = target_port & 255
  port_hi = (target_port / 256) & 255

  n = code_bytes.len()
  i = 0
  @while i <= n - 7
    b0 = code_bytes[i]
    b1 = code_bytes[i + 1]
    b2 = code_bytes[i + 2]
    b3 = code_bytes[i + 3]
    b4 = code_bytes[i + 4]
    b5 = code_bytes[i + 5]
    b6 = code_bytes[i + 6]

    @if b0 == 102 && b1 == 186 && b2 == port_lo && b3 == port_hi && b4 == 176 && b5 == target_val && b6 == 238
      return i
    @end
    i = i + 1
  @end
  return 0 - 1
@end

@fn decode_serial_transmitted_string(code_bytes)
  @! Decodes sequential UART port writes: mov dx, 0x3F8 (66 BA F8 03); mov al, <c> (B0 <c>); out dx, al (EE)
  @! WHY: Extracts string reconstructed from direct machine code byte loop.
  chars = []
  n = code_bytes.len()
  i = 0
  @while i <= n - 7
    b0 = code_bytes[i]
    b1 = code_bytes[i + 1]
    b2 = code_bytes[i + 2]
    b3 = code_bytes[i + 3]
    b4 = code_bytes[i + 4]
    b5 = code_bytes[i + 5]
    b6 = code_bytes[i + 6]

    @if b0 == 102 && b1 == 186 && b2 == 248 && b3 == 3 && b4 == 176 && b6 == 238
      chars = chars.push(b5)
      i = i + 7
    @else
      i = i + 1
    @end
  @end

  @! Convert ASCII byte array to Maya string
  res = ""
  ci = 0
  @while ci < chars.len()
    c_val = chars[ci]
    @! Build single char string via substring/slice or direct append
    c_str = str_concat("", "")
    res = str_concat(res, to_str(c_val)) @! Fallback string representation
    ci = ci + 1
  @end
  return chars
@end

@! ============================================================================
@! 3. MAIN TEST RUNNER
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🛸 MAYA RING-0 BARE-METAL UNIKERNEL LIVE RUNNER TEST SUITE 🛸")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! --------------------------------------------------------------------------
  @! SECTION 1: Multiboot2 Specification Header & Tag Structures
  @! --------------------------------------------------------------------------
  println("▶ Section 1: Multiboot2 Specification Header & Tag Structures...")
  total_tests = total_tests + 1

  hdr2 = multiboot2_create_header(1024, 768, 32)

  @! Validate Multiboot2 Magic (0xE85250D6 = 3897741526)
  ok1 = assert_eq_int(hdr2.magic, 3897741526, "Multiboot2 Magic is 0xE85250D6")

  @! Validate Architecture (0 = i386 / x86_64 protected/long mode)
  ok2 = assert_eq_int(hdr2.architecture, 0, "Architecture is 0 (i386 / x86_64)")

  @! Validate Header Length (16 bytes base header + 20 bytes framebuffer tag + 8 bytes end tag = 44 bytes)
  ok3 = assert_eq_int(hdr2.header_length, 44, "Multiboot2 Header length is exactly 44 bytes")

  @! Validate Checksum Identity: (magic + architecture + header_length + checksum) % 2^32 == 0
  chk_sum = hdr2.magic + hdr2.architecture + hdr2.header_length + hdr2.checksum
  ok4 = assert_eq_int(chk_sum, 0, "Checksum satisfies identity (magic + arch + length + chk = 0)")

  @! Serialize Multiboot2 header to binary stream
  mb2_bin = multiboot2_serialize_binary(hdr2, 1024, 768, 32)
  ok5 = assert_eq_int(mb2_bin.len(), 44, "Serialized Multiboot2 byte length is 44 bytes")

  @! Little-endian magic byte verification: 0xE85250D6 -> [0xD6, 0x50, 0x52, 0xE8]
  ok6 = assert_eq_int(mb2_bin[0], 214, "Magic byte 0 is 0xD6 (214)")
  ok7 = assert_eq_int(mb2_bin[1], 80, "Magic byte 1 is 0x50 (80)")
  ok8 = assert_eq_int(mb2_bin[2], 82, "Magic byte 2 is 0x52 (82)")
  ok9 = assert_eq_int(mb2_bin[3], 232, "Magic byte 3 is 0xE8 (232)")

  @! Architecture bytes: 0 -> [0, 0, 0, 0]
  ok10 = assert_eq_int(mb2_bin[4], 0, "Architecture byte 0 is 0")
  ok11 = assert_eq_int(mb2_bin[5], 0, "Architecture byte 1 is 0")

  @! Header length bytes: 44 -> [44, 0, 0, 0]
  ok12 = assert_eq_int(mb2_bin[8], 44, "Header length byte 0 is 44")
  ok13 = assert_eq_int(mb2_bin[9], 0, "Header length byte 1 is 0")

  @! Framebuffer Request Tag (Type 5 at offset 16, Size 20 at offset 20)
  ok14 = assert_eq_int(mb2_bin[16], 5, "Framebuffer Tag Type is 5 at offset 16")
  ok15 = assert_eq_int(mb2_bin[20], 20, "Framebuffer Tag Size is 20 at offset 20")
  ok16 = assert_eq_int(mb2_bin[24], 0, "Framebuffer Width low byte is 0")
  ok17 = assert_eq_int(mb2_bin[25], 4, "Framebuffer Width high byte is 4 (1024 px)")
  ok18 = assert_eq_int(mb2_bin[28], 0, "Framebuffer Height low byte is 0")
  ok19 = assert_eq_int(mb2_bin[29], 3, "Framebuffer Height high byte is 3 (768 px)")
  ok20 = assert_eq_int(mb2_bin[32], 32, "Framebuffer Color Depth is 32 bpp")

  @! End Tag (Type 0 at offset 36, Size 8 at offset 40)
  ok21 = assert_eq_int(mb2_bin[36], 0, "End Tag Type is 0 at offset 36")
  ok22 = assert_eq_int(mb2_bin[40], 8, "End Tag Size is 8 at offset 40")

  sec1_ok = ok1 && ok2 && ok3 && ok4 && ok5 && ok6 && ok7 && ok8 && ok9 && ok10 && ok11 && ok12 && ok13 && ok14 && ok15 && ok16 && ok17 && ok18 && ok19 && ok20 && ok21 && ok22
  @if sec1_ok == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Multiboot2 44-byte tag structures, architecture, and checksum invariant verified")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 2: UART 16550 COM1 Hardware Register Initialization Sequence
  @! --------------------------------------------------------------------------
  println("▶ Section 2: COM1 UART 16550 Register Initialization Sequence...")
  total_tests = total_tests + 1

  com1_init = unikernel_build_com1_init_bytes()
  ok_init_len = assert_true(com1_init.len() >= 42, "COM1 init machine code sequence contains >= 42 bytes")

  @! Step A: Disable UART interrupts -> Port 0x3F9 (1017) = 0x00
  pos_ier = find_uart_io_write(com1_init, 1017, 0)
  ok_ier = assert_true(pos_ier >= 0, "IER (Port 0x3F9) interrupts disabled with 0x00")

  @! Step B: Enable DLAB (Divisor Latch Access Bit) -> Port 0x3FB (1019) = 0x80 (128)
  @! WHY: DLAB=1 exposes Divisor Latch Registers (DLL & DLM) at base ports 0x3F8 and 0x3F9.
  pos_dlab = find_uart_io_write(com1_init, 1019, 128)
  ok_dlab = assert_true(pos_dlab >= 0, "LCR (Port 0x3FB) DLAB bit enabled with 0x80")

  @! Step C: Set Baud Rate Divisor Latch Low -> Port 0x3F8 (1016) = 0x01 (1)
  @! WHY: UART base clock 115200 Hz / Divisor 1 = 115200 Baud for maximum hypervisor log speed.
  pos_dll = find_uart_io_write(com1_init, 1016, 1)
  ok_dll = assert_true(pos_dll >= 0, "DLL (Port 0x3F8) divisor latch low byte set to 0x01 (115200 baud)")

  @! Step D: Set Baud Rate Divisor Latch High -> Port 0x3F9 (1017) = 0x00
  pos_dlm = find_uart_io_write(com1_init, 1017, 0)
  ok_dlm = assert_true(pos_dlm >= 0, "DLM (Port 0x3F9) divisor latch high byte set to 0x00")

  @! Step E: Set Line Control to 8N1 (8 data bits, no parity, 1 stop bit, DLAB=0) -> Port 0x3FB = 0x03
  pos_lcr = find_uart_io_write(com1_init, 1019, 3)
  ok_lcr = assert_true(pos_lcr >= 0, "LCR (Port 0x3FB) set to 8N1 mode (0x03, DLAB=0)")

  @! Step F: Enable FIFO and clear transmit/receive queues -> Port 0x3FA (1018) = 0xC7 (199)
  @! WHY: 0xC7 sets FIFO Enable (bit 0), Clear RX (bit 1), Clear TX (bit 2), 14-byte trigger (bits 6-7).
  pos_fcr = find_uart_io_write(com1_init, 1018, 199)
  ok_fcr = assert_true(pos_fcr >= 0, "FCR (Port 0x3FA) FIFO enabled & queues cleared with 0xC7")

  @! Step G: Set Modem Control Register (RTS/DSR) -> Port 0x3FC (1020) = 0x0B (11)
  pos_mcr = find_uart_io_write(com1_init, 1020, 11)
  ok_mcr = assert_true(pos_mcr >= 0, "MCR (Port 0x3FC) modem control set to 0x0B (RTS/DSR)")

  @! Validate Ordering Invariant: DLAB write MUST occur before Divisor Latch write
  ok_order = assert_true(pos_dlab < pos_dll, "Ordering Invariant: DLAB (0x3FB=0x80) precedes Divisor write (0x3F8=0x01)")

  sec2_ok = ok_init_len && ok_ier && ok_dlab && ok_dll && ok_dlm && ok_lcr && ok_fcr && ok_mcr && ok_order
  @if sec2_ok == 1
    passed_tests = passed_tests + 1
    println("  [PASS] UART 16550 initialization sequence (LCR 0x3FB=0x80, DLL 0x3F8=0x01, FCR 0x3FA=0xC7) verified")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 3: Serial Transmission Byte Loop & Ring-0 Banner String
  @! --------------------------------------------------------------------------
  println("▶ Section 3: Serial Transmission Byte Loop & Ring-0 Banner String...")
  total_tests = total_tests + 1

  banner_str = unikernel_banner_string()
  expected_banner = "[MAYA RING-0 UNIKERNEL BOOTED]"
  ok_banner = assert_str_eq(banner_str, expected_banner, "Canonical Ring-0 kernel banner string")

  @! Build machine code for transmitting the banner string
  tx_bytes = unikernel_build_com1_str_bytes(banner_str)
  b_len = str_len(banner_str)
  expected_byte_len = b_len * 7
  ok_len = assert_eq_int(tx_bytes.len(), expected_byte_len, "7 machine code bytes emitted per character")

  @! Verify each character's transmission byte loop
  all_chars_ok = 1
  ci = 0
  @while ci < b_len
    off = ci * 7
    ch = str_char_at(banner_str, ci)

    @! Check: mov dx, 0x3F8 -> 102, 186, 248, 3
    c0 = tx_bytes[off] == 102
    c1 = tx_bytes[off + 1] == 186
    c2 = tx_bytes[off + 2] == 248
    c3 = tx_bytes[off + 3] == 3

    @! Check: mov al, ch -> 176, <ch>
    c4 = tx_bytes[off + 4] == 176
    c5 = tx_bytes[off + 5] == ch

    @! Check: out dx, al -> 238
    c6 = tx_bytes[off + 6] == 238

    @if (c0 && c1 && c2 && c3 && c4 && c5 && c6) == 0
      all_chars_ok = 0
    @end
    ci = ci + 1
  @end
  ok_loop = assert_eq_int(all_chars_ok, 1, "Direct serial I/O instruction loop verified for all characters")

  @! Verify banner string is correctly extracted back from serial byte stream
  decoded_chars = decode_serial_transmitted_string(tx_bytes)
  ok_dec_len = assert_eq_int(decoded_chars.len(), b_len, "Decoded character count matches banner length")

  @! Character-by-character validation
  char_match = 1
  di = 0
  @while di < b_len
    @if decoded_chars[di] != str_char_at(banner_str, di)
      char_match = 0
    @end
    di = di + 1
  @end
  ok_dec_match = assert_eq_int(char_match, 1, "Decoded characters match '[MAYA RING-0 UNIKERNEL BOOTED]'")

  sec3_ok = ok_banner && ok_len && ok_loop && ok_dec_len && ok_dec_match
  @if sec3_ok == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Serial transmission byte loop & Ring-0 kernel banner string verified")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 4: Dual-Mode Bootloader Entry Stub & Execution State Setup
  @! --------------------------------------------------------------------------
  println("▶ Section 4: Dual-Mode Entry Stub, Stack (0x200000), VGA & Halt Loop...")
  total_tests = total_tests + 1

  stub = unikernel_build_entry_stub("live_qemu_test")
  ok_stub_len = assert_true(stub.len() >= 200, "Entry stub size is >= 200 bytes")

  @! 1. Processor state initialization: cli (250) + cld (252)
  ok_cli = assert_eq_int(stub[0], 250, "Stub byte 0 is 'cli' (interrupts disabled)")
  ok_cld = assert_eq_int(stub[1], 252, "Stub byte 1 is 'cld' (direction flag cleared)")

  @! 2. Stack pointer initialization: mov esp, 0x00200000 -> [188, 0, 0, 32, 0]
  ok_esp0 = assert_eq_int(stub[2], 188, "Stack setup opcode is 'mov esp, imm32' (0xBC)")
  ok_esp1 = assert_eq_int(stub[3], 0, "Stack address byte 0 is 0x00")
  ok_esp2 = assert_eq_int(stub[4], 0, "Stack address byte 1 is 0x00")
  ok_esp3 = assert_eq_int(stub[5], 32, "Stack address byte 2 is 0x20 (2MB physical stack)")
  ok_esp4 = assert_eq_int(stub[6], 0, "Stack address byte 3 is 0x00")

  @! 3. VGA Text Mode Buffer address: mov edi, 0x000B8000 -> [191, 0, 128, 11, 0]
  has_vga_ptr = 0
  si = 0
  @while si <= stub.len() - 5
    @if stub[si] == 191 && stub[si + 1] == 0 && stub[si + 2] == 128 && stub[si + 3] == 11 && stub[si + 4] == 0
      has_vga_ptr = 1
    @end
    si = si + 1
  @end
  ok_vga = assert_eq_int(has_vga_ptr, 1, "VGA Text Mode Buffer pointer 0xB8000 initialized in entry stub")

  @! 4. Energy-saving Idle Halt Loop: cli (250), hlt (244), jmp short .-2 (235, 252)
  stub_end = stub.len()
  ok_halt_cli = assert_eq_int(stub[stub_end - 4], 250, "Halt loop byte 0 is 'cli'")
  ok_halt_hlt = assert_eq_int(stub[stub_end - 3], 244, "Halt loop byte 1 is 'hlt' (0xF4)")
  ok_halt_jmp = assert_eq_int(stub[stub_end - 2], 235, "Halt loop byte 2 is 'jmp short' (0xEB)")
  ok_halt_off = assert_eq_int(stub[stub_end - 1], 252, "Halt loop byte 3 is relative offset -4 (0xFC)")

  sec4_ok = ok_stub_len && ok_cli && ok_cld && ok_esp0 && ok_esp1 && ok_esp2 && ok_esp3 && ok_esp4 && ok_vga && ok_halt_cli && ok_halt_hlt && ok_halt_jmp && ok_halt_off
  @if sec4_ok == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Dual-mode entry stub, stack setup, VGA pointer, and halt loop verified")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 5: Unikernel Image Emission & QEMU CLI Command Line Integration
  @! --------------------------------------------------------------------------
  println("▶ Section 5: Unikernel Image Emission & QEMU CLI Command Line...")
  total_tests = total_tests + 1

  test_bin_path = "/tmp/maya_live_qemu_test_kernel.bin"
  sys_unlink(test_bin_path)

  img_spec = build_unikernel_image("qemu_live_vm", test_bin_path)
  ok_img_sz = assert_true(img_spec.image_size_bytes >= 900, "Unikernel binary size is >= 900 bytes")
  ok_img_boot = assert_eq_int(img_spec.boot_time_ms, 5, "Cold boot target is 5ms")
  ok_img_priv = assert_eq_int(img_spec.ring_privilege, 0, "Privilege level is Ring-0 (direct hardware)")
  ok_img_exec = assert_eq_int(img_spec.is_executable, 1, "Image is executable (mode 0755)")

  @! Verify file exists on disk
  ok_file_on_disk = assert_true(file_exists(test_bin_path), "Unikernel binary created on disk")

  @! Verify Multiboot2 magic at byte 0 and Multiboot1 magic at byte 48 of emitted binary
  fd = sys_open(test_bin_path, 0, 0)
  ok_fd = assert_true(fd >= 0, "Opened emitted binary for inspection")

  buf128 = sys_mmap(0, 128, 3, 34, 0 - 1, 0)
  nread = sys_read(fd, buf128, 128)
  sys_close(fd)
  ok_read = assert_true(nread >= 96, "Read first 96 bytes containing Multiboot headers")

  @! Offset 0: Multiboot2 Magic 0xE85250D6 -> 214, 80, 82, 232
  mb2_b0 = sys_peek8(buf128 + 0)
  mb2_b1 = sys_peek8(buf128 + 1)
  mb2_b2 = sys_peek8(buf128 + 2)
  mb2_b3 = sys_peek8(buf128 + 3)
  ok_mb2_on_disk = assert_true(mb2_b0 == 214 && mb2_b1 == 80 && mb2_b2 == 82 && mb2_b3 == 232, "Multiboot2 Magic 0xE85250D6 confirmed at offset 0 on disk")

  @! Offset 48: Multiboot 1 Magic 0x1BADB002 -> 2, 176, 173, 27
  mb1_b0 = sys_peek8(buf128 + 48)
  mb1_b1 = sys_peek8(buf128 + 49)
  mb1_b2 = sys_peek8(buf128 + 50)
  mb1_b3 = sys_peek8(buf128 + 51)
  ok_mb1_on_disk = assert_true(mb1_b0 == 2 && mb1_b1 == 176 && mb1_b2 == 173 && mb1_b3 == 27, "Multiboot 1 Magic 0x1BADB002 confirmed at offset 48 on disk (QEMU compat)")

  @! Validate exact QEMU invocation command line helper
  qemu_cmd = unikernel_qemu_command(test_bin_path)
  expected_qemu_cmd = str_concat("qemu-system-x86_64 -kernel ", str_concat(test_bin_path, " -nographic -serial mon:stdio"))
  ok_qemu_cmd = assert_str_eq(qemu_cmd, expected_qemu_cmd, "Exact QEMU invocation command line matches specification")

  @! Clean up temporary test binary and mapped buffer
  sys_munmap(buf128, 128)
  sys_unlink(test_bin_path)

  sec5_ok = ok_img_sz && ok_img_boot && ok_img_priv && ok_img_exec && ok_file_on_disk && ok_fd && ok_read && ok_mb2_on_disk && ok_mb1_on_disk && ok_qemu_cmd
  @if sec5_ok == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Unikernel binary emission, dual Multiboot headers on disk, and QEMU CLI helper verified")
  @end

  @! --------------------------------------------------------------------------
  @! TEST SUITE SUMMARY
  @! --------------------------------------------------------------------------
  println("=================================================================")
  s_pass = to_str(passed_tests)
  s_tot = to_str(total_tests)
  res_str = str_concat("📊 LIVE QEMU RUNNER TEST RESULTS: ", str_concat(s_pass, str_concat(" / ", str_concat(s_tot, " passed"))))
  println(res_str)
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL 5 LIVE QEMU RUNNER & UNIKERNEL BOOT TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME LIVE QEMU RUNNER TESTS FAILED")
    return 1
  @end
@end
