// Test 29: Debugger — Lipi 2.0 Global Standard
// Simulates a debug session with breakpoints and inspection

struct Breakpoint
    addr
    active
    hits

fn bp_set addr
    bp = Breakpoint()
    bp.addr = addr
    bp.active = 1
    bp.hits = 0
    say "Breakpoint set at 0x" + addr
    return bp

fn bp_hit bp
    bp.hits = bp.hits + 1
    say "Hit breakpoint addr=" + bp.addr + " hits=" + bp.hits
    return bp.hits

fn inspect_register name value
    say "REG " + name + " = " + value

fn inspect_memory addr value
    say "MEM [" + addr + "] = " + value

fn step_over addr
    say "STEP " + addr
    return addr + 4

// Debug session
say "=== Debug Session ==="
bp1 = bp_set 4096
bp2 = bp_set 8192

bp_hit bp1
bp_hit bp1
bp_hit bp2

inspect_register "rax" 42
inspect_register "rsp" 65536
inspect_register "rip" 4096

inspect_memory 4096 255
inspect_memory 4100 128

pc = 4096
repeat 5
    pc = step_over pc
say "Final PC: " + pc

say "PASS: Test 29 Debugger"
