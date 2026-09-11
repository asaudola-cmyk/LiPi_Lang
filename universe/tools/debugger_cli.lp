@! ============================================================================
@! MAYA SOVEREIGN DEBUGGER CLI & PTRACE DRIVER (universe/tools/debugger_cli.maya)
@! 100% Written in Pure Maya Language — Zero Foreign Syntax
@! Freestanding Linux x86-64 Machine Code Tracing via Linux Kernel sys_ptrace (Syscall 101)
@! ============================================================================

@! ----------------------------------------------------------------------------
@! 1. Linux Kernel Syscall Numbers & Constants
@! ----------------------------------------------------------------------------
@fn SYS_PTRACE() return 101 @end
@fn SYS_MMAP() return 9 @end
@fn SYS_FORK() return 57 @end
@fn SYS_EXECVE() return 59 @end
@fn SYS_EXIT() return 60 @end
@fn SYS_WAIT4() return 61 @end
@fn SYS_KILL() return 62 @end
@fn SYS_GETPID() return 39 @end

@! Linux ptrace request opcodes (arch/x86/include/uapi/asm/ptrace.h)
@fn PTRACE_TRACEME() return 0 @end
@fn PTRACE_PEEKTEXT() return 1 @end
@fn PTRACE_PEEKDATA() return 2 @end
@fn PTRACE_PEEKUSER() return 3 @end
@fn PTRACE_POKETEXT() return 4 @end
@fn PTRACE_POKEDATA() return 5 @end
@fn PTRACE_POKEUSER() return 6 @end
@fn PTRACE_CONT() return 7 @end
@fn PTRACE_KILL() return 8 @end
@fn PTRACE_SINGLESTEP() return 9 @end
@fn PTRACE_GETREGS() return 12 @end
@fn PTRACE_SETREGS() return 13 @end
@fn PTRACE_ATTACH() return 16 @end
@fn PTRACE_DETACH() return 17 @end

@! x86_64 Software Breakpoint INT3 Opcode (0xCC)
@fn INT3_OPCODE() return 204 @end

@! POSIX Signals
@fn SIGTRAP() return 5 @end
@fn SIGSTOP() return 19 @end

@! ----------------------------------------------------------------------------
@! 2. Sovereign Debugger Data Structures
@! ----------------------------------------------------------------------------
@struct DebuggerRegs
  rip: i64,
  rsp: i64,
  rax: i64,
  rbp: i64,
  rbx: i64,
  rcx: i64,
  rdx: i64,
  rsi: i64,
  rdi: i64,
  r8: i64,
  r9: i64,
  r10: i64,
  r11: i64,
  r12: i64,
  r13: i64,
  r14: i64,
  r15: i64,
  eflags: i64
@end

@struct DebuggerBreakpoint
  pid: i64,
  addr: i64,
  orig_byte: i64,
  is_active: i64
@end

@struct DebuggerStackFrame
  frame_index: i64,
  rip: i64,
  rbp: i64,
  rsp: i64,
  caller_rip: i64,
  caller_rbp: i64
@end

@struct DebuggerSession
  pid: i64,
  is_running: i64,
  status: i64,
  last_sig: i64
@end

@! ----------------------------------------------------------------------------
@! 3. Direct Linux Kernel sys_ptrace Gateway
@! ----------------------------------------------------------------------------
@fn sys_ptrace(request, pid, addr, data)
  @! Direct invocation of x86_64 Linux ptrace system call (syscall 101)
  @! WHY: Directly interacts with kernel process debugging facility without libc wrapper overhead.
  return sys_syscall(101, request, pid, addr, data, 0, 0)
@end

@! ----------------------------------------------------------------------------
@! 4. Core Sovereign Debugger Operations
@! ----------------------------------------------------------------------------

@fn debugger_spawn(program_path)
  @! Forks and execs child under ptrace supervision
  @! WHY: Child enables tracing before execve so parent intercepts entrypoint via SIGTRAP.
  child_pid = sys_syscall(57, 0, 0, 0, 0, 0, 0)
  @if child_pid < 0
    return child_pid
  @end

  @if child_pid == 0
    @! In child: request tracing
    tr_res = sys_ptrace(PTRACE_TRACEME(), 0, 0, 0)
    @if tr_res < 0
      sys_syscall(60, 126, 0, 0, 0, 0, 0)
    @end

    @! Execute target binary
    argv = [program_path, 0]
    sys_syscall(59, program_path, argv, 0)
    @! If execve fails, exit child
    sys_syscall(60, 127, 0, 0, 0, 0, 0)
  @end

  @! In parent: wait for child to stop on execve SIGTRAP
  status_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  sys_syscall(61, child_pid, status_buf, 0, 0, 0, 0)
  return child_pid
@end

@fn debugger_attach(pid)
  @! Attaches sovereign ptrace driver to a running target process
  @! WHY: Allows inspection and debugging of existing processes by PID.
  res = sys_ptrace(PTRACE_ATTACH(), pid, 0, 0)
  @if res < 0
    return res
  @end

  @! Wait for target process to halt on SIGSTOP
  status_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  sys_syscall(61, pid, status_buf, 0, 0, 0, 0)
  return res
@end

@fn debugger_set_breakpoint(pid, addr)
  @! Injects 0xCC (INT3) breakpoint at target address
  @! WHY: Reads original 8-byte instruction word via PTRACE_PEEKTEXT, replaces the lowest
  @! byte with INT3 opcode 0xCC (204), and writes the modified word back via PTRACE_POKETEXT.
  @! Returns the original byte on success, or negative error code on failure.
  word_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  peek_res = sys_ptrace(PTRACE_PEEKTEXT(), pid, addr, word_buf)
  @if peek_res < 0
    return peek_res
  @end

  orig_word = sys_peek(word_buf)
  orig_byte = orig_word & 255

  @! Replace lowest byte with 0xCC (204) while preserving upper 56 bits
  patched_word = (orig_word & (0 - 256)) | 204
  poke_res = sys_ptrace(PTRACE_POKETEXT(), pid, addr, patched_word)
  @if poke_res < 0
    return poke_res
  @end

  return orig_byte
@end

@fn debugger_restore_breakpoint(pid, addr, orig_byte)
  @! Restores original instruction byte at target address
  @! WHY: Required to remove breakpoint and allow normal instruction execution past the breakpoint.
  word_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  peek_res = sys_ptrace(PTRACE_PEEKTEXT(), pid, addr, word_buf)
  @if peek_res < 0
    return peek_res
  @end

  curr_word = sys_peek(word_buf)
  restored_word = (curr_word & (0 - 256)) | (orig_byte & 255)
  poke_res = sys_ptrace(PTRACE_POKETEXT(), pid, addr, restored_word)
  return poke_res
@end

@fn debugger_get_regs(pid)
  @! Retrieves CPU user register state via PTRACE_GETREGS
  @! WHY: Populates 216-byte user_regs_struct to inspect RIP, RSP, RAX, RBP and all general purpose registers.
  regs_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  res = sys_ptrace(PTRACE_GETREGS(), pid, 0, regs_buf)
  @if res < 0
    return {
      rip: 0,
      rsp: 0,
      rax: 0,
      rbp: 0,
      rbx: 0,
      rcx: 0,
      rdx: 0,
      rsi: 0,
      rdi: 0,
      r8: 0,
      r9: 0,
      r10: 0,
      r11: 0,
      r12: 0,
      r13: 0,
      r14: 0,
      r15: 0,
      eflags: 0
    }
  @end

  @! Register offsets in Linux x86_64 user_regs_struct:
  @! r15: 0, r14: 8, r13: 16, r12: 24, rbp: 32, rbx: 40, r11: 48, r10: 56
  @! r9: 64, r8: 72, rax: 80, rcx: 88, rdx: 96, rsi: 104, rdi: 112
  @! orig_rax: 120, rip: 128, cs: 136, eflags: 144, rsp: 152, ss: 160
  return {
    rip: sys_peek(regs_buf + 128),
    rsp: sys_peek(regs_buf + 152),
    rax: sys_peek(regs_buf + 80),
    rbp: sys_peek(regs_buf + 32),
    rbx: sys_peek(regs_buf + 40),
    rcx: sys_peek(regs_buf + 88),
    rdx: sys_peek(regs_buf + 96),
    rsi: sys_peek(regs_buf + 104),
    rdi: sys_peek(regs_buf + 112),
    r8: sys_peek(regs_buf + 72),
    r9: sys_peek(regs_buf + 64),
    r10: sys_peek(regs_buf + 56),
    r11: sys_peek(regs_buf + 48),
    r12: sys_peek(regs_buf + 24),
    r13: sys_peek(regs_buf + 16),
    r14: sys_peek(regs_buf + 8),
    r15: sys_peek(regs_buf + 0),
    eflags: sys_peek(regs_buf + 144)
  }
@end

@fn debugger_single_step(pid)
  @! Executes a single machine instruction via PTRACE_SINGLESTEP
  @! WHY: Enables CPU Trap Flag (TF) so CPU executes one instruction and raises SIGTRAP.
  res = sys_ptrace(PTRACE_SINGLESTEP(), pid, 0, 0)
  @if res < 0
    return res
  @end

  status_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  sys_syscall(61, pid, status_buf, 0, 0, 0, 0)
  st = sys_peek(status_buf)
  return st
@end

@fn debugger_continue(pid)
  @! Resumes target process execution via PTRACE_CONT
  @! WHY: Allows tracee to run freely until the next breakpoint or signal.
  return sys_ptrace(PTRACE_CONT(), pid, 0, 0)
@end

@fn debugger_detach(pid)
  @! Detaches from target process via PTRACE_DETACH
  @! WHY: Allows target process to run freely without further supervision.
  return sys_ptrace(PTRACE_DETACH(), pid, 0, 0)
@end

@! ----------------------------------------------------------------------------
@! 5. Opcode Masking, Simulation & Verification Helpers
@! ----------------------------------------------------------------------------

@fn debugger_mask_breakpoint(word, int3_byte)
  @! Masks in 0xCC (or custom opcode byte) into lowest byte of 64-bit instruction word
  @! WHY: Isolates software breakpoint arithmetic for unit testing and simulation.
  return (word & (0 - 256)) | (int3_byte & 255)
@end

@fn debugger_unmask_breakpoint(patched_word, orig_byte)
  @! Restores original opcode byte into lowest byte of 64-bit instruction word
  @! WHY: Reverses 0xCC substitution to verify instruction recovery roundtrip.
  return (patched_word & (0 - 256)) | (orig_byte & 255)
@end

@fn debugger_extract_opcode(word)
  @! Extracts opcode byte from instruction word (least significant byte on x86_64)
  @! WHY: Little-endian CPU stores first instruction byte at lowest address / lowest bits.
  return word & 255
@end

@fn debugger_parse_user_regs(regs_buf)
  @! Parses raw memory buffer into DebuggerRegs struct
  @! WHY: Allows decoding registers from raw memory dumps, fixtures, or simulated payloads.
  return {
    rip: sys_peek(regs_buf + 128),
    rsp: sys_peek(regs_buf + 152),
    rax: sys_peek(regs_buf + 80),
    rbp: sys_peek(regs_buf + 32),
    rbx: sys_peek(regs_buf + 40),
    rcx: sys_peek(regs_buf + 88),
    rdx: sys_peek(regs_buf + 96),
    rsi: sys_peek(regs_buf + 104),
    rdi: sys_peek(regs_buf + 112),
    r8: sys_peek(regs_buf + 72),
    r9: sys_peek(regs_buf + 64),
    r10: sys_peek(regs_buf + 56),
    r11: sys_peek(regs_buf + 48),
    r12: sys_peek(regs_buf + 24),
    r13: sys_peek(regs_buf + 16),
    r14: sys_peek(regs_buf + 8),
    r15: sys_peek(regs_buf + 0),
    eflags: sys_peek(regs_buf + 144)
  }
@end

@fn debugger_unwind_stack_frame(frame_index, rbp, rsp, rip, caller_rbp, caller_rip)
  @! Constructs a stack frame representation for stack unwinding
  @! WHY: Encapsulates standard x86_64 frame-pointer based stack unwinding record.
  return {
    frame_index: frame_index,
    rip: rip,
    rbp: rbp,
    rsp: rsp,
    caller_rip: caller_rip,
    caller_rbp: caller_rbp
  }
@end

@fn debugger_regs_rip(regs) return regs.rip @end
@fn debugger_regs_rsp(regs) return regs.rsp @end
@fn debugger_regs_rax(regs) return regs.rax @end
@fn debugger_regs_rbp(regs) return regs.rbp @end

@fn debugger_read_mem(pid, addr)
  @! Reads 8-byte word from process memory
  @! WHY: Uses PTRACE_PEEKDATA to inspect tracee heap, stack, or globals.
  buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  res = sys_ptrace(PTRACE_PEEKDATA(), pid, addr, buf)
  @if res < 0
    return 0
  @end
  return sys_peek(buf)
@end

@fn debugger_write_mem(pid, addr, val)
  @! Writes 8-byte word to process memory
  @! WHY: Uses PTRACE_POKEDATA to modify tracee memory state.
  return sys_ptrace(PTRACE_POKEDATA(), pid, addr, val)
@end

@! Process status inspection helpers
@fn debugger_is_stopped(status) return (status & 255) == 127 @end
@fn debugger_stop_signal(status) return (status / 256) & 255 @end
@fn debugger_is_exited(status) return (status & 127) == 0 @end
@fn debugger_exit_status(status) return (status / 256) & 255 @end
