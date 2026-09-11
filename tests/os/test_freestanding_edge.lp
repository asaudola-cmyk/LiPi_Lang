@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — THE EDGE FREESTANDING #[NO_OS] TEST SUITE
@! File: tests/os/test_freestanding_edge.maya
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

@fn main()
  println("=================================================================")
  println("🛰️ THE EDGE (FREESTANDING #[NO_OS] & DEFRAG GC) TEST SUITE 🛰️")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Fixed Arena Allocator for 2MB RAM Microcontroller
  println("▶ Section 1: Fixed Arena Allocator (0 Syscalls)...")
  total_tests = total_tests + 1
  arena = edge_arena_init(2097152) @! 2MB RAM
  
  ok1 = assert_eq_int(arena.total_capacity_bytes, 2097152, "Arena capacity is 2MB (2097152 bytes)")
  ok2 = assert_eq_int(arena.syscalls_executed, 0, "No OS syscalls executed (#[no_os] mode)")
  
  arena = edge_arena_alloc(arena, 1, 1024) @! 1KB object at offset 0
  arena = edge_arena_alloc(arena, 2, 2048) @! 2KB object at offset 1024
  ok3 = assert_eq_int(arena.allocated_bytes, 3072, "Allocated 3072 bytes in fixed arena")
  obj2 = arena.live_objects[1]
  ok4 = assert_eq_int(obj2.mem_offset, 1024, "Object 2 memory offset is 1024")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Fixed arena memory allocation verified")
  @end

  @! SECTION 2: Two-Finger Compaction & Defragmenting Garbage Collection
  println("▶ Section 2: Two-Finger Compaction GC (Relocating Object 2 to Offset 0)...")
  total_tests = total_tests + 1
  @! Mark object 1 dead
  arena.live_objects[0].is_live = 0
  
  arena = edge_arena_defrag_compact(arena)
  ok1 = assert_eq_int(arena.live_objects.len(), 1, "Dead object collected during compaction")
  reloc_obj = arena.live_objects[0]
  ok2 = assert_eq_int(reloc_obj.obj_id, 2, "Object 2 is surviving live object")
  ok3 = assert_eq_int(reloc_obj.mem_offset, 0, "Object 2 relocated to base memory offset 0")
  ok4 = assert_eq_int(arena.allocated_bytes, 2048, "Memory compacted down to 2048 bytes (Contiguous free space reclaimed)")
  ok5 = assert_eq_int(arena.defrag_runs_count, 1, "Defragmentation compaction counter incremented")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Two-finger compaction GC & memory defragmentation verified")
  @end

  @! SECTION 3: ARM Cortex-M Vector Table & Serializer
  println("▶ Section 3: ARM Cortex-M Vector Table & Serializer...")
  total_tests = total_tests + 1
  vt = cortex_m_vector_table_new(0x20020000, 0x08000100)
  ok1 = assert_eq_int(vt.initial_sp, 0x20020000, "Initial SP set correctly")
  ok2 = assert_eq_int(vt.reset_handler, 0x08000101, "Reset handler has Thumb bit set")
  vt = cortex_m_set_irq_handler(vt, 0, 0x08000200)
  ok3 = assert_eq_int(vt.external_irqs[0], 0x08000201, "IRQ 0 handler has Thumb bit set")
  vt_bytes = cortex_m_serialize_vector_table(vt)
  ok4 = assert_eq_int(vt_bytes.len(), 192, "Vector table serialized to 192 bytes (16 core + 32 IRQs)")
  ok5 = assert_eq_int(vt_bytes[0], 0, "Byte 0 of SP is 0x00")
  ok6 = assert_eq_int(vt_bytes[2], 2, "Byte 2 of SP is 0x02")
  ok7 = assert_eq_int(vt_bytes[3], 32, "Byte 3 of SP is 0x20")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] ARM Cortex-M vector table & serialization verified")
  @end

  @! SECTION 4: RISC-V MTVEC CSR & Trap Vector Table
  println("▶ Section 4: RISC-V MTVEC CSR & Trap Vector Table...")
  total_tests = total_tests + 1
  mtvec_direct = riscv_encode_mtvec(0x80000000, 0)
  ok1 = assert_eq_int(mtvec_direct, 0x80000000, "Encoded Direct mtvec")
  ok2 = assert_eq_int(riscv_decode_mtvec_mode(mtvec_direct), 0, "Decoded mode is 0 (Direct)")
  ok3 = assert_eq_int(riscv_decode_mtvec_base(mtvec_direct), 0x80000000, "Decoded base is 0x80000000")
  mtvec_vect = riscv_encode_mtvec(0x80000100, 1)
  ok4 = assert_eq_int(mtvec_vect, 0x80000101, "Encoded Vectored mtvec")
  ok5 = assert_eq_int(riscv_decode_mtvec_mode(mtvec_vect), 1, "Decoded mode is 1 (Vectored)")
  
  rv_table = riscv_trap_table_new(0x80000000, 1)
  rv_bytes = riscv_serialize_trap_table(rv_table)
  ok6 = assert_eq_int(rv_bytes.len(), 128, "RISC-V trap table serialized to 128 bytes (16 exc + 16 irq)")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] RISC-V mtvec CSR encoding & trap table verified")
  @end

  @! SECTION 5: CRT0 Emitters & GNU LD Linker Scripts
  println("▶ Section 5: CRT0 Emitters & GNU LD Linker Scripts...")
  total_tests = total_tests + 1
  cfg = freestanding_crt0_config_new(0x08000000, 0x08001000, 0x20000000, 256, 0x20000100, 512, 0x20020000, 0x08000200)
  thumb_crt0 = cortex_m_emit_crt0_thumb(cfg)
  ok1 = assert_eq_int(thumb_crt0.len(), 48, "Cortex-M Thumb CRT0 emitted 48 bytes")
  rv32_crt0 = riscv_emit_crt0_rv32(cfg)
  ok2 = assert_eq_int(rv32_crt0.len(), 48, "RISC-V RV32 CRT0 emitted 48 bytes")

  arm_ld = freestanding_generate_arm_linker_script(0x08000000, 0x00080000, 0x20000000, 0x00020000)
  ok3 = assert_true(arm_ld.len() > 100, "ARM Linker script generated non-empty")
  ok4 = assert_true(string_contains(arm_ld, "FLASH (rx) : ORIGIN = 0x8000000"), "ARM LD contains FLASH region")
  ok5 = assert_true(string_contains(arm_ld, "RAM (rwx) : ORIGIN = 0x20000000"), "ARM LD contains RAM region")

  rv_ld = freestanding_generate_riscv_linker_script(0x80000000, 0x00100000, 0x80100000, 0x00040000)
  ok6 = assert_true(string_contains(rv_ld, "OUTPUT_ARCH(\"riscv\")"), "RISC-V LD contains OUTPUT_ARCH")
  ok7 = assert_true(string_contains(rv_ld, "__global_pointer$"), "RISC-V LD contains __global_pointer$")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] CRT0 emitters & GNU LD linker script generators verified")
  @end

  @! SECTION 6: Hardware Memory Boot Simulator
  println("▶ Section 6: Hardware Memory Boot Simulator (Copy .data, Zero .bss, SP/PC)...")
  total_tests = total_tests + 1
  sim = freestanding_sim_new(0x08000000, 0x20000000)
  
  sim = freestanding_sim_write_flash(sim, 128, 42)
  sim = freestanding_sim_write_flash(sim, 129, 99)
  sim = freestanding_sim_write_flash(sim, 130, 255)

  boot_cfg = freestanding_crt0_config_new(
    0x08000000,
    0x08000080,
    0x20000040,
    3,
    0x20000100,
    128,
    0x20000400,
    0x08000010
  )

  sim = freestanding_sim_execute_crt0(sim, boot_cfg)
  ok1 = assert_eq_int(sim.sp, 0x20000400, "Simulator SP initialized to stack_top")
  ok2 = assert_eq_int(sim.pc, 0x08000010, "Simulator PC set to entry_point")
  ok3 = assert_true(freestanding_sim_verify_data_copied(sim, boot_cfg), ".data copied accurately from Flash to RAM")
  ok4 = assert_eq_int(sim.ram[64], 42, "RAM[64] == Flash[128] (42)")
  ok5 = assert_eq_int(sim.ram[65], 99, "RAM[65] == Flash[129] (99)")
  ok6 = assert_eq_int(sim.ram[66], 255, "RAM[66] == Flash[130] (255)")
  ok7 = assert_true(freestanding_sim_verify_bss_zeroed(sim, boot_cfg), ".bss memory region completely zeroed")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Hardware memory boot simulator execution verified")
  @end

  println("=================================================================")
  println("📊 THE EDGE TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 6 THE EDGE FREESTANDING TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME THE EDGE TESTS FAILED")
    return 1
  @end
@end
