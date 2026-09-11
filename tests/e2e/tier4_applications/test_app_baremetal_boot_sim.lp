// @! RUN: %maya %file
// @! EXPECT: ✓ Application: Bare-Metal CRT0 Boot & Memory Lifecycle PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 4
// @! TAGS: app, baremetal, crt0, freestanding, boot_sim, two_finger_defrag, no_os

@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP: BARE-METAL BOOT SIMULATOR & MEMORY LIFECYCLE
@! File: tests/e2e/tier4_applications/test_app_baremetal_boot_sim.maya
@! ============================================================================

import "universe/os/freestanding"
import "universe/core/collections"
import "universe/core/string"

@fn main()
  println("=================================================================")
  println("▶ [TIER 4] Application: Bare-Metal Boot Simulation & Memory Lifecycle")
  println("=================================================================")

  total_stages = 0
  passed_stages = 0
  failed_stages = 0

  @! ----------------------------------------------------------------------------
  @! STAGE 1: Cortex-M Vector Table & RISC-V Trap Table Synthesis
  @! ----------------------------------------------------------------------------
  total_stages = total_stages + 1
  msp_top = 536870912       @! 0x20000000 (RAM Top: 512MB)
  reset_vma = 134217728     @! 0x08000000 (Flash Base)
  cortex_vt = cortex_m_vector_table_new(msp_top, reset_vma)
  cortex_vt = cortex_m_set_irq_handler(cortex_vt, 0, 134218752) @! Timer IRQ
  cortex_bytes = cortex_m_serialize_vector_table(cortex_vt)

  rv_mtvec_base = 2147483648 @! 0x80000000
  rv_table = riscv_trap_table_new(rv_mtvec_base, 1)
  rv_bytes = riscv_serialize_trap_table(rv_table)

  st1_ok = (cortex_bytes.len() == 192) && (rv_bytes.len() == 128)
  @if st1_ok
    passed_stages = passed_stages + 1
    println("  [PASS] STAGE 1: Dual-architecture exception vector tables synthesized (ARM 192B + RV 128B)")
  @else
    failed_stages = failed_stages + 1
    println("  [FAIL] STAGE 1: Vector table synthesis")
  @end

  @! ----------------------------------------------------------------------------
  @! STAGE 2: CRT0 Binary Configuration & Linker Scripts
  @! ----------------------------------------------------------------------------
  total_stages = total_stages + 1
  cfg = freestanding_crt0_config_new(
    134217728,  @! text_start: 0x08000000
    134221824,  @! data_load_start: 0x08001000
    536870912,  @! data_vma_start: 0x20000000
    32,         @! data_size: 32 bytes
    536870944,  @! bss_start: 0x20000020
    64,         @! bss_size: 64 bytes
    536875008,  @! stack_top: 0x20001000
    134217736   @! entry_point: 0x08000008
  )

  arm_script = freestanding_generate_arm_linker_script(134217728, 65536, 536870912, 16384)
  rv_script = freestanding_generate_riscv_linker_script(2147483648, 65536, 2147549184, 16384)

  st2_a = (str_index_of(arm_script, "ENTRY(Reset_Handler)") >= 0)
  st2_b = (str_index_of(rv_script, "ENTRY(_start)") >= 0)
  st2_ok = st2_a && st2_b
  @if st2_ok
    passed_stages = passed_stages + 1
    println("  [PASS] STAGE 2: Linker scripts and CRT0 relocation configurations generated")
  @else
    failed_stages = failed_stages + 1
    println("  [FAIL] STAGE 2: CRT0 configuration")
  @end

  @! ----------------------------------------------------------------------------
  @! STAGE 3: Hardware Memory Simulator CRT0 Execution (.data copy & .bss zero)
  @! ----------------------------------------------------------------------------
  total_stages = total_stages + 1
  sim = freestanding_sim_new(134217728, 536870912)

  @! Write sensor calibration constants to flash .data
  f_off = cfg.data_load_start - 134217728
  b = 0
  @while b < cfg.data_size
    sim = freestanding_sim_write_flash(sim, f_off + b, (b * 3 + 7) & 255)
    b = b + 1
  @end

  @! Execute CRT0 startup in simulation
  sim = freestanding_sim_execute_crt0(sim, cfg)

  data_ok = freestanding_sim_verify_data_copied(sim, cfg)
  bss_ok = freestanding_sim_verify_bss_zeroed(sim, cfg)
  sp_ok = (sim.sp == cfg.stack_top)

  st3_ok = data_ok && bss_ok && sp_ok
  @if st3_ok
    passed_stages = passed_stages + 1
    println("  [PASS] STAGE 3: CRT0 executed in hardware simulator (.data copied, .bss zeroed, SP set)")
  @else
    failed_stages = failed_stages + 1
    println("  [FAIL] STAGE 3: Hardware simulator CRT0 execution")
  @end

  @! ----------------------------------------------------------------------------
  @! STAGE 4: Freestanding Arena Memory Allocation Lifecycle (Zero Syscalls)
  @! ----------------------------------------------------------------------------
  total_stages = total_stages + 1
  @! Initialize 2MB freestanding arena
  arena = edge_arena_init(2097152)

  @! Allocate 4 sensor telemetry buffers
  arena = edge_arena_alloc(arena, 1, 128)  @! Sensor A (Live)
  arena = edge_arena_alloc(arena, 2, 256)  @! Sensor B (To mark dead)
  arena = edge_arena_alloc(arena, 3, 512)  @! Sensor C (Live)
  arena = edge_arena_alloc(arena, 4, 1024) @! Sensor D (To mark dead)

  alloc_bytes_before = arena.allocated_bytes
  num_objs_before = arena.live_objects.len()

  st4_ok = (num_objs_before == 4) && (alloc_bytes_before == (128 + 256 + 512 + 1024)) && (arena.syscalls_executed == 0)
  @if st4_ok
    passed_stages = passed_stages + 1
    println("  [PASS] STAGE 4: Freestanding arena allocated 4 telemetry objects (1,920 bytes, 0 syscalls)")
  @else
    failed_stages = failed_stages + 1
    println("  [FAIL] STAGE 4: Freestanding arena allocation")
  @end

  @! ----------------------------------------------------------------------------
  @! STAGE 5: Two-Finger Compaction & Defragmentation GC Execution
  @! ----------------------------------------------------------------------------
  total_stages = total_stages + 1
  @! Mark Sensor B (index 1) and Sensor D (index 3) as dead
  arena.live_objects[1].is_live = 0
  arena.live_objects[3].is_live = 0

  @! Run two-finger compaction algorithm
  arena = edge_arena_defrag_compact(arena)

  num_objs_after = arena.live_objects.len()
  alloc_bytes_after = arena.allocated_bytes
  defrag_runs = arena.defrag_runs_count

  @! Surviving objects should be Sensor A (128B) + Sensor C (512B) = 640B compacted to offset 0 and 128
  live0 = arena.live_objects[0]
  live1 = arena.live_objects[1]
  c_cnt_ok = (num_objs_after == 2) && (alloc_bytes_after == 640)
  c_l0_ok = (live0.obj_id == 1) && (live0.mem_offset == 0)
  c_l1_ok = (live1.obj_id == 3) && (live1.mem_offset == 128)
  c_run_ok = (defrag_runs == 1)
  compaction_ok = c_cnt_ok && c_l0_ok && c_l1_ok && c_run_ok

  @if compaction_ok
    passed_stages = passed_stages + 1
    println("  [PASS] STAGE 5: Two-finger compaction coalesced memory from 1,920B to 640B contiguous layout")
  @else
    failed_stages = failed_stages + 1
    println("  [FAIL] STAGE 5: Two-finger compaction GC")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed_stages.to_str() + "/" + total_stages.to_str() + " stages passed")
  @if failed_stages == 0
    println("✓ Application: Bare-Metal CRT0 Boot & Memory Lifecycle PASSED")
    return 0
  @else
    println("✗ Application: Bare-Metal CRT0 Boot & Memory Lifecycle FAILED")
    return 1
  @end
@end
