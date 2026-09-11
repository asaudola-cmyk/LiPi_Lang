// ==============================================================================
// 🧪 LIPI TEST 64: Direct WebAssembly (WASM) Binary Emitter Verification Suite
// ⚡ Written 100% in Pure Lipi (.lp) Indentation Syntax | 0% C | 0% LLVM
// 🏛️ File: tests/64_wasm_emitter.lp
//
// WHY: WebAssembly (WASM) is the portable binary format that allows sovereign Lipi
//      applications to run seamlessly inside web browsers, edge runtime workers,
//      and containerless sandboxes. This test suite verifies bit-level LEB128
//      integer encoding, section synthesis, direct filesystem emission, and full
//      end-to-end execution of generated WebAssembly bytecode inside Node.js.
// ==============================================================================

include "src/compiler/wasm_emitter.lp"

fn test_assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ PASS: " + test_name

// Helper: Spawns a shell command via Linux SYS_fork (57) and SYS_execve (59)
// WHY: Pure Lipi subprocess execution directly on baremetal Linux kernel syscalls
//      without relying on C libc system() or popen().
fn run_shell_command cmd_str
    sh_path = "/bin/sh"
    sh_flag = "-c"

    argv = malloc(32)
    syscall(2318, argv, 0, sh_path) // mem_write_word
    // In Lipi, mem_write / pointer arithmetic:
    // mem_write_word is built into the runtime
    mem_word_write(argv, 0, sh_path)
    mem_word_write(argv, 8, sh_flag)
    mem_word_write(argv, 16, cmd_str)
    mem_word_write(argv, 24, 0)

    env = malloc(8)
    mem_word_write(env, 0, 0)

    st = malloc(8)
    mem_word_write(st, 0, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        syscall(59, sh_path, argv, env, 0, 0, 0)
        syscall(60, 1, 0, 0, 0, 0, 0)

    syscall(61, pid, st, 0, 0, 0, 0)
    raw_status = mem_word_read(st, 0)
    exit_code = (raw_status / 256) % 256

    free(argv, 32)
    free(env, 8)
    free(st, 8)

    return exit_code

fn main
    say "════════════════════════════════════════════════════════════════════════"
    say "  👑 LIPI SOVEREIGN WEBASSEMBLY (WASM) EMITTER VERIFICATION SUITE"
    say "════════════════════════════════════════════════════════════════════════"

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 1]: Mathematical LEB128 Integer Encoders Verification
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 1]: Validating LEB128 Variable-Length Integer Encoders..."

    // 1. Unsigned LEB128 Encodings
    u0 = leb128_encode_u32(0)
    test_assert_eq(len(u0), 1, "uLEB128(0) length == 1")
    test_assert_eq(get(u0, 0), 0, "uLEB128(0) == [0x00]")

    u1 = leb128_encode_u32(1)
    test_assert_eq(len(u1), 1, "uLEB128(1) length == 1")
    test_assert_eq(get(u1, 0), 1, "uLEB128(1) == [0x01]")

    u127 = leb128_encode_u32(127)
    test_assert_eq(len(u127), 1, "uLEB128(127) length == 1")
    test_assert_eq(get(u127, 0), 127, "uLEB128(127) == [0x7F]")

    u128 = leb128_encode_u32(128)
    test_assert_eq(len(u128), 2, "uLEB128(128) length == 2")
    test_assert_eq(get(u128, 0), 128, "uLEB128(128)[0] == 0x80")
    test_assert_eq(get(u128, 1), 1, "uLEB128(128)[1] == 0x01")

    u624485 = leb128_encode_u32(624485)
    test_assert_eq(len(u624485), 3, "uLEB128(624485) length == 3")
    test_assert_eq(get(u624485, 0), 229, "uLEB128(624485)[0] == 0xE5 (229)")
    test_assert_eq(get(u624485, 1), 142, "uLEB128(624485)[1] == 0x8E (142)")
    test_assert_eq(get(u624485, 2), 38, "uLEB128(624485)[2] == 0x26 (38)")

    // 2. Signed LEB128 Encodings
    s0 = leb128_encode_s32(0)
    test_assert_eq(len(s0), 1, "sLEB128(0) == [0x00]")
    test_assert_eq(get(s0, 0), 0, "sLEB128(0)[0] == 0")

    s42 = leb128_encode_s32(42)
    test_assert_eq(len(s42), 1, "sLEB128(42) == [0x2A]")
    test_assert_eq(get(s42, 0), 42, "sLEB128(42)[0] == 42")

    s64 = leb128_encode_s32(64)
    test_assert_eq(len(s64), 2, "sLEB128(64) requires 2 bytes [0xC0, 0x00]")
    test_assert_eq(get(s64, 0), 192, "sLEB128(64)[0] == 192 (0xC0)")
    test_assert_eq(get(s64, 1), 0, "sLEB128(64)[1] == 0 (0x00)")

    s_neg1 = leb128_encode_s32(0 - 1)
    test_assert_eq(len(s_neg1), 1, "sLEB128(-1) length == 1")
    test_assert_eq(get(s_neg1, 0), 127, "sLEB128(-1) == [0x7F] (127)")

    s_neg2 = leb128_encode_s32(0 - 2)
    test_assert_eq(len(s_neg2), 1, "sLEB128(-2) length == 1")
    test_assert_eq(get(s_neg2, 0), 126, "sLEB128(-2) == [0x7E] (126)")

    s_neg64 = leb128_encode_s32(0 - 64)
    test_assert_eq(len(s_neg64), 1, "sLEB128(-64) length == 1")
    test_assert_eq(get(s_neg64, 0), 64, "sLEB128(-64) == [0x40] (64)")

    s_neg65 = leb128_encode_s32(0 - 65)
    test_assert_eq(len(s_neg65), 2, "sLEB128(-65) length == 2")
    test_assert_eq(get(s_neg65, 0), 191, "sLEB128(-65)[0] == 191 (0xBF)")
    test_assert_eq(get(s_neg65, 1), 127, "sLEB128(-65)[1] == 127 (0x7F)")

    s_neg624485 = leb128_encode_s32(0 - 624485)
    test_assert_eq(len(s_neg624485), 3, "sLEB128(-624485) length == 3")
    test_assert_eq(get(s_neg624485, 0), 155, "sLEB128(-624485)[0] == 155")
    test_assert_eq(get(s_neg624485, 1), 241, "sLEB128(-624485)[1] == 241")
    test_assert_eq(get(s_neg624485, 2), 89, "sLEB128(-624485)[2] == 89")

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 2]: WebAssembly Architectural Constants Verification
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 2]: Validating WebAssembly Architectural Constants..."
    test_assert_eq(WASM_MAGIC_0, 0,   "WASM Magic [0] == 0x00 ('\\0')")
    test_assert_eq(WASM_MAGIC_1, 97,  "WASM Magic [1] == 0x61 ('a')")
    test_assert_eq(WASM_MAGIC_2, 115, "WASM Magic [2] == 0x73 ('s')")
    test_assert_eq(WASM_MAGIC_3, 109, "WASM Magic [3] == 0x6D ('m')")

    test_assert_eq(WASM_VERSION_0, 1, "WASM Version == 1")
    test_assert_eq(WASM_VERSION_1, 0, "WASM Version [1] == 0")

    test_assert_eq(WASM_SEC_TYPE, 1,     "Type Section ID == 1")
    test_assert_eq(WASM_SEC_FUNCTION, 3, "Function Section ID == 3")
    test_assert_eq(WASM_SEC_EXPORT, 7,   "Export Section ID == 7")
    test_assert_eq(WASM_SEC_CODE, 10,    "Code Section ID == 10")

    test_assert_eq(WASM_TYPE_I32, 127, "WASM i32 Type == 0x7F (127)")
    test_assert_eq(WASM_TYPE_FUNC, 96, "WASM func Type == 0x60 (96)")

    test_assert_eq(WASM_OP_I32_CONST, 65,  "i32.const Opcode == 0x41 (65)")
    test_assert_eq(WASM_OP_I32_ADD, 106,   "i32.add Opcode == 0x6A (106)")
    test_assert_eq(WASM_OP_I32_SUB, 107,   "i32.sub Opcode == 0x6B (107)")
    test_assert_eq(WASM_OP_I32_MUL, 108,   "i32.mul Opcode == 0x6C (108)")
    test_assert_eq(WASM_OP_I32_DIV_S, 109, "i32.div_s Opcode == 0x6D (109)")
    test_assert_eq(WASM_OP_CALL, 16,       "call Opcode == 0x10 (16)")
    test_assert_eq(WASM_OP_RETURN, 15,     "return Opcode == 0x0F (15)")
    test_assert_eq(WASM_OP_END, 11,        "end Opcode == 0x0B (11)")

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 3]: Standalone WebAssembly Module Synthesis
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 3]: Synthesizing Standalone WebAssembly Module..."
    mod = wasm_module_new()

    // 1. Function 'add(a, b) -> a + b'
    f_add = wasm_compile_function_add(mod)
    test_assert_eq(f_add, 0, "Function 'add' registered as func_idx 0")

    // 2. Function 'sub(a, b) -> a - b'
    f_sub = wasm_compile_function_sub(mod)
    test_assert_eq(f_sub, 1, "Function 'sub' registered as func_idx 1")

    // 3. Function 'mul(a, b) -> a * b'
    f_mul = wasm_compile_function_mul(mod)
    test_assert_eq(f_mul, 2, "Function 'mul' registered as func_idx 2")

    // 4. Function 'div_s(a, b) -> a / b'
    f_div = wasm_compile_function_div_s(mod)
    test_assert_eq(f_div, 3, "Function 'div_s' registered as func_idx 3")

    // 5. Function 'fib(n)' recursive
    f_fib = wasm_compile_function_fib(mod)
    test_assert_eq(f_fib, 4, "Function 'fib' registered as func_idx 4")

    // 6. Function 'main()' calling add(10, 32)
    f_main = wasm_compile_function_main(mod, f_add)
    test_assert_eq(f_main, 5, "Function 'main' registered as func_idx 5")

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 4]: Direct Pure Lipi Memory Manipulation & File Emission
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 4]: Committing WASM Binary to Filesystem via Pure Memory Primitives..."
    out_wasm_path = "/tmp/test.wasm"
    write_res = wasm_module_write(mod, out_wasm_path)
    say "  • Output WASM module emitted to: " + out_wasm_path
    test_assert_eq(write_res, 0, "wasm_module_write succeeded with status 0")

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 5]: Byte-Level Structural WASM Header & Section Diagnostics
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 5]: Validating WASM Binary Headers & Sections on Disk..."
    content = file_read(out_wasm_path)
    file_len = len(content)
    say "  • Total generated WASM size: " + str(file_len) + " bytes"
    if file_len < 8
        say "  ❌ FAILED: File size less than 8-byte WASM header!"
        exit(1)

    // Validate 4-byte Magic Cookie: '\0asm'
    b0 = ord(char_at(content, 0))
    b1 = ord(char_at(content, 1))
    b2 = ord(char_at(content, 2))
    b3 = ord(char_at(content, 3))
    test_assert_eq(b0, 0,   "WASM Magic [0] == 0x00")
    test_assert_eq(b1, 97,  "WASM Magic [1] == 0x61 ('a')")
    test_assert_eq(b2, 115, "WASM Magic [2] == 0x73 ('s')")
    test_assert_eq(b3, 109, "WASM Magic [3] == 0x6D ('m')")

    // Validate 4-byte Version: 1
    v0 = ord(char_at(content, 4))
    v1 = ord(char_at(content, 5))
    v2 = ord(char_at(content, 6))
    v3 = ord(char_at(content, 7))
    test_assert_eq(v0, 1, "WASM Version [0] == 0x01")
    test_assert_eq(v1, 0, "WASM Version [1] == 0x00")
    test_assert_eq(v2, 0, "WASM Version [2] == 0x00")
    test_assert_eq(v3, 0, "WASM Version [3] == 0x00")

    // Verify first section is Type Section (id 1)
    sec1_id = ord(char_at(content, 8))
    test_assert_eq(sec1_id, 1, "First section is Type Section (id 1)")

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 6]: External Node.js WebAssembly Execution Validation
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 6]: Validating Output '.wasm' using External Node.js Engine..."
    say "  • Executing exact Node.js requirement command:"

    node_cmd = "node -e \"const fs=require('fs'); WebAssembly.instantiate(fs.readFileSync('/tmp/test.wasm')).then(res => { console.log('WASM Export test:', res.instance.exports.add(10, 32)); })\""
    say "    $ " + node_cmd

    exit_code = run_shell_command(node_cmd)
    test_assert_eq(exit_code, 0, "Node.js WebAssembly.instantiate executed successfully")

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 7]: Node.js Comprehensive Mathematical Exports Verification
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 7]: Validating All Exported Operations (add, sub, mul, div_s, fib, main)..."
    verify_cmd = "node -e \"const fs=require('fs'); WebAssembly.instantiate(fs.readFileSync('/tmp/test.wasm')).then(res => { const e = res.instance.exports; if (e.add(10, 32) !== 42) process.exit(1); if (e.sub(50, 8) !== 42) process.exit(2); if (e.mul(6, 7) !== 42) process.exit(3); if (e.div_s(84, 2) !== 42) process.exit(4); if (e.fib(10) !== 55) process.exit(5); if (e.main() !== 42) process.exit(6); console.log('  ✔ All WebAssembly exported calculations verified bit-exact:'); console.log('    • add(10, 32)  =', e.add(10, 32)); console.log('    • sub(50, 8)   =', e.sub(50, 8)); console.log('    • mul(6, 7)    =', e.mul(6, 7)); console.log('    • div_s(84, 2) =', e.div_s(84, 2)); console.log('    • fib(10)      =', e.fib(10)); console.log('    • main()       =', e.main()); })\""

    multi_code = run_shell_command(verify_cmd)
    test_assert_eq(multi_code, 0, "All multi-function WASM exports (add, sub, mul, div_s, fib, main) verified")

    say "\n════════════════════════════════════════════════════════════════════════"
    say "  🎉 ALL WEBASSEMBLY EMITTER INVARIANTS VALIDATED SUCCESSFULLY!"
    say "════════════════════════════════════════════════════════════════════════"
    say "PASS: Test 64 WASM Emitter"
    return 0

main()
