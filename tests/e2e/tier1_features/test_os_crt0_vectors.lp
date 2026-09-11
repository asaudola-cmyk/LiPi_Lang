// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Bare-Metal CRT0 Vectors & Freestanding Boot PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: os, freestanding, baremetal, crt0, vectors, cortex_m, riscv, bss_zero, data_copy

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: BARE-METAL CRT0 VECTORS & BOOT ENGINE
@! File: tests/e2e/tier1_features/test_os_crt0_vectors.maya
@! ============================================================================

import "universe/os/freestanding"
import "universe/core/string"

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: Bare-Metal CRT0 Vectors & Freestanding Boot")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! ----------------------------------------------------------------------------
  @! TC-CRT-01: ARM Cortex-M Vector Table Layout & Binary Serialization
  @! ----------------------------------------------------------------------------
  total = total + 1
  initial_sp = 536870912          @! 0x20000000 (RAM Top)
  reset_handler = 134217728       @! 0x08000000 (Flash Reset Base)
  cm_table = cortex_m_vector_table_new(initial_sp, reset_handler)
  cm_table = cortex_m_set_irq_handler(cm_table, 0, 134217984) @! SysTick/IRQ0
  cm_bytes = cortex_m_serialize_vector_table(cm_table)

  @! Check vector table length: 16 core vectors (64B) + 32 IRQs (128B) = 192 bytes
  len_ok = (cm_bytes.len() == 192)
  @! First 4 bytes must be initial_sp (0x20000000 -> LE: 0x00, 0x00, 0x00, 0x20)
  sp_ok = (cm_bytes[0] == 0 && cm_bytes[1] == 0 && cm_bytes[2] == 0 && cm_bytes[3] == 32)
  @! Next 4 bytes must be reset_handler | 1 (Thumb bit: 0x08000001 -> LE: 0x01, 0x00, 0x00, 0x08)
  reset_ok = (cm_bytes[4] == 1 && cm_bytes[5] == 0 && cm_bytes[6] == 0 && cm_bytes[7] == 8)

  @if len_ok && sp_ok && reset_ok
    passed = passed + 1
    println("  [PASS] TC-CRT-01: ARM Cortex-M vector table layout & 192-byte serialization with Thumb bit")
  @else
    failed = failed + 1
    println("  [FAIL] TC-CRT-01: ARM Cortex-M vector table layout")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-CRT-02: RISC-V mtvec Encoding, Decoding & Trap Vector Table
  @! ----------------------------------------------------------------------------
  total = total + 1
  rv_base = 2147483648            @! 0x80000000
  rv_mode_vectored = 1            @! Vectored trap mode
  encoded_mtvec = riscv_encode_mtvec(rv_base, rv_mode_vectored)
  decoded_mode = riscv_decode_mtvec_mode(encoded_mtvec)
  decoded_base = riscv_decode_mtvec_base(encoded_mtvec)

  rv_table = riscv_trap_table_new(rv_base, rv_mode_vectored)
  rv_bytes = riscv_serialize_trap_table(rv_table)

  mtvec_ok = (encoded_mtvec == 2147483649) && (decoded_mode == 1) && (decoded_base == 2147483648)
  rv_len_ok = (rv_bytes.len() == 128)
  @if mtvec_ok && rv_len_ok
    passed = passed + 1
    println("  [PASS] TC-CRT-02: RISC-V mtvec base/mode encoding (0x80000001) and 128-byte trap table")
  @else
    failed = failed + 1
    println("  [FAIL] TC-CRT-02: RISC-V mtvec trap vector table")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-CRT-03: Bare-Metal CRT0 Configuration & Machine Code Emitters
  @! ----------------------------------------------------------------------------
  total = total + 1
  cfg = freestanding_crt0_config_new(
    134217728,  @! text_start: 0x08000000
    134221824,  @! data_load_start: 0x08001000
    536870912,  @! data_vma_start: 0x20000000
    64,         @! data_size: 64 bytes
    536870976,  @! bss_start: 0x20000040
    128,        @! bss_size: 128 bytes
    536875008,  @! stack_top: 0x20001000
    134217736   @! entry_point: 0x08000008
  )

  thumb_crt0 = cortex_m_emit_crt0_thumb(cfg)
  rv32_crt0 = riscv_emit_crt0_rv32(cfg)

  thumb_ok = (thumb_crt0.len() == 48) && (thumb_crt0[0] == 79)
  rv_ok = (rv32_crt0.len() == 48) && (rv32_crt0[0] == 19)
  @if thumb_ok && rv_ok
    passed = passed + 1
    println("  [PASS] TC-CRT-03: Cortex-M Thumb and RISC-V RV32 CRT0 bootstrap machine code emission")
  @else
    failed = failed + 1
    println("  [FAIL] TC-CRT-03: CRT0 configuration and emitter")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-CRT-04: Hardware Boot Sim: .data Section LMA-to-VMA Copy Verification
  @! ----------------------------------------------------------------------------
  total = total + 1
  flash_base = 134217728  @! 0x08000000
  ram_base = 536870912    @! 0x20000000
  sim = freestanding_sim_new(flash_base, ram_base)

  @! Write pattern into simulated Flash .data source region
  data_flash_offset = cfg.data_load_start - flash_base
  d_idx = 0
  @while d_idx < cfg.data_size
    sim = freestanding_sim_write_flash(sim, data_flash_offset + d_idx, (d_idx + 1) & 255)
    d_idx = d_idx + 1
  @end

  @! Execute CRT0 startup sequence in simulator
  sim = freestanding_sim_execute_crt0(sim, cfg)

  data_copied = freestanding_sim_verify_data_copied(sim, cfg)
  @if data_copied
    passed = passed + 1
    println("  [PASS] TC-CRT-04: Hardware Boot Sim relocates .data from Flash LMA to RAM VMA correctly")
  @else
    failed = failed + 1
    println("  [FAIL] TC-CRT-04: .data relocation copy")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-CRT-05: Hardware Boot Sim: .bss Zero-Initialization Loop Verification
  @! ----------------------------------------------------------------------------
  total = total + 1
  bss_zeroed = freestanding_sim_verify_bss_zeroed(sim, cfg)
  sp_correct = (sim.sp == cfg.stack_top)
  pc_correct = (sim.pc == cfg.entry_point)
  @if bss_zeroed && sp_correct && pc_correct
    passed = passed + 1
    println("  [PASS] TC-CRT-05: Hardware Boot Sim zeroes .bss and initializes SP/PC properly")
  @else
    failed = failed + 1
    println("  [FAIL] TC-CRT-05: .bss zero initialization")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-CRT-06: Bare-Metal Linker Script Generation
  @! ----------------------------------------------------------------------------
  total = total + 1
  arm_ld = freestanding_generate_arm_linker_script(134217728, 65536, 536870912, 16384)
  rv_ld = freestanding_generate_riscv_linker_script(2147483648, 65536, 2147549184, 16384)

  arm_ld_ok = (str_index_of(arm_ld, "ENTRY(Reset_Handler)") >= 0) && (str_index_of(arm_ld, ".isr_vector") >= 0)
  rv_ld_ok = (str_index_of(rv_ld, "ENTRY(_start)") >= 0) && (str_index_of(rv_ld, "__global_pointer$") >= 0)
  @if arm_ld_ok && rv_ld_ok
    passed = passed + 1
    println("  [PASS] TC-CRT-06: Linker script generators emit valid GNU LD scripts for ARM and RISC-V")
  @else
    failed = failed + 1
    println("  [FAIL] TC-CRT-06: Linker script generators")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Bare-Metal CRT0 Vectors & Freestanding Boot PASSED")
    return 0
  @else
    println("✗ Feature: Bare-Metal CRT0 Vectors & Freestanding Boot FAILED")
    return 1
  @end
@end
