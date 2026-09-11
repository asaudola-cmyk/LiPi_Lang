// tests/test_wasm_lipi_source.lp
include "src/compiler/wasm_emitter.lp"

fn main
    say "Testing wasm_compile_lipi_source..."
    src = "fn add(a, b) return a + b\n"
    res = wasm_compile_lipi_source(src, "/tmp/lipi_source.wasm")
    if res == 0
        say "PASS: wasm_compile_lipi_source created /tmp/lipi_source.wasm"
    else
        say "FAIL: wasm_compile_lipi_source failed"
    return 0

main()
