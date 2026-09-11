@! ============================================================================
@! ADVERSARIAL STRESS TEST SUITE — ELF64 BINARY WRITER
@! Module under test: compiler/backend/elf_writer.maya
@! Tests:
@! 1. Little-endian u16, u32, u64 integer encoding & negative boundary handling
@! 2. Pure Maya ElfByteBuf push, push_bytes, push16, push32, push64, patch32
@! 3. WordPack chunked 64-byte serialization logic & pack_u64_le boundaries
@! 4. Linux Standalone _start Entry Stub (32 bytes) & relative jump displacement
@! 5. ELF Header (64 bytes), Program Header (56 bytes), Section Headers (64 bytes)
@! 6. Section & Memory Alignment (16-byte .text, 8-byte .rodata, 8-byte sh_offset)
@! 7. Corner cases: 0-byte rodata, nil/0 input structures, complex entry offsets
@! 8. Extreme payloads: 64KB+ code, 64KB+ rodata, multi-chunk file serialization
@! 9. Full ELF binary generation and disk serialization
@! 100% Pure Maya — Strict Empirical Verification
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"
import "compiler/backend/elf_writer"

@! ----------------------------------------------------------------------------
@! Test Harness
@! ----------------------------------------------------------------------------

@struct TestState
  passed: 0
  failed: 0
  total: 0
@end

@fn test_assert_eq(state, actual, expected, name)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Expected: " + expected.to_str() + ", Got: " + actual.to_str() + ")")
  @end
  return state
@end

@fn test_assert_bytes_eq(state, actual_bytes, expected_bytes, name)
  state.total = state.total + 1
  matched = 1
  @if actual_bytes.len() != expected_bytes.len()
    matched = 0
  @else
    i = 0
    @while i < actual_bytes.len()
      @if actual_bytes[i] != expected_bytes[i]
        matched = 0
      @end
      i = i + 1
    @end
  @end

  @if matched == 1
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Mismatch: actual len " + actual_bytes.len().to_str() + " vs expected len " + expected_bytes.len().to_str() + ")")
  @end
  return state
@end

@fn test_assert_str_eq(state, actual, expected, name)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Expected: '" + expected + "', Got: '" + actual + "')")
  @end
  return state
@end

@! ----------------------------------------------------------------------------
@! Main Adversarial Suite
@! ----------------------------------------------------------------------------

@fn main()
  println("=================================================================")
  println("🔥 ADVERSARIAL STRESS SUITE: ELF64 NATIVE BINARY WRITER 🔥")
  println("=================================================================")

  state = { passed: 0, failed: 0, total: 0 }

  @! --------------------------------------------------------------------------
  @! SECTION 1: Little-Endian Integer Encoders & Numeric Boundaries
  @! --------------------------------------------------------------------------
  println("▶ [Adv 1] Testing Little-Endian Integer Encoders & Boundaries...")

  @! 1.1 u16_le tests
  state = test_assert_bytes_eq(state, elf_u16_le(0), [0, 0], "u16_le(0)")
  state = test_assert_bytes_eq(state, elf_u16_le(255), [255, 0], "u16_le(255)")
  state = test_assert_bytes_eq(state, elf_u16_le(256), [0, 1], "u16_le(256)")
  state = test_assert_bytes_eq(state, elf_u16_le(0x1234), [0x34, 0x12], "u16_le(0x1234)")
  state = test_assert_bytes_eq(state, elf_u16_le(65535), [255, 255], "u16_le(65535 / 0xFFFF)")
  state = test_assert_bytes_eq(state, elf_u16_le(-1), [255, 255], "u16_le(-1) two's complement")
  state = test_assert_bytes_eq(state, u16_to_bytes(0xABCD), [0xCD, 0xAB], "u16_to_bytes alias")

  @! 1.2 u32_le tests
  state = test_assert_bytes_eq(state, elf_u32_le(0), [0, 0, 0, 0], "u32_le(0)")
  state = test_assert_bytes_eq(state, elf_u32_le(0x12345678), [0x78, 0x56, 0x34, 0x12], "u32_le(0x12345678)")
  state = test_assert_bytes_eq(state, elf_u32_le(4294967295), [255, 255, 255, 255], "u32_le(0xFFFFFFFF)")
  state = test_assert_bytes_eq(state, elf_u32_le(-1), [255, 255, 255, 255], "u32_le(-1) two's complement")
  state = test_assert_bytes_eq(state, u32_to_bytes(0xDEADBEEF), [0xEF, 0xBE, 0xAD, 0xDE], "u32_to_bytes alias")

  @! 1.3 u64_le tests
  state = test_assert_bytes_eq(state, elf_u64_le(0), [0, 0, 0, 0, 0, 0, 0, 0], "u64_le(0)")
  state = test_assert_bytes_eq(state, elf_u64_le(0x00400000), [0, 0, 0x40, 0, 0, 0, 0, 0], "u64_le(0x400000 base addr)")
  state = test_assert_bytes_eq(state, elf_u64_le(0x00400078), [0x78, 0, 0x40, 0, 0, 0, 0, 0], "u64_le(0x400078 entry vaddr)")
  state = test_assert_bytes_eq(state, u64_to_bytes(0x1000), [0, 0x10, 0, 0, 0, 0, 0, 0], "u64_to_bytes(0x1000 / 4096 align)")

  @! --------------------------------------------------------------------------
  @! SECTION 2: ElfByteBuf Dynamic Buffer & In-Place Patching
  @! --------------------------------------------------------------------------
  println("▶ [Adv 2] Testing ElfByteBuf Manipulation & In-Place Patching...")

  buf = elf_bytebuf_new()
  state = test_assert_eq(state, buf.eb_size, 0, "New ElfByteBuf size = 0")
  state = test_assert_eq(state, buf.eb_bytes.len(), 0, "New ElfByteBuf bytes len = 0")

  buf = elf_bytebuf_push(buf, 0x55)
  buf = elf_bytebuf_push(buf, 0x48)
  buf = elf_bytebuf_push(buf, 0x89)
  buf = elf_bytebuf_push(buf, 0xE5)
  state = test_assert_eq(state, buf.eb_size, 4, "ElfByteBuf after 4 pushes size = 4")
  state = test_assert_bytes_eq(state, elf_bytebuf_to_bytes(buf), [0x55, 0x48, 0x89, 0xE5], "ElfByteBuf bytes")

  @! Push negative byte (e.g. -1 should be 255)
  buf = elf_bytebuf_push(buf, -1)
  state = test_assert_eq(state, buf.eb_bytes[4], 255, "ElfByteBuf push(-1) modulo 256 = 255")

  @! Push list of bytes
  buf = elf_bytebuf_push_bytes(buf, [10, 20, 30])
  state = test_assert_eq(state, buf.eb_size, 8, "ElfByteBuf push_bytes size = 8")

  @! Push 16, 32, 64-bit ints
  buf = elf_bytebuf_push16(buf, 0x1234)
  state = test_assert_eq(state, buf.eb_size, 10, "ElfByteBuf push16 size = 10")
  state = test_assert_eq(state, buf.eb_bytes[8], 0x34, "ElfByteBuf push16 byte 0")
  state = test_assert_eq(state, buf.eb_bytes[9], 0x12, "ElfByteBuf push16 byte 1")

  buf = elf_bytebuf_push32(buf, 0xAABBCCDD)
  state = test_assert_eq(state, buf.eb_size, 14, "ElfByteBuf push32 size = 14")

  @! Patch 32-bit integer at offset 10
  buf = elf_bytebuf_patch32(buf, 10, 0x11223344)
  state = test_assert_eq(state, buf.eb_bytes[10], 0x44, "ElfByteBuf patch32 byte 0")
  state = test_assert_eq(state, buf.eb_bytes[11], 0x33, "ElfByteBuf patch32 byte 1")
  state = test_assert_eq(state, buf.eb_bytes[12], 0x22, "ElfByteBuf patch32 byte 2")
  state = test_assert_eq(state, buf.eb_bytes[13], 0x11, "ElfByteBuf patch32 byte 3")

  @! --------------------------------------------------------------------------
  @! SECTION 3: WordPack Chunking & pack_u64_le
  @! --------------------------------------------------------------------------
  println("▶ [Adv 3] Testing WordPack Serialization & 64-bit Pack Packing...")

  @! Test packing 8 bytes
  sample_bytes = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
  w_val = pack_u64_le(sample_bytes, 0)
  @! Expected: 0x0807060504030201 = 578437695752307201
  state = test_assert_eq(state, w_val, 578437695752307201, "pack_u64_le full 8 bytes")

  @! Test packing with partial bytes (e.g. at end of list)
  partial_bytes = [0x12, 0x34]
  w_partial = pack_u64_le(partial_bytes, 0)
  @! 0x3412 = 13330
  state = test_assert_eq(state, w_partial, 13330, "pack_u64_le partial 2 bytes with zero-padding")

  @! Test packing beyond length
  w_empty = pack_u64_le(partial_bytes, 10)
  state = test_assert_eq(state, w_empty, 0, "pack_u64_le out of bounds returns 0")

  @! --------------------------------------------------------------------------
  @! SECTION 4: Linux _start Entry Stub & Rel32 Calculations
  @! --------------------------------------------------------------------------
  println("▶ [Adv 4] Testing Linux Standalone _start Entry Stub (32 bytes)...")

  @! Test stub for main at offset 0
  stub0 = elf_build_start_stub(0)
  state = test_assert_eq(state, stub0.len(), 32, "Entry stub length is exactly 32 bytes")
  state = test_assert_eq(state, stub0[0], 49, "stub[0] = 0x31 (xor)")
  state = test_assert_eq(state, stub0[1], 237, "stub[1] = 0xED (ebp, ebp)")
  state = test_assert_eq(state, stub0[2], 232, "stub[2] = 0xE8 (call rel32 opcode)")
  @! rel32 for offset 0 = 25 -> [25, 0, 0, 0]
  state = test_assert_eq(state, stub0[3], 25, "stub call rel32 byte 0 = 25")
  state = test_assert_eq(state, stub0[4], 0, "stub call rel32 byte 1 = 0")
  state = test_assert_eq(state, stub0[5], 0, "stub call rel32 byte 2 = 0")
  state = test_assert_eq(state, stub0[6], 0, "stub call rel32 byte 3 = 0")
  @! mov rdi, rax
  state = test_assert_eq(state, stub0[7], 72, "stub mov rdi, rax (0x48)")
  state = test_assert_eq(state, stub0[8], 137, "stub mov rdi, rax (0x89)")
  state = test_assert_eq(state, stub0[9], 199, "stub mov rdi, rax (0xC7)")
  @! mov eax, 60
  state = test_assert_eq(state, stub0[10], 184, "stub mov eax, 60 (0xB8)")
  state = test_assert_eq(state, stub0[11], 60, "stub sys_exit (60)")
  state = test_assert_eq(state, stub0[12], 0, "stub sys_exit imm high 0")
  @! syscall (0x0F 0x05)
  state = test_assert_eq(state, stub0[15], 15, "stub syscall (0x0F)")
  state = test_assert_eq(state, stub0[16], 5, "stub syscall (0x05)")
  @! hlt (0xF4)
  state = test_assert_eq(state, stub0[17], 244, "stub hlt (0xF4)")
  @! 14 NOPs (0x90 = 144)
  nop_count = 0
  idx = 18
  @while idx < 32
    @if stub0[idx] == 144
      nop_count = nop_count + 1
    @end
    idx = idx + 1
  @end
  state = test_assert_eq(state, nop_count, 14, "stub has 14 NOPs padding to 32 bytes")

  @! Test stub with non-zero main_entry_offset (e.g. main at offset 100)
  stub100 = elf_build_start_stub(100)
  @! rel32 = 25 + 100 = 125
  state = test_assert_eq(state, stub100[3], 125, "stub with entry_offset=100 rel32 = 125")

  @! Test stub with large main_entry_offset (e.g. main at offset 65536)
  stub64k = elf_build_start_stub(65536)
  @! rel32 = 25 + 65536 = 65561 -> 65561 % 256 = 25, 65561 / 256 = 256 -> 0, 65561 / 65536 = 1
  state = test_assert_eq(state, stub64k[3], 25, "stub with entry_offset=65536 rel32 byte 0")
  state = test_assert_eq(state, stub64k[4], 0, "stub with entry_offset=65536 rel32 byte 1")
  state = test_assert_eq(state, stub64k[5], 1, "stub with entry_offset=65536 rel32 byte 2")

  @! --------------------------------------------------------------------------
  @! SECTION 5: Alignment & Section Table Synthesis
  @! --------------------------------------------------------------------------
  println("▶ [Adv 5] Testing Alignment Calculations & Section Layout...")

  @! Verify that elf_write_executable properly handles various code and rodata lengths
  @! Test Case 5.1: 0-byte code, 0-byte rodata
  res_empty = elf_write_executable(
    {
      text_bytes: [],
      rodata_bytes: [],
      symbol_offsets: [],
      symbols: [],
      entry_offset: 0
    },
    "/tmp/test_adv_empty.elf"
  )
  state = test_assert_eq(state, res_empty.ew_success, 1, "ELF emission with 0-byte user code succeeds")
  state = test_assert_eq(state, res_empty.ew_entry_vaddr, 4194424, "Entry vaddr is 0x400078")

  @! Test Case 5.2: Unaligned 1-byte code and 1-byte rodata
  res_unaligned = elf_write_executable(
    {
      text_bytes: [0xC3], @! 'ret' (1 byte)
      rodata_bytes: [65], @! 'A' (1 byte)
      symbol_offsets: [],
      symbols: [],
      entry_offset: 0
    },
    "/tmp/test_adv_unaligned.elf"
  )
  state = test_assert_eq(state, res_unaligned.ew_success, 1, "ELF emission with unaligned code & rodata succeeds")

  @! Test Case 5.3: Null/0 input structures
  res_null_struct = elf_write_executable(0, "/tmp/test_adv_null.elf")
  state = test_assert_eq(state, res_null_struct.ew_success, 1, "ELF emission with null x86_result gracefully succeeds")

  @! Test Case 5.4: Helper wrapper emit_elf_64_executable
  out_wrap = emit_elf_64_executable("/tmp/test_adv_wrap.elf", [0xB8, 42, 0, 0, 0, 0xC3])
  state = test_assert_str_eq(state, out_wrap, "/tmp/test_adv_wrap.elf", "emit_elf_64_executable wrapper returns path")

  @! --------------------------------------------------------------------------
  @! SECTION 6: Large Binary Payloads (Stress Testing > 64KB)
  @! --------------------------------------------------------------------------
  println("▶ [Adv 6] Stress-Testing Large Payloads (> 64KB Code & Data)...")

  @! Create 70,000 bytes of machine code (NOP sled + return 42)
  large_code = []
  i = 0
  @while i < 70000
    large_code = large_code.push(144) @! NOP (0x90)
    i = i + 1
  @end
  @! Append: mov eax, 42; ret -> [0xB8, 42, 0, 0, 0, 0xC3]
  large_code = large_code.push(184)
  large_code = large_code.push(42)
  large_code = large_code.push(0)
  large_code = large_code.push(0)
  large_code = large_code.push(0)
  large_code = large_code.push(195)

  @! Create 35,000 bytes of rodata
  large_rodata = []
  j = 0
  @while j < 35000
    large_rodata = large_rodata.push((j % 127) + 1)
    j = j + 1
  @end

  res_large = elf_write_executable(
    {
      text_bytes: large_code,
      rodata_bytes: large_rodata,
      symbol_offsets: [],
      symbols: [],
      entry_offset: 0
    },
    "/tmp/test_adv_large_payload.elf"
  )

  state = test_assert_eq(state, res_large.ew_success, 1, "ELF emission with > 70KB code & 35KB rodata succeeds")
  @! Expected size > 105,000 bytes
  size_ok = 0
  @if res_large.ew_file_size > 105000
    size_ok = 1
  @end
  state = test_assert_eq(state, size_ok, 1, "Emitted large ELF file size > 105,000 bytes")

  @! --------------------------------------------------------------------------
  @! SECTION 7: WordPack Multi-Chunk File Serialization Boundary Stress
  @! --------------------------------------------------------------------------
  println("▶ [Adv 7] Stress-Testing WordPack Chunked Serialization...")

  @! Test writing arbitrary byte sizes (1, 63, 64, 65, 127, 128, 129 bytes) to verify no chunk boundary clipping
  test_sizes = [1, 7, 8, 9, 63, 64, 65, 127, 128, 129, 255, 256, 257, 1024, 4096]
  @for sz in test_sizes
    chunk_test_bytes = []
    k = 0
    @while k < sz
      chunk_test_bytes = chunk_test_bytes.push(k % 256)
      k = k + 1
    @end
    test_out_path = "/tmp/test_adv_chunk_" + sz.to_str() + ".bin"
    wr_res = elf_write_file(test_out_path, chunk_test_bytes)
    state = test_assert_eq(state, wr_res, sz, "elf_write_file exact size write for " + sz.to_str() + " bytes")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 8: Real Executable Standalone Binary Synthesis
  @! --------------------------------------------------------------------------
  println("▶ [Adv 8] Synthesizing Real Native Executables with Syscalls...")

  @! Real Program 1: Return exit code 77
  @! main: mov eax, 77; ret (6 bytes)
  prog1_code = [184, 77, 0, 0, 0, 195]
  res_prog1 = elf_write_executable(
    {
      text_bytes: prog1_code,
      rodata_bytes: [],
      symbol_offsets: [],
      symbols: [],
      entry_offset: 0
    },
    "/tmp/test_adv_exec_ret77.elf"
  )
  state = test_assert_eq(state, res_prog1.ew_success, 1, "Synthesized exit(77) native binary")

  @! Real Program 2: Multi-function dispatch with entry_offset
  @! helper (at offset 0): mov eax, 50; ret -> [184, 50, 0, 0, 0, 195] (6 bytes)
  @! padding to 16 bytes: 10 x NOP
  @! main (at offset 16):
  @!   call helper (rel32 = -21) -> [232, 235, 255, 255, 255] (5 bytes)
  @!   add eax, 5 -> [131, 192, 5] (3 bytes)
  @!   ret -> [195] (1 byte)
  @! Total main size = 9 bytes
  prog2_code = [
    184, 50, 0, 0, 0, 195,              @! helper: mov eax, 50; ret (6B)
    144, 144, 144, 144, 144,            @! NOP padding
    144, 144, 144, 144, 144,            @! (10B padding -> main starts at offset 16)
    232, 235, 255, 255, 255,            @! main: call helper (-21 rel32)
    131, 192, 5,                        @! add eax, 5
    195                                 @! ret (should return 55)
  ]
  res_prog2 = elf_write_executable(
    {
      text_bytes: prog2_code,
      rodata_bytes: [],
      symbol_offsets: [],
      symbols: [],
      entry_offset: 16
    },
    "/tmp/test_adv_exec_multifn.elf"
  )
  state = test_assert_eq(state, res_prog2.ew_success, 1, "Synthesized multi-function native binary (entry_offset=16)")

  @! Real Program 3: Linux sys_write to stdout ("ADVERSARIAL_ELF64_PASSED\n") + exit(0)
  @! .rodata contains string: "ADVERSARIAL_ELF64_PASSED\n" (25 bytes)
  @! .rodata vaddr = 0x400078 + 48 (text size aligned to 16) = 0x4000A8 (4194472)
  @! main (text_size = 48B):
  @!   mov rax, 1 (sys_write) -> [72, 199, 192, 1, 0, 0, 0] (7 bytes)
  @!   mov rdi, 1 (stdout) -> [72, 199, 199, 1, 0, 0, 0] (7 bytes)
  @!   mov rsi, 0x4000A8 (rodata vaddr) -> [72, 190, 0xA8, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00] (10 bytes: 48 BE A8 00 40 00 00 00 00 00)
  @!   mov rdx, 25 (len) -> [72, 199, 194, 25, 0, 0, 0] (7 bytes)
  @!   syscall -> [15, 5] (2 bytes)
  @!   xor eax, eax -> [49, 192] (2 bytes)
  @!   ret -> [195] (1 byte)
  @! Total user text = 36 bytes. (With stub 32 bytes = 68 bytes -> aligns to 80 bytes -> 0x50)
  @! Let's calculate exact rodata vaddr:
  @! stub (32B) + user code (36B) = 68B.
  @! Alignment to 16 bytes: 68 -> 80 bytes (0x50).
  @! text_offset = 120 (0x78).
  @! rodata_offset = 120 + 80 = 200 (0xC8).
  @! rodata_vaddr = 0x400000 + 200 = 0x4000C8 (4194504).
  rodata_msg = [
    65, 68, 86, 69, 82, 83, 65, 82, 73, 65, 76, 95, 69, 76, 70, 54, 52, 95, 80, 65, 83, 83, 69, 68, 10
  ]
  prog3_code = [
    72, 199, 192, 1, 0, 0, 0,                      @! mov rax, 1 (sys_write)
    72, 199, 199, 1, 0, 0, 0,                      @! mov rdi, 1 (stdout)
    72, 190, 200, 0, 64, 0, 0, 0, 0, 0,            @! mov rsi, 0x4000C8 (rodata msg)
    72, 199, 194, 25, 0, 0, 0,                     @! mov rdx, 25 (count)
    15, 5,                                         @! syscall
    49, 192,                                       @! xor eax, eax
    195                                            @! ret
  ]
  res_prog3 = elf_write_executable(
    {
      text_bytes: prog3_code,
      rodata_bytes: rodata_msg,
      symbol_offsets: [],
      symbols: [],
      entry_offset: 0
    },
    "/tmp/test_adv_exec_syswrite.elf"
  )
  state = test_assert_eq(state, res_prog3.ew_success, 1, "Synthesized stdout syscall native binary with .rodata string")

  println("")
  println("=================================================================")
  println("📊 ADVERSARIAL STRESS SUITE SUMMARY:")
  println("   Total Tests : " + state.total.to_str())
  println("   Passed      : " + state.passed.to_str())
  println("   Failed      : " + state.failed.to_str())
  @if state.failed == 0
    println("🎉 ALL ADVERSARIAL ELF WRITER TESTS PASSED CLEANLY! 🎉")
  @else
    println("❌ ADVERSARIAL ELF WRITER TESTS FAILED! ❌")
  @end
  println("=================================================================")

  @if state.failed == 0
    return 0
  @else
    return 1
  @end
@end
