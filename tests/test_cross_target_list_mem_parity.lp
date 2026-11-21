// ==============================================================================
// REGRESSION TEST: 6-TARGET LIST & MEMORY PARITY + LIVE RISC-V VM EXECUTION
// ==============================================================================
// Verifies cross-target compilation of list (`[]`, `len`, `get`, `list_set`) and
// memory (`alloc`/`বরাদ্দ`, `free`/`মুক্ত`) intrinsics across:
//   - WebAssembly (.wasm 0x00 'a' 's' 'm')
//   - RISC-V 64 ELF (`e_machine = 243`, executed on pure-Lipi `riscv64_vm.lp`)
//   - ARM64 Linux ELF (`e_machine = 183`)
//   - macOS ARM64 Mach-O (`0xfeedfacf`)
//   - Windows PE64 (`'M' 'Z'`)

include "utso/io"
include "utso/string"
include "src/compiler/backend/emulators/riscv64_vm.lp"

fn ct_resolve_compiler
    if syscall(21, "bin/lipc", 0, 0, 0, 0, 0) == 0
        return "bin/lipc"
    if syscall(21, "bin/lipc_bin", 0, 0, 0, 0, 0) == 0
        return "bin/lipc_bin"
    return "bin/lipc"

fn ct_write_file path content
    fd = syscall(2, path, 577, 420, 0, 0, 0)
    if fd < 0
        return 0 - 1
    syscall(1, fd, content, len(content), 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    return 0

fn ct_read_magic path out_buf cap
    fd = syscall(2, path, 0, 0, 0, 0, 0)
    if fd < 0
        return 0 - 1
    n = syscall(0, fd, out_buf, cap, 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    return n

fn ct_exec comp src out_p target_flag log_p
    argv = malloc(64)
    env = malloc(16)
    st = malloc(8)
    i = 0
    while i < 64
        mem_byte_write(argv, i, 0)
        i = i + 1
    mem_write(env, 0, 0)
    mem_write(env, 8, 0)
    mem_write(st, 0, 0)

    mem_write(argv, 0, comp)
    mem_write(argv, 8, src)
    mem_write(argv, 16, out_p)
    mem_write(argv, 24, target_flag)
    mem_write(argv, 32, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        cfd = syscall(2, log_p, 577, 420, 0, 0, 0)
        if cfd >= 0
            syscall(33, cfd, 1, 0, 0, 0, 0)
            syscall(33, cfd, 2, 0, 0, 0, 0)
            syscall(3, cfd, 0, 0, 0, 0, 0)
        syscall(59, comp, argv, env, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)

    syscall(61, pid, st, 0, 0, 0, 0)
    raw = mem_read(st, 0) & 65535
    code = (raw / 256) % 256
    if (raw & 127) != 0
        code = 128 + (raw & 127)
    syscall(11, argv, 64, 0, 0, 0, 0)
    syscall(11, env, 16, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)
    return code

fn main
    pid = syscall(39, 0, 0, 0, 0, 0, 0)
    comp = ct_resolve_compiler()
    base = "/tmp/ct_parity_" + str(pid)
    src_lp = base + ".lp"
    log_p = base + ".log"

    parity_src = "fn main\n  v = [10, 20, 30, 40]\n  list_set(v, 1, 55)\n  n = len(v)\n  s = get(v, 0) + get(v, 1) + get(v, 2) + get(v, 3)\n  p = alloc(32)\n  free(p)\n  if n == 4 and s == 135\n    say \"PARITY_135\"\n    return 0\n  return 1\n\nmain()\n"
    ct_write_file(src_lp, parity_src)

    hdr = malloc(64)

    // 1. WebAssembly
    w_out = base + ".wasm"
    if ct_exec(comp, src_lp, w_out, "--target=wasm", log_p) != 0
        say "[ERR] wasm compilation error"
        return 1
    nw = ct_read_magic(w_out, hdr, 64)
    if nw < 8 or mem_byte_read(hdr, 0) != 0 or mem_byte_read(hdr, 1) != 97 or mem_byte_read(hdr, 2) != 115 or mem_byte_read(hdr, 3) != 109
        say "[ERR] invalid WASM magic"
        return 1
    say "[PASS] target=wasm parity compiled (" + str(nw) + "+ bytes, valid 0x00asm)"

    // 2. RISC-V 64 + Live VM Execution
    rv_out = base + ".rv64"
    if ct_exec(comp, src_lp, rv_out, "--target=riscv64", log_p) != 0
        say "[ERR] riscv64 compilation error"
        return 1
    nr = ct_read_magic(rv_out, hdr, 64)
    if nr < 64 or mem_byte_read(hdr, 18) != 243
        say "[ERR] invalid RISC-V 64 ELF header"
        return 1
    vm = riscv64_vm_new(4194304, 65536)
    if riscv64_vm_load_file(vm, rv_out) != 1
        say "[ERR] riscv64_vm_load_file error"
        return 1
    cyc = riscv64_vm_run(vm, 100000)
    if vm.rv_exit_code != 0 or str_contains(vm.rv_captured_output, "PARITY_135") != 1
        say "[ERR] RISC-V VM parity output/exit mismatch: exit=" + str(vm.rv_exit_code) + " out=" + vm.rv_captured_output
        riscv64_vm_free(vm)
        return 1
    riscv64_vm_free(vm)
    say "[PASS] target=riscv64 executed on pure-Lipi VM (" + str(cyc) + " cycles, out=PARITY_135)"

    // 3. ARM64 Linux ELF
    arm_out = base + ".arm64"
    if ct_exec(comp, src_lp, arm_out, "--target=arm64", log_p) != 0
        say "[ERR] arm64 compilation error"
        return 1
    na = ct_read_magic(arm_out, hdr, 64)
    if na < 64 or mem_byte_read(hdr, 18) != 183
        say "[ERR] invalid ARM64 ELF header"
        return 1
    say "[PASS] target=arm64 ELF verified (e_machine=183)"

    // 4. macOS ARM64 Mach-O
    mac_out = base + ".macho"
    if ct_exec(comp, src_lp, mac_out, "--target=macos-arm64", log_p) != 0
        say "[ERR] macos-arm64 compilation error"
        return 1
    nm = ct_read_magic(mac_out, hdr, 64)
    if nm < 32 or mem_byte_read(hdr, 0) != 207 or mem_byte_read(hdr, 1) != 250 or mem_byte_read(hdr, 2) != 237 or mem_byte_read(hdr, 3) != 254
        say "[ERR] invalid macOS ARM64 Mach-O header"
        return 1
    say "[PASS] target=macos-arm64 Mach-O verified (0xfeedfacf)"

    // 5. Windows PE64
    win_out = base + ".exe"
    if ct_exec(comp, src_lp, win_out, "--target=windows", log_p) != 0
        say "[ERR] windows PE compilation error"
        return 1
    nwin = ct_read_magic(win_out, hdr, 64)
    if nwin < 64 or mem_byte_read(hdr, 0) != 77 or mem_byte_read(hdr, 1) != 90
        say "[ERR] invalid Windows PE header"
        return 1
    say "[PASS] target=windows PE verified (MZ)"

    syscall(11, hdr, 64, 0, 0, 0, 0)
    syscall(87, src_lp, 0, 0, 0, 0, 0)
    syscall(87, log_p, 0, 0, 0, 0, 0)
    syscall(87, w_out, 0, 0, 0, 0, 0)
    syscall(87, rv_out, 0, 0, 0, 0, 0)
    syscall(87, arm_out, 0, 0, 0, 0, 0)
    syscall(87, mac_out, 0, 0, 0, 0, 0)
    syscall(87, win_out, 0, 0, 0, 0, 0)

    say "✅ TEST_CROSS_TARGET_LIST_MEM_PARITY_COMPLETE"
    return 0

main()
