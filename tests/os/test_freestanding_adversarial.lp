@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — FREESTANDING ADVERSARIAL STRESS TEST SUITE
@! File: tests/os/test_freestanding_adversarial.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/freestanding"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn test_vector_tables_and_serialization()
  println("▶ [ADVERSARIAL 1] Vector Tables & Serialization...")
  failures = 0

  @! 1.1 ARM Cortex-M Vector Table & Boundary IRQs
  vt = cortex_m_vector_table_new(0x20010000, 0x08000040)
  @if assert_eq_int(vt.initial_sp, 0x20010000, "Cortex-M initial SP matches") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(vt.reset_handler, 0x08000041, "Cortex-M reset handler thumb bit set") == 0
    failures = failures + 1
  @end

  @! Set all 32 IRQs with patterned addresses
  i = 0
  @while i < 32
    handler_addr = 0x08001000 + (i * 16)
    vt = cortex_m_set_irq_handler(vt, i, handler_addr)
    @if assert_eq_int(vt.external_irqs[i], handler_addr | 1, "IRQ " + i.to_str() + " thumb bit set") == 0
      failures = failures + 1
    @end
    i = i + 1
  @end

  @! Out of bounds IRQ handling (must not crash or mutate table)
  vt = cortex_m_set_irq_handler(vt, -1, 0x12345678)
  vt = cortex_m_set_irq_handler(vt, 32, 0x12345678)
  vt = cortex_m_set_irq_handler(vt, 100, 0x12345678)
  @if assert_eq_int(vt.external_irqs.len(), 32, "External IRQ array length preserved at 32") == 0
    failures = failures + 1
  @end

  @! Full 192-byte serialization check
  vt_bytes = cortex_m_serialize_vector_table(vt)
  @if assert_eq_int(vt_bytes.len(), 192, "Cortex-M serialized bytes length is 192") == 0
    failures = failures + 1
  @end

  @! Check reserved core vectors (offsets 7, 8, 9, 10, 13 -> byte offsets 28..43 and 52..55 are 0)
  k = 28
  @while k < 44
    @if assert_eq_int(vt_bytes[k], 0, "Reserved core vector byte at " + k.to_str() + " is zero") == 0
      failures = failures + 1
    @end
    k = k + 1
  @end

  @! 1.2 RISC-V Trap Vector Table Serialization
  rv_table = riscv_trap_table_new(0x80000000, 1)
  j = 0
  @while j < 16
    rv_table.exception_handlers[j] = 0x80001000 + (j * 4)
    rv_table.interrupt_handlers[j] = 0x80002000 + (j * 4)
    j = j + 1
  @end

  rv_bytes = riscv_serialize_trap_table(rv_table)
  @if assert_eq_int(rv_bytes.len(), 128, "RISC-V serialized trap table length is 128") == 0
    failures = failures + 1
  @end

  @! Check first exception handler little-endian bytes: 0x80001000 -> [0x00, 0x10, 0x00, 0x80]
  @if assert_eq_int(rv_bytes[0], 0, "Exc 0 byte 0 is 0x00") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(rv_bytes[1], 16, "Exc 0 byte 1 is 0x10 (16)") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(rv_bytes[2], 0, "Exc 0 byte 2 is 0x00") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(rv_bytes[3], 128, "Exc 0 byte 3 is 0x80 (128)") == 0
    failures = failures + 1
  @end

  @! Check first interrupt handler at offset 64: 0x80002000 -> [0x00, 0x20, 0x00, 0x80]
  @if assert_eq_int(rv_bytes[64], 0, "Irq 0 byte 0 is 0x00") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(rv_bytes[65], 32, "Irq 0 byte 1 is 0x20 (32)") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(rv_bytes[66], 0, "Irq 0 byte 2 is 0x00") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(rv_bytes[67], 128, "Irq 0 byte 3 is 0x80 (128)") == 0
    failures = failures + 1
  @end

  @if failures == 0
    println("  [PASS] Vector tables and serialization stress tests passed.")
    return 1
  @end
  return 0
@end

@fn test_riscv_mtvec_extreme_addresses()
  println("▶ [ADVERSARIAL 2] RISC-V mtvec CSR Encoding / Decoding with Extreme Addresses...")
  failures = 0

  addresses = [
    0x00000000,
    0x00000004,
    0x10000000,
    0x80000000,
    0x80000004,
    0x80001000,
    0xFFFFFFFC,
    0x00000001,
    0x00000002,
    0x00000003,
    0x80000003,
    0xFFFFFFFF
  ]

  modes = [0, 1, 2, 3, 5, 7]

  a_idx = 0
  @while a_idx < addresses.len()
    addr = addresses[a_idx]
    expected_base = addr & ~3

    m_idx = 0
    @while m_idx < modes.len()
      mode = modes[m_idx]
      expected_mode = mode & 3

      mtvec = riscv_encode_mtvec(addr, mode)
      decoded_base = riscv_decode_mtvec_base(mtvec)
      decoded_mode = riscv_decode_mtvec_mode(mtvec)

      @if decoded_base != expected_base
        println("  [FAIL] mtvec base mismatch for addr " + addr.to_str() + " mode " + mode.to_str() + " -> got " + decoded_base.to_str() + ", expected " + expected_base.to_str())
        failures = failures + 1
      @end

      @if decoded_mode != expected_mode
        println("  [FAIL] mtvec mode mismatch for addr " + addr.to_str() + " mode " + mode.to_str() + " -> got " + decoded_mode.to_str() + ", expected " + expected_mode.to_str())
        failures = failures + 1
      @end

      m_idx = m_idx + 1
    @end
    a_idx = a_idx + 1
  @end

  @if failures == 0
    println("  [PASS] All 72 RISC-V mtvec extreme address & mode permutations passed.")
    return 1
  @end
  return 0
@end

@fn test_memory_simulator_edge_cases()
  println("▶ [ADVERSARIAL 3] Memory Boot Simulator (Empty/Overlapping Sections, Boundary Offsets)...")
  failures = 0

  @! 3.1 Empty .data section (data_size = 0)
  sim1 = freestanding_sim_new(0x08000000, 0x20000000)
  cfg_empty_data = freestanding_crt0_config_new(
    0x08000000,
    0x08000000,
    0x20000000,
    0,
    0x20000010,
    32,
    0x20000400,
    0x08000004
  )
  sim1 = freestanding_sim_execute_crt0(sim1, cfg_empty_data)
  @if assert_true(freestanding_sim_verify_data_copied(sim1, cfg_empty_data), "Empty .data section copy verified") == 0
    failures = failures + 1
  @end
  @if assert_true(freestanding_sim_verify_bss_zeroed(sim1, cfg_empty_data), ".bss zeroed with empty .data") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(sim1.ram[0], 170, "RAM[0] untouched with pattern 0xAA (170)") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(sim1.ram[16], 0, "RAM[16] in .bss is zeroed") == 0
    failures = failures + 1
  @end

  @! 3.2 Empty .bss section (bss_size = 0)
  sim2 = freestanding_sim_new(0x08000000, 0x20000000)
  sim2 = freestanding_sim_write_flash(sim2, 0, 0xDE)
  sim2 = freestanding_sim_write_flash(sim2, 1, 0xAD)
  sim2 = freestanding_sim_write_flash(sim2, 2, 0xBE)
  sim2 = freestanding_sim_write_flash(sim2, 3, 0xEF)
  cfg_empty_bss = freestanding_crt0_config_new(
    0x08000000,
    0x08000000,
    0x20000000,
    4,
    0x20000010,
    0,
    0x20000400,
    0x08000004
  )
  sim2 = freestanding_sim_execute_crt0(sim2, cfg_empty_bss)
  @if assert_true(freestanding_sim_verify_data_copied(sim2, cfg_empty_bss), "4-byte .data copied accurately") == 0
    failures = failures + 1
  @end
  @if assert_true(freestanding_sim_verify_bss_zeroed(sim2, cfg_empty_bss), "Empty .bss verification succeeds") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(sim2.ram[0], 0xDE, "RAM[0] == 0xDE") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(sim2.ram[3], 0xEF, "RAM[3] == 0xEF") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(sim2.ram[4], 170, "RAM[4] remains uninitialized 0xAA (170)") == 0
    failures = failures + 1
  @end

  @! 3.3 Both .data and .bss empty (data_size = 0, bss_size = 0)
  sim3 = freestanding_sim_new(0x08000000, 0x20000000)
  cfg_empty_both = freestanding_crt0_config_new(
    0x08000000, 0x08000000, 0x20000000, 0,
    0x20000000, 0,
    0x20000400, 0x08000004
  )
  sim3 = freestanding_sim_execute_crt0(sim3, cfg_empty_both)
  @if assert_true(freestanding_sim_verify_data_copied(sim3, cfg_empty_both), "Empty both data/bss copied returns true") == 0
    failures = failures + 1
  @end
  @if assert_true(freestanding_sim_verify_bss_zeroed(sim3, cfg_empty_both), "Empty both data/bss zeroed returns true") == 0
    failures = failures + 1
  @end

  @! 3.4 Contiguous .data and .bss (data: 0..63, bss: 64..127)
  sim4 = freestanding_sim_new(0x08000000, 0x20000000)
  d_idx = 0
  @while d_idx < 64
    sim4 = freestanding_sim_write_flash(sim4, d_idx, (d_idx + 1) & 255)
    d_idx = d_idx + 1
  @end
  cfg_contiguous = freestanding_crt0_config_new(
    0x08000000,
    0x08000000,
    0x20000000,
    64,
    0x20000040,
    64,
    0x20000400,
    0x08000000
  )
  sim4 = freestanding_sim_execute_crt0(sim4, cfg_contiguous)
  @if assert_true(freestanding_sim_verify_data_copied(sim4, cfg_contiguous), "Contiguous .data verified") == 0
    failures = failures + 1
  @end
  @if assert_true(freestanding_sim_verify_bss_zeroed(sim4, cfg_contiguous), "Contiguous .bss verified") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(sim4.ram[0], 1, "RAM[0] is 1") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(sim4.ram[63], 64, "RAM[63] is 64") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(sim4.ram[64], 0, "RAM[64] is 0 (.bss start)") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(sim4.ram[127], 0, "RAM[127] is 0 (.bss end)") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(sim4.ram[128], 170, "RAM[128] remains 0xAA (170)") == 0
    failures = failures + 1
  @end

  @if failures == 0
    println("  [PASS] All memory simulator edge case stress tests passed.")
    return 1
  @end
  return 0
@end

@fn test_linker_script_symbols_and_formatting()
  println("▶ [ADVERSARIAL 4] Linker Script Symbols, Formatting & Math...")
  failures = 0

  @! 4.1 Hex formatting
  @if assert_true(int_to_hex_str(0) == "0x0", "int_to_hex_str(0) is 0x0") == 0
    failures = failures + 1
  @end
  @if assert_true(int_to_hex_str(1) == "0x1", "int_to_hex_str(1) is 0x1") == 0
    failures = failures + 1
  @end
  @if assert_true(int_to_hex_str(15) == "0xF", "int_to_hex_str(15) is 0xF") == 0
    failures = failures + 1
  @end
  @if assert_true(int_to_hex_str(16) == "0x10", "int_to_hex_str(16) is 0x10") == 0
    failures = failures + 1
  @end
  @if assert_true(int_to_hex_str(255) == "0xFF", "int_to_hex_str(255) is 0xFF") == 0
    failures = failures + 1
  @end
  @if assert_true(int_to_hex_str(0x08000000) == "0x8000000", "int_to_hex_str(0x08000000) is 0x8000000") == 0
    failures = failures + 1
  @end
  @if assert_true(int_to_hex_str(0x20000000) == "0x20000000", "int_to_hex_str(0x20000000) is 0x20000000") == 0
    failures = failures + 1
  @end
  @if assert_true(int_to_hex_str(0x80000000) == "0x80000000", "int_to_hex_str(0x80000000) is 0x80000000") == 0
    failures = failures + 1
  @end

  @! 4.2 ARM Linker Script Symbol Audit
  arm_ld = freestanding_generate_arm_linker_script(0x08000000, 0x00040000, 0x20000000, 0x00010000)
  required_arm_symbols = [
    "ENTRY(Reset_Handler)",
    "MEMORY",
    "FLASH (rx) : ORIGIN =",
    "RAM (rwx) : ORIGIN =",
    "SECTIONS",
    ".isr_vector :",
    "KEEP(*(.isr_vector))",
    ".text :",
    "*(.text*)",
    "*(.rodata*)",
    "_etext = .;",
    "_sidata = LOADADDR(.data);",
    ".data :",
    "_sdata = .;",
    "*(.data*)",
    "_edata = .;",
    "} > RAM AT > FLASH",
    ".bss :",
    "_sbss = .;",
    "*(.bss*)",
    "*(COMMON)",
    "_ebss = .;",
    "} > RAM",
    "_sheap = .;",
    "_eheap =",
    "_estack ="
  ]

  s_idx = 0
  @while s_idx < required_arm_symbols.len()
    sym = required_arm_symbols[s_idx]
    @if assert_true(string_contains(arm_ld, sym), "ARM LD contains symbol: " + sym) == 0
      failures = failures + 1
    @end
    s_idx = s_idx + 1
  @end

  @! Check stack and heap math for ARM
  @! ram_base = 0x20000000, ram_size = 0x00010000 (65536)
  @! estack = 0x20000000 + 65536 = 0x20010000
  @! eheap = 0x20010000 - 1024 = 0x2000FC00
  @if assert_true(string_contains(arm_ld, "_estack = 0x20010000;"), "ARM LD contains accurate _estack") == 0
    failures = failures + 1
  @end
  @if assert_true(string_contains(arm_ld, "_eheap = 0x2000FC00;"), "ARM LD contains accurate _eheap") == 0
    failures = failures + 1
  @end

  @! 4.3 RISC-V Linker Script Symbol Audit
  rv_ld = freestanding_generate_riscv_linker_script(0x80000000, 0x00200000, 0x80200000, 0x00080000)
  required_rv_symbols = [
    "OUTPUT_ARCH(\"riscv\")",
    "ENTRY(_start)",
    "MEMORY",
    "FLASH (rx) : ORIGIN =",
    "RAM (rwx) : ORIGIN =",
    "SECTIONS",
    ".text :",
    "KEEP(*(.text.entry))",
    "*(.text*)",
    "*(.rodata*)",
    "_etext = .;",
    "_sidata = LOADADDR(.data);",
    ".data :",
    "_sdata = .;",
    "__global_pointer$ = . + 0x800;",
    "*(.data*)",
    "_edata = .;",
    "} > RAM AT > FLASH",
    ".bss :",
    "_sbss = .;",
    "*(.bss*)",
    "*(COMMON)",
    "_ebss = .;",
    "} > RAM",
    "_stack_top ="
  ]

  r_idx = 0
  @while r_idx < required_rv_symbols.len()
    sym = required_rv_symbols[r_idx]
    @if assert_true(string_contains(rv_ld, sym), "RISC-V LD contains symbol: " + sym) == 0
      failures = failures + 1
    @end
    r_idx = r_idx + 1
  @end

  @! Check stack math for RISC-V
  @! ram_base = 0x80200000, ram_size = 0x00080000 (524288)
  @! stack_top = 0x80200000 + 524288 = 0x80280000
  @if assert_true(string_contains(rv_ld, "_stack_top = 0x80280000;"), "RISC-V LD contains accurate _stack_top") == 0
    failures = failures + 1
  @end

  @if failures == 0
    println("  [PASS] Linker script symbols, formatting and address calculations verified.")
    return 1
  @end
  return 0
@end

@fn test_arena_compaction_stress()
  println("▶ [ADVERSARIAL 5] Arena Fixed Memory Allocator & Two-Finger Compaction Stress...")
  failures = 0

  @! Create arena with exactly 1000 bytes
  arena = edge_arena_init(1000)

  @! Allocate 10 blocks of 100 bytes each
  i = 0
  @while i < 10
    arena = edge_arena_alloc(arena, i + 1, 100)
    i = i + 1
  @end

  @if assert_eq_int(arena.allocated_bytes, 1000, "Arena fully allocated to 1000 bytes") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(arena.live_objects.len(), 10, "10 objects allocated") == 0
    failures = failures + 1
  @end

  @! 11th allocation must fail (OOM)
  oom_res = edge_arena_alloc(arena, 11, 50)
  @if assert_eq_int(oom_res, 0, "Allocation beyond capacity returns 0 (OOM)") == 0
    failures = failures + 1
  @end

  @! Mark alternating blocks as dead (0, 2, 4, 6, 8)
  arena.live_objects[0].is_live = 0
  arena.live_objects[2].is_live = 0
  arena.live_objects[4].is_live = 0
  arena.live_objects[6].is_live = 0
  arena.live_objects[8].is_live = 0

  @! Run compaction
  arena = edge_arena_defrag_compact(arena)

  @if assert_eq_int(arena.live_objects.len(), 5, "5 surviving live objects after compaction") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(arena.allocated_bytes, 500, "Compacted allocated bytes is 500") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(arena.free_offset, 500, "Compacted free offset is 500") == 0
    failures = failures + 1
  @end

  @! Verify surviving object offsets are contiguous: 0, 100, 200, 300, 400
  k = 0
  @while k < 5
    expected_offset = k * 100
    actual_offset = arena.live_objects[k].mem_offset
    @if assert_eq_int(actual_offset, expected_offset, "Object " + k.to_str() + " relocated offset is " + expected_offset.to_str()) == 0
      failures = failures + 1
    @end
    k = k + 1
  @end

  @! Allocate 5 new objects into the coalesced free memory (500..1000)
  j = 0
  @while j < 5
    arena = edge_arena_alloc(arena, 100 + j, 100)
    j = j + 1
  @end
  @if assert_eq_int(arena.allocated_bytes, 1000, "Re-allocated 500 bytes into coalesced free space") == 0
    failures = failures + 1
  @end

  @! Mark all 10 objects dead and compact
  all_idx = 0
  @while all_idx < 10
    arena.live_objects[all_idx].is_live = 0
    all_idx = all_idx + 1
  @end

  arena = edge_arena_defrag_compact(arena)
  @if assert_eq_int(arena.live_objects.len(), 0, "0 objects remain when all dead") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(arena.allocated_bytes, 0, "Allocated bytes 0 after full sweep") == 0
    failures = failures + 1
  @end
  @if assert_eq_int(arena.free_offset, 0, "Free offset 0 after full sweep") == 0
    failures = failures + 1
  @end

  @if failures == 0
    println("  [PASS] Arena allocation & two-finger compaction stress tests passed.")
    return 1
  @end
  return 0
@end

@fn main()
  println("=================================================================")
  println("⚡ FREESTANDING & BARE-METAL ADVERSARIAL STRESS TEST SUITE ⚡")
  println("=================================================================")

  total_sections = 5
  passed_sections = 0

  @if test_vector_tables_and_serialization() == 1
    passed_sections = passed_sections + 1
  @end

  @if test_riscv_mtvec_extreme_addresses() == 1
    passed_sections = passed_sections + 1
  @end

  @if test_memory_simulator_edge_cases() == 1
    passed_sections = passed_sections + 1
  @end

  @if test_linker_script_symbols_and_formatting() == 1
    passed_sections = passed_sections + 1
  @end

  @if test_arena_compaction_stress() == 1
    passed_sections = passed_sections + 1
  @end

  println("=================================================================")
  println("📊 ADVERSARIAL RESULTS: " + passed_sections.to_str() + " / " + total_sections.to_str() + " sections passed")
  println("=================================================================")

  @if passed_sections == total_sections
    println("🎉 ALL 5 FREESTANDING ADVERSARIAL STRESS SECTIONS PASSED! (100%) 🎉")
    return 0
  @else
    println("❌ ADVERSARIAL FAILURES DETECTED")
    return 1
  @end
@end
