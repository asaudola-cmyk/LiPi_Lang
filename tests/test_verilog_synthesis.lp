// ==============================================================================
// 🧪 LIPI REGRESSION TEST: SYNTHESIZABLE VERILOG RTL CHIP EMITTER
// ⚡ Module: tests/test_verilog_synthesis.lp
// 100% Pure LiPi Implementation — Zero External / Libc / Python Dependencies
// ==============================================================================

include "utso/io.lp"
include "utso/string.lp"
include "src/compiler/backend/targets/verilog/synthesizer.lp"

fn test_verilog_module_naming
    say "[Verilog] Testing Module Name Extraction & Identifier Sanitization..."
    n1 = verilog_synth_extract_module_name("chip/accelerator.lp")
    if n1 != "lipi_accelerator"
        say "FAIL: Expected lipi_accelerator, got " + n1
        return 0
    end

    n2 = verilog_synth_extract_module_name("tensor-core-v2.lp")
    if n2 != "lipi_tensor_core_v2"
        say "FAIL: Expected lipi_tensor_core_v2, got " + n2
        return 0
    end

    say "  ✔ Module Identifier: Clean Verilog 1364-2001 naming compliance verified."
    return 1

fn test_verilog_procedural_fsm_synthesis
    say "[Verilog] Testing Procedural FSM Datapath RTL Generation..."
    tokens = list()
    res = verilog_synth_compile_program(tokens, "fpga/core_fsm.lp")
    if res.vs_success != 1
        say "FAIL: Verilog synthesis failed"
        return 0
    end

    code = res.vs_verilog_code
    if str_contains(code, "module lipi_core_fsm") == 0
        say "FAIL: Missing module declaration in emitted RTL"
        return 0
    end
    if str_contains(code, "posedge clk or negedge rst_n") == 0
        say "FAIL: Missing asynchronous reset sensitivity list"
        return 0
    end
    if str_contains(code, "STATE_IDLE") == 0 or str_contains(code, "STATE_EXEC") == 0 or str_contains(code, "STATE_DONE") == 0
        say "FAIL: Missing FSM controller state parameters"
        return 0
    end

    say "  ✔ FSM Controller: Positive-edge clocked state machine RTL synthesized."
    return 1

fn test_verilog_hardware_alu_synthesis
    say "[Verilog] Testing 64-bit Hardware ALU RTL Synthesis..."
    alu_code = verilog_synth_alu("lipi_alu_64", 64)
    if len(alu_code) == 0
        say "FAIL: Empty ALU RTL emitted"
        return 0
    end

    if str_contains(alu_code, "module lipi_alu_64") == 0
        say "FAIL: Module name mismatch in ALU RTL"
        return 0
    end
    if str_contains(alu_code, "[63:0]        operand_a") == 0
        say "FAIL: Expected 64-bit operand_a port"
        return 0
    end
    if str_contains(alu_code, "OP_ADD") == 0 or str_contains(alu_code, "OP_SUB") == 0 or str_contains(alu_code, "OP_XOR") == 0
        say "FAIL: Missing core ALU opcodes"
        return 0
    end

    say "  ✔ Hardware ALU: 64-bit registered ALU datapath synthesized."
    return 1

fn test_verilog_systolic_gemm_tile
    say "[Verilog] Testing Parameterized 2D Systolic Array Hardware Tile..."
    // Synthesize 4x4 Systolic Array with 32-bit PEs
    gemm_code = verilog_synth_gemm_tile("lipi_systolic_gemm_4x4", 4, 32)
    if len(gemm_code) == 0
        say "FAIL: Empty Systolic GEMM RTL emitted"
        return 0
    end

    if str_contains(gemm_code, "module lipi_systolic_gemm_4x4") == 0
        say "FAIL: Module declaration missing in Systolic GEMM RTL"
        return 0
    end
    if str_contains(gemm_code, "pe_acc [0:DIM-1][0:DIM-1]") == 0
        say "FAIL: 2D PE accumulator registers not declared"
        return 0
    end
    if str_contains(gemm_code, "Systolic MAC Step across array") == 0
        say "FAIL: Systolic MAC datapath logic missing"
        return 0
    end

    // Test writing to disk
    out_v_path = "/tmp/lipi_systolic_gemm_4x4.v"
    written = verilog_emit_file(gemm_code, out_v_path)
    if written <= 0 or file_exists(out_v_path) == 0
        say "FAIL: Verilog RTL file could not be written to " + out_v_path
        return 0
    end

    say "  ✔ Systolic Array: 4x4 32-bit hardware tensor MAC tile synthesized & emitted."
    return 1

fn main
    say "===================================================================="
    say "👑 LIPI SOVEREIGN: SYNTHESIZABLE VERILOG RTL CHIP EMITTER TEST SUITE"
    say "===================================================================="
    if test_verilog_module_naming() == 0 exit(1) end
    if test_verilog_procedural_fsm_synthesis() == 0 exit(1) end
    if test_verilog_hardware_alu_synthesis() == 0 exit(1) end
    if test_verilog_systolic_gemm_tile() == 0 exit(1) end
    say "===================================================================="
    say "🎉 ALL VERILOG RTL SYNTHESIS TESTS PASSED (100% GREEN)!"
    say "===================================================================="
    return 0

main()
