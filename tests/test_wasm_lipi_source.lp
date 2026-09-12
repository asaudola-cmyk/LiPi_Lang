// ==============================================================================
// 🧪 LIPI TEST: Sovereign Dynamic WebAssembly Source-to-Binary Verification
// ⚡ Written in 100% Pure Lipi (.lp) | 0% C | 0% LLVM | 0% Emscripten
// 🏛️ File: tests/test_wasm_lipi_source.lp
//
// WHY: Verifies that arbitrary Lipi source programs (containing custom functions,
//      parameters, local variables, and arithmetic expressions) are dynamically
//      compiled into compliant W3C WebAssembly binaries and execute bit-exact.
// ==============================================================================

include "src/compiler/wasm_emitter.lp"

fn test_assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ PASS: " + test_name

fn run_shell_command cmd_str
    sh_path = "/bin/sh"
    sh_flag = "-c"

    argv = malloc(32)
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
    say "╔════════════════════════════════════════════════════════════════════════╗"
    say "║  🌐 LIPI DYNAMIC SOURCE-TO-WEBASSEMBLY (WASM) COMPILER TEST            ║"
    say "╚════════════════════════════════════════════════════════════════════════╝"

    // [Step 1]: Define multi-function Lipi program with custom mathematics
    say "\n[Step 1]: Synthesizing Dynamic Lipi Source Program..."
    src = ""
    src = src + "fn square(x)\n"
    src = src + "    return x * x\n"
    src = src + "\n"
    src = src + "fn hypot_sq(a, b)\n"
    src = src + "    return (a * a) + (b * b)\n"
    src = src + "\n"
    src = src + "fn add_three(a, b, c)\n"
    src = src + "    return a + b + c\n"
    src = src + "\n"
    src = src + "fn main()\n"
    src = src + "    return hypot_sq(3, 4)\n"

    out_wasm = "/tmp/lipi_source.wasm"
    say "  • Target WASM binary: " + out_wasm

    // [Step 2]: Compile Lipi Source Code to WebAssembly Binary
    say "\n[Step 2]: Compiling Lipi Source to WebAssembly Module..."
    res = wasm_compile_lipi_source(src, out_wasm)
    test_assert_eq(res, 0, "wasm_compile_lipi_source compiled successfully (res == 0)")

    // [Step 3]: Inspect Generated W3C WebAssembly Binary
    say "\n[Step 3]: Inspecting Generated WASM Binary Headers..."
    content = file_read(out_wasm)
    wasm_len = len(content)
    say "  • Synthesized WASM size: " + str(wasm_len) + " bytes"
    if wasm_len < 8
        say "  ❌ FAILED: WASM module file too small!"
        exit(1)

    // Verify 4-byte WebAssembly Magic: \0asm (0x00, 0x61, 0x73, 0x6D)
    test_assert_eq(ord(char_at(content, 0)), 0,   "WASM Magic [0] == 0x00 ('\\0')")
    test_assert_eq(ord(char_at(content, 1)), 97,  "WASM Magic [1] == 0x61 ('a')")
    test_assert_eq(ord(char_at(content, 2)), 115, "WASM Magic [2] == 0x73 ('s')")
    test_assert_eq(ord(char_at(content, 3)), 109, "WASM Magic [3] == 0x6D ('m')")

    // Verify 4-byte WebAssembly Version: 0x01, 0x00, 0x00, 0x00
    test_assert_eq(ord(char_at(content, 4)), 1, "WASM Version [0] == 0x01")
    test_assert_eq(ord(char_at(content, 5)), 0, "WASM Version [1] == 0x00")
    test_assert_eq(ord(char_at(content, 6)), 0, "WASM Version [2] == 0x00")
    test_assert_eq(ord(char_at(content, 7)), 0, "WASM Version [3] == 0x00")

    // [Step 4]: Execute in Node.js VM to verify Bit-Exact Mathematical Evaluation
    say "\n[Step 4]: Executing Dynamically Compiled Functions in WebAssembly Engine..."
    node_cmd = "node -e \""
    node_cmd = node_cmd + "const fs = require('fs');\n"
    node_cmd = node_cmd + "const bytes = fs.readFileSync('/tmp/lipi_source.wasm');\n"
    node_cmd = node_cmd + "WebAssembly.instantiate(bytes).then(r => {\n"
    node_cmd = node_cmd + "  const exp = r.instance.exports;\n"
    node_cmd = node_cmd + "  if (exp.square(9) !== 81) process.exit(1);\n"
    node_cmd = node_cmd + "  if (exp.hypot_sq(3, 4) !== 25) process.exit(2);\n"
    node_cmd = node_cmd + "  if (exp.add_three(10, 20, 12) !== 42) process.exit(3);\n"
    node_cmd = node_cmd + "  if (exp.main() !== 25) process.exit(4);\n"
    node_cmd = node_cmd + "  console.log('  ✔ Node.js WebAssembly: square(9)=81, hypot_sq(3,4)=25, add_three(10,20,12)=42, main()=25 PASS');\n"
    node_cmd = node_cmd + "  process.exit(0);\n"
    node_cmd = node_cmd + "}).catch(e => { console.error(e); process.exit(10); });\n"
    node_cmd = node_cmd + "\""

    node_rc = run_shell_command(node_cmd)
    test_assert_eq(node_rc, 0, "Node.js WebAssembly execution of custom Lipi functions passed bit-exact")

    say "\n════════════════════════════════════════════════════════════════════════"
    say "  🎉 DYNAMIC WEBASSEMBLY SOURCE-TO-BINARY COMPILER 100% VERIFIED!"
    say "════════════════════════════════════════════════════════════════════════"
    say "PASS: Test WASM Lipi Source"
    return 0

main()
