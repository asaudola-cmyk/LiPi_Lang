@! ============================================================================
@! MAYA SOVEREIGN DEBUGGER TEST SUITE (tests/tools/test_sovereign_debugger.maya)
@! 100% Written in Pure Maya Language — Zero Foreign Dependencies
@! Tests Linux sys_ptrace (syscall 101), register inspection, 0xCC breakpoint
@! injection simulation, and call stack frame unwinding.
@! ============================================================================

import "universe/tools/debugger_cli"

@! ----------------------------------------------------------------------------
@! Test Output & Assertion Primitives (Pure Maya, Freestanding)
@! ----------------------------------------------------------------------------

@fn print_char(c)
  sys_write_byte(1, c)
  return 0
@end

@fn print_str(s)
  i = 0
  @while sys_peek8(s + i) != 0
    sys_write_byte(1, sys_peek8(s + i))
    i = i + 1
  @end
  return i
@end

@fn print_line(s)
  print_str(s)
  sys_write_byte(1, 10)
  return 0
@end

@fn print_num(n)
  @if n == 0
    sys_write_byte(1, 48)
    return 0
  @end
  val = n
  @if val < 0
    sys_write_byte(1, 45)
    val = 0 - val
  @end
  digits = sys_mmap(0, 64, 3, 34, 0 - 1, 0)
  d_count = 0
  @while val > 0
    rem = val % 10
    sys_poke8(digits + d_count, 48 + rem)
    d_count = d_count + 1
    val = val / 10
  @end
  @while d_count > 0
    d_count = d_count - 1
    sys_write_byte(1, sys_peek8(digits + d_count))
  @end
  return 0
@end

@fn print_hex(val)
  digits = sys_mmap(0, 64, 3, 34, 0 - 1, 0)
  v = val
  d_count = 0
  @if v == 0
    sys_write_byte(1, 48)
    sys_write_byte(1, 120)
    sys_write_byte(1, 48)
    return 0
  @end
  @while v > 0
    rem = v % 16
    @if rem < 10
      sys_poke8(digits + d_count, 48 + rem)
    @else
      sys_poke8(digits + d_count, 87 + rem)
    @end
    d_count = d_count + 1
    v = v / 16
  @end
  sys_write_byte(1, 48)
  sys_write_byte(1, 120)
  @while d_count > 0
    d_count = d_count - 1
    sys_write_byte(1, sys_peek8(digits + d_count))
  @end
  return 0
@end

@fn assert_eq(actual, expected, test_name)
  @if actual == expected
    print_str("  ✓ ")
    print_str(test_name)
    print_str(" (value: ")
    print_num(actual)
    print_line(")")
    return 1
  @end
  print_str("  ✗ FAIL: ")
  print_str(test_name)
  print_str(" -> expected: ")
  print_num(expected)
  print_str(", got: ")
  print_num(actual)
  print_line("")
  return 0
@end

@fn assert_true(condition, test_name)
  @if condition == 1
    print_str("  ✓ ")
    print_line(test_name)
    return 1
  @end
  print_str("  ✗ FAIL: ")
  print_line(test_name)
  return 0
@end

@! ----------------------------------------------------------------------------
@! Test 1: Validate ptrace syscall interface and Linux request constants
@! ----------------------------------------------------------------------------
@fn test_ptrace_constants()
  print_line("[TEST 1/6] Validating Linux sys_ptrace interface and request constants...")
  p = 1
  p = p & assert_eq(SYS_PTRACE(), 101, "SYS_PTRACE == 101 (x86_64)")
  p = p & assert_eq(PTRACE_TRACEME(), 0, "PTRACE_TRACEME == 0")
  p = p & assert_eq(PTRACE_PEEKTEXT(), 1, "PTRACE_PEEKTEXT == 1")
  p = p & assert_eq(PTRACE_POKETEXT(), 4, "PTRACE_POKETEXT == 4")
  p = p & assert_eq(PTRACE_CONT(), 7, "PTRACE_CONT == 7")
  p = p & assert_eq(PTRACE_SINGLESTEP(), 9, "PTRACE_SINGLESTEP == 9")
  p = p & assert_eq(PTRACE_GETREGS(), 12, "PTRACE_GETREGS == 12")
  p = p & assert_eq(PTRACE_ATTACH(), 16, "PTRACE_ATTACH == 16")
  p = p & assert_eq(PTRACE_DETACH(), 17, "PTRACE_DETACH == 17")
  p = p & assert_eq(INT3_OPCODE(), 204, "INT3_OPCODE == 204 (0xCC)")

  @! Direct invocation of sys_ptrace on invalid PID should return negative error code (-ESRCH = -3)
  inv_res = sys_ptrace(PTRACE_PEEKTEXT(), 0 - 9999, 0, 0)
  p = p & assert_true(inv_res < 0, "sys_ptrace invalid PID returns negative error code")

  return p
@end

@! ----------------------------------------------------------------------------
@! Test 2: Register inspection logic & user_regs_struct unwrapping
@! ----------------------------------------------------------------------------
@fn test_register_inspection()
  print_line("[TEST 2/6] Validating register inspection logic and decoding offsets...")
  p = 1

  @! Populate synthetic 216-byte user_regs_struct payload
  regs_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  
  @! r15: offset 0
  sys_poke(regs_buf + 0, 15)
  @! rbp: offset 32
  sys_poke(regs_buf + 32, 140737488347136) @! 0x7FFFFFFFDE00
  @! rbx: offset 40
  sys_poke(regs_buf + 40, 66)
  @! rax: offset 80
  sys_poke(regs_buf + 80, 305419896)       @! 0x12345678
  @! rip: offset 128
  sys_poke(regs_buf + 128, 4198480)        @! 0x401050
  @! eflags: offset 144
  sys_poke(regs_buf + 144, 582)            @! 0x246
  @! rsp: offset 152
  sys_poke(regs_buf + 152, 140737488346880) @! 0x7FFFFFFFDD00

  regs = debugger_parse_user_regs(regs_buf)

  p = p & assert_eq(regs.rip, 4198480, "Decoded RIP == 0x401050")
  p = p & assert_eq(regs.rsp, 140737488346880, "Decoded RSP == 0x7FFFFFFFDD00")
  p = p & assert_eq(regs.rax, 305419896, "Decoded RAX == 0x12345678")
  p = p & assert_eq(regs.rbp, 140737488347136, "Decoded RBP == 0x7FFFFFFFDE00")
  p = p & assert_eq(regs.rbx, 66, "Decoded RBX == 66")
  p = p & assert_eq(regs.eflags, 582, "Decoded EFLAGS == 0x246")

  @! Verify accessor helpers
  p = p & assert_eq(debugger_regs_rip(regs), 4198480, "debugger_regs_rip() accessor matches")
  p = p & assert_eq(debugger_regs_rsp(regs), 140737488346880, "debugger_regs_rsp() accessor matches")
  p = p & assert_eq(debugger_regs_rax(regs), 305419896, "debugger_regs_rax() accessor matches")
  p = p & assert_eq(debugger_regs_rbp(regs), 140737488347136, "debugger_regs_rbp() accessor matches")

  return p
@end

@! ----------------------------------------------------------------------------
@! Test 3: Breakpoint injection simulation & 0xCC opcode masking
@! ----------------------------------------------------------------------------
@fn test_breakpoint_simulation()
  print_line("[TEST 3/6] Validating breakpoint injection simulation and 0xCC masking...")
  p = 1

  @! Instruction Word 1: Standard x86_64 prologue (push rbp: 0x55 = 85)
  @! Upper bytes: 0x48 0x89 0xE5 (mov rbp, rsp)
  orig_word1 = 5227094916892520789
  orig_byte1 = debugger_extract_opcode(orig_word1)
  p = p & assert_eq(orig_byte1, 85, "Instruction word 1: original opcode byte == 0x55 (push rbp)")

  @! Inject 0xCC (204)
  patched1 = debugger_mask_breakpoint(orig_word1, 204)
  patched_byte1 = debugger_extract_opcode(patched1)
  p = p & assert_eq(patched_byte1, 204, "Instruction word 1: injected opcode == 0xCC (INT3)")

  @! Verify upper 56 bits remain completely intact
  upper_orig1 = orig_word1 & (0 - 256)
  upper_patched1 = patched1 & (0 - 256)
  p = p & assert_true(upper_orig1 == upper_patched1, "Instruction word 1: upper 56 bits preserved exactly")

  @! Restore original byte
  restored1 = debugger_unmask_breakpoint(patched1, orig_byte1)
  p = p & assert_true(restored1 == orig_word1, "Instruction word 1: roundtrip restore matches original word")

  @! Instruction Word 2: mov eax, imm32 (0xB8 = 184)
  orig_word2 = 8198552921648689848
  orig_byte2 = debugger_extract_opcode(orig_word2)
  p = p & assert_eq(orig_byte2, 184, "Instruction word 2: original opcode byte == 0xB8")

  patched2 = debugger_mask_breakpoint(orig_word2, 204)
  p = p & assert_eq(debugger_extract_opcode(patched2), 204, "Instruction word 2: injected opcode == 0xCC")

  restored2 = debugger_unmask_breakpoint(patched2, orig_byte2)
  p = p & assert_true(restored2 == orig_word2, "Instruction word 2: roundtrip restore matches original word")

  return p
@end

@! ----------------------------------------------------------------------------
@! Test 4: Call stack frame unwinding and return address tracking
@! ----------------------------------------------------------------------------
@fn test_stack_unwinding()
  print_line("[TEST 4/6] Validating call stack frame unwinding and pointer chain...")
  p = 1

  @! Simulate 3-level call stack:
  @! Frame 0 (inner):  RIP = 0x401120, RBP = 0x7FFFFFFFDD00, RSP = 0x7FFFFFFFDCE0
  @! Frame 1 (caller): RIP = 0x401080, RBP = 0x7FFFFFFFDE00, RSP = 0x7FFFFFFFDD10
  @! Frame 2 (main):   RIP = 0x401000, RBP = 0x7FFFFFFFDF00, RSP = 0x7FFFFFFFDE10

  f0 = debugger_unwind_stack_frame(0, 140737488346368, 140737488346336, 4198688, 140737488346624, 4198528)
  f1 = debugger_unwind_stack_frame(1, 140737488346624, 140737488346384, 4198528, 140737488346880, 4198400)
  f2 = debugger_unwind_stack_frame(2, 140737488346880, 140737488346640, 4198400, 0, 0)

  p = p & assert_eq(f0.frame_index, 0, "Frame 0: index == 0")
  p = p & assert_eq(f0.rip, 4198688, "Frame 0: RIP == 0x401120")
  p = p & assert_eq(f0.caller_rip, f1.rip, "Frame 0: caller_rip connects to Frame 1 RIP")
  p = p & assert_eq(f0.caller_rbp, f1.rbp, "Frame 0: caller_rbp connects to Frame 1 RBP")

  p = p & assert_eq(f1.frame_index, 1, "Frame 1: index == 1")
  p = p & assert_eq(f1.rip, 4198528, "Frame 1: RIP == 0x401080")
  p = p & assert_eq(f1.caller_rip, f2.rip, "Frame 1: caller_rip connects to Frame 2 RIP")
  p = p & assert_eq(f1.caller_rbp, f2.rbp, "Frame 1: caller_rbp connects to Frame 2 RBP")

  p = p & assert_eq(f2.frame_index, 2, "Frame 2: index == 2")
  p = p & assert_eq(f2.rip, 4198400, "Frame 2: RIP == 0x401000 (main entry)")
  p = p & assert_eq(f2.caller_rip, 0, "Frame 2: top-of-stack caller_rip == 0")

  @! Verify stack pointer growth downwards (RSP0 < RSP1 < RSP2)
  p = p & assert_true(f0.rsp < f1.rsp && f1.rsp < f2.rsp, "Stack pointer grows downwards monotonically")

  return p
@end

@! ----------------------------------------------------------------------------
@! Test 5: Live Sovereign Process Tracing (fork + PTRACE_TRACEME + GETREGS + CONT)
@! ----------------------------------------------------------------------------
@fn test_live_ptrace_lifecycle()
  print_line("[TEST 5/6] Executing live Linux kernel sys_ptrace lifecycle test...")
  p = 1

  child_pid = sys_syscall(57, 0, 0, 0, 0, 0, 0)
  @if child_pid < 0
    print_line("  ✗ FAIL: fork failed")
    return 0
  @end

  @if child_pid == 0
    @! Child process: invoke PTRACE_TRACEME
    tr_res = sys_ptrace(PTRACE_TRACEME(), 0, 0, 0)
    @if tr_res < 0
      sys_syscall(60, 126, 0, 0, 0, 0, 0)
    @end

    @! Stop child to let parent attach supervisor
    self_pid = sys_syscall(39, 0, 0, 0, 0, 0, 0)
    sys_syscall(62, self_pid, 19, 0, 0, 0, 0) @! SIGSTOP

    @! Child exits with code 42
    sys_syscall(60, 42, 0, 0, 0, 0, 0)
    return 0
  @end

  @! Parent process: wait for child to stop on SIGSTOP
  status_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  sys_syscall(61, child_pid, status_buf, 0, 0, 0, 0)
  status_val = sys_peek(status_buf)
  p = p & assert_true(debugger_is_stopped(status_val) == 1, "Child process stopped under ptrace supervision")

  @! Read CPU registers via PTRACE_GETREGS
  regs = debugger_get_regs(child_pid)
  p = p & assert_true(regs.rip > 0, "Tracee RIP register > 0")
  p = p & assert_true(regs.rsp > 0, "Tracee RSP register > 0")

  print_str("  ℹ Tracee Registers: RIP=")
  print_hex(regs.rip)
  print_str(" RSP=")
  print_hex(regs.rsp)
  print_str(" RAX=")
  print_hex(regs.rax)
  print_str(" RBP=")
  print_hex(regs.rbp)
  print_line("")

  @! Single step tracee by one instruction
  step_status = debugger_single_step(child_pid)
  p = p & assert_true(step_status >= 0, "Tracee successfully advanced via PTRACE_SINGLESTEP")

  @! Continue tracee to completion
  cont_res = debugger_continue(child_pid)
  p = p & assert_eq(cont_res, 0, "PTRACE_CONT returned 0 (success)")

  @! Wait for child termination
  sys_syscall(61, child_pid, status_buf, 0, 0, 0, 0)
  final_status = sys_peek(status_buf)
  exit_code = debugger_exit_status(final_status)
  p = p & assert_eq(exit_code, 42, "Tracee process exited with expected code 42")

  return p
@end

@! ----------------------------------------------------------------------------
@! Test 6: Live Memory PEEKTEXT, Breakpoint Injection & POKETEXT Restoration
@! ----------------------------------------------------------------------------
@fn test_live_breakpoint_injection()
  print_line("[TEST 6/6] Executing live in-memory 0xCC breakpoint injection & restoration...")
  p = 1

  child_pid = sys_syscall(57, 0, 0, 0, 0, 0, 0)
  @if child_pid < 0
    print_line("  ✗ FAIL: fork failed")
    return 0
  @end

  @if child_pid == 0
    sys_ptrace(PTRACE_TRACEME(), 0, 0, 0)
    self_pid = sys_syscall(39, 0, 0, 0, 0, 0, 0)
    sys_syscall(62, self_pid, 19, 0, 0, 0, 0) @! SIGSTOP
    sys_syscall(60, 0, 0, 0, 0, 0, 0)
    return 0
  @end

  status_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  sys_syscall(61, child_pid, status_buf, 0, 0, 0, 0)

  regs = debugger_get_regs(child_pid)
  target_addr = regs.rip
  p = p & assert_true(target_addr > 0, "Target breakpoint address identified via tracee RIP")

  @! Read original byte and inject 0xCC via debugger_set_breakpoint
  orig_byte = debugger_set_breakpoint(child_pid, target_addr)
  p = p & assert_true(orig_byte >= 0, "debugger_set_breakpoint read original instruction opcode byte")

  print_str("  ℹ Original opcode at RIP: ")
  print_hex(orig_byte)
  print_line("")

  @! Verify 0xCC (204) was written into tracee memory
  word_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  sys_ptrace(PTRACE_PEEKTEXT(), child_pid, target_addr, word_buf)
  read_back_word = sys_peek(word_buf)
  injected_byte = read_back_word & 255
  p = p & assert_eq(injected_byte, 204, "Target address contains 0xCC (INT3 software breakpoint)")

  @! Restore original byte via debugger_restore_breakpoint
  rest_res = debugger_restore_breakpoint(child_pid, target_addr, orig_byte)
  p = p & assert_eq(rest_res, 0, "debugger_restore_breakpoint returned 0 (success)")

  @! Verify original byte restored
  sys_ptrace(PTRACE_PEEKTEXT(), child_pid, target_addr, word_buf)
  restored_word = sys_peek(word_buf)
  restored_byte = restored_word & 255
  p = p & assert_eq(restored_byte, orig_byte, "Target address opcode byte restored back to original value")

  @! Resume child and wait for exit
  debugger_continue(child_pid)
  sys_syscall(61, child_pid, status_buf, 0, 0, 0, 0)

  return p
@end

@! ----------------------------------------------------------------------------
@! Main Test Runner
@! ----------------------------------------------------------------------------
@fn main()
  print_line("================================================================================")
  print_line("⚡ MAYA SOVEREIGN DEBUGGER & SYS_PTRACE SUITE (tests/tools/test_sovereign_debugger)")
  print_line("   100% Native Pure Maya Tracing | Linux Kernel Syscall 101 | Zero Libc")
  print_line("================================================================================")

  all_passed = 1

  t1 = test_ptrace_constants()
  all_passed = all_passed & t1
  print_line("")

  t2 = test_register_inspection()
  all_passed = all_passed & t2
  print_line("")

  t3 = test_breakpoint_simulation()
  all_passed = all_passed & t3
  print_line("")

  t4 = test_stack_unwinding()
  all_passed = all_passed & t4
  print_line("")

  t5 = test_live_ptrace_lifecycle()
  all_passed = all_passed & t5
  print_line("")

  t6 = test_live_breakpoint_injection()
  all_passed = all_passed & t6
  print_line("")

  print_line("================================================================================")
  @if all_passed == 1
    print_line("🎉 ALL 6 SOVEREIGN DEBUGGER TEST SUITES PASSED! (100% SUCCESS)")
    print_line("================================================================================")
    return 0
  @end

  print_line("❌ SOME TESTS FAILED")
  print_line("================================================================================")
  return 1
@end
