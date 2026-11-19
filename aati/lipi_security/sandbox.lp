@! ============================================================================
@! LIPI UNIVERSE SECURITY: PROCESS SANDBOXING & SECCOMP BPF FILTERS
@! Module: aati/lipi_security/sandbox
@! 100% Pure Lipi Implementation — Zero External / C Dependencies
@! Standard: Linux Kernel BPF Seccomp (PR_SET_NO_NEW_PRIVS & SECCOMP_SET_MODE_FILTER)
@! ============================================================================

import "utso/collections"
import "utso/string"
import "utso/syscalls"

@! ----------------------------------------------------------------------------
@! 1. Linux BPF Instruction & Filter Program Data Structures
@! ----------------------------------------------------------------------------

@struct BpfInstruction
  code: i64
  jt: i64
  jf: i64
  k: i64
@end

@struct SockFilter
  code: i64
  jt: i64
  jf: i64
  k: i64
@end

@struct SockFProg
  len: i64
  filter: array
@end

@struct SyscallFilter
  allowed_syscalls: array
  default_action: i64
@end

@! ----------------------------------------------------------------------------
@! 2. Linux Kernel Seccomp & BPF Architecture Constants
@! ----------------------------------------------------------------------------

@! BPF Instruction Classes & Modes
@fn BPF_LD() return 0 @end
@fn BPF_W() return 0 @end
@fn BPF_ABS() return 32 @end
@fn BPF_JMP() return 5 @end
@fn BPF_JEQ() return 16 @end
@fn BPF_K() return 0 @end
@fn BPF_RET() return 6 @end

@! Seccomp Return Actions
@fn SECCOMP_RET_KILL() return 0 @end
@fn SECCOMP_RET_TRAP() return 50331648 @end @! 0x03000000
@fn SECCOMP_RET_ERRNO() return 327681 @end @! 0x00050001 (EPERM)
@fn SECCOMP_RET_ALLOW() return 2147418112 @end @! 0x7fff0000

@! Linux Architecture & Operation Codes
@fn AUDIT_ARCH_X86_64() return 3221225534 @end @! 0xc000003e
@fn PR_SET_NO_NEW_PRIVS() return 38 @end
@fn SECCOMP_SET_MODE_FILTER() return 1 @end

@! Linux x86_64 Syscall Numbers
@fn SYS_PRCTL() return 157 @end
@fn SYS_SECCOMP() return 317 @end

@! ----------------------------------------------------------------------------
@! 3. BPF Filter Compilation Engine
@! ----------------------------------------------------------------------------

@fn bpf_insn(code: i64, jt: i64, jf: i64, k: i64) -> BpfInstruction
  return {
    code: code,
    jt: jt,
    jf: jf,
    k: k
  }
@end

@fn compile_bpf_filter(filter: SyscallFilter) -> array
  insns = []
  
  @! Instruction 0: Load architecture into BPF accumulator (offsetof(struct seccomp_data, arch) = 4)
  insns = insns.push(bpf_insn(32, 0, 0, 4)) @! BPF_LD | BPF_W | BPF_ABS
  
  @! Instruction 1: Verify arch == AUDIT_ARCH_X86_64 (0xc000003e)
  @! If match, jump 1 instruction over the kill instruction to line 3; if mismatch, fall through to line 2 (kill)
  insns = insns.push(bpf_insn(21, 1, 0, 3221225534)) @! BPF_JMP | BPF_JEQ | BPF_K
  
  @! Instruction 2: Architecture mismatch -> SECCOMP_RET_KILL
  insns = insns.push(bpf_insn(6, 0, 0, 0)) @! BPF_RET | BPF_K (KILL)
  
  @! Instruction 3: Load syscall number into BPF accumulator (offsetof(struct seccomp_data, nr) = 0)
  insns = insns.push(bpf_insn(32, 0, 0, 0)) @! BPF_LD | BPF_W | BPF_ABS
  
  @! Instructions 4 .. 4 + N - 1: Check each allowed syscall
  n = filter.allowed_syscalls.len()
  i = 0
  @while i < n
    nr = filter.allowed_syscalls[i]
    @! If match: jump forward to ALLOW instruction.
    @! There are (n - 1 - i) remaining check instructions, followed by 1 default action instruction.
    @! Jump offset jt = (n - 1 - i) + 1 = n - i.
    jump_offset = n - i
    insns = insns.push(bpf_insn(21, jump_offset, 0, nr)) @! BPF_JMP | BPF_JEQ | BPF_K
    i = i + 1
  @end
  
  @! Instruction 4 + N: Default action for disallowed syscalls
  insns = insns.push(bpf_insn(6, 0, 0, filter.default_action)) @! BPF_RET | BPF_K
  
  @! Instruction 4 + N + 1: SECCOMP_RET_ALLOW (0x7fff0000)
  insns = insns.push(bpf_insn(6, 0, 0, 2147418112)) @! BPF_RET | BPF_K (ALLOW)
  
  return insns
@end

@! ----------------------------------------------------------------------------
@! 4. Sandboxing Profiles & Syscall Application
@! ----------------------------------------------------------------------------

@fn strict_io_filter() -> SyscallFilter
  return {
    allowed_syscalls: [0, 1, 3, 60, 231], @! read(0), write(1), close(3), exit(60), exit_group(231)
    default_action: 0 @! SECCOMP_RET_KILL
  }
@end

@fn compute_only_filter() -> SyscallFilter
  return {
    allowed_syscalls: [60, 231], @! exit(60), exit_group(231) only
    default_action: 327681 @! SECCOMP_RET_ERRNO (EPERM)
  }
@end

@fn pack_raw_sock_fprog(bpf_prog: array) -> i64
  @! WHY: Linux kernel seccomp ABI requires a flat C struct sock_fprog { u16 len; pad[6]; struct sock_filter *filter; }
  @! pointing to a contiguous array of 8-byte struct sock_filter { u16 code; u8 jt; u8 jf; u32 k; } elements.
  prog_len = bpf_prog.len()
  filter_buf = alloc((prog_len * 8) + 16)
  i = 0
  @while i < prog_len
    insn = bpf_prog[i]
    base_off = i * 8
    c_val = insn.code
    k_val = insn.k
    mem_byte_write(filter_buf, base_off + 0, c_val & 255)
    mem_byte_write(filter_buf, base_off + 1, (c_val / 256) & 255)
    mem_byte_write(filter_buf, base_off + 2, insn.jt & 255)
    mem_byte_write(filter_buf, base_off + 3, insn.jf & 255)
    mem_byte_write(filter_buf, base_off + 4, k_val & 255)
    mem_byte_write(filter_buf, base_off + 5, (k_val / 256) & 255)
    mem_byte_write(filter_buf, base_off + 6, (k_val / 65536) & 255)
    mem_byte_write(filter_buf, base_off + 7, (k_val / 16777216) & 255)
    i = i + 1
  @end

  fprog_buf = alloc(16)
  mem_word_write(fprog_buf, 0, prog_len)
  mem_word_write(fprog_buf, 8, filter_buf)
  return fprog_buf
@end

@fn apply_syscall_filter(filter: SyscallFilter) -> i64
  @if filter.allowed_syscalls.len() == 0
    return 0 - 22 @! EINVAL
  @end

  bpf_prog = compile_bpf_filter(filter)

  @! 1. Linux mandate: PR_SET_NO_NEW_PRIVS must be set before unprivileged seccomp
  res_privs = syscall(157, 38, 1, 0, 0, 0, 0)
  @if res_privs < 0
    return res_privs
  @end

  @! 2. Construct raw binary sock_fprog & sock_filter buffer for kernel ABI
  fprog_buf = pack_raw_sock_fprog(bpf_prog)

  @! 3. Call sys_seccomp(SECCOMP_SET_MODE_FILTER = 1, flags = 0, &fprog)
  res_seccomp = syscall(317, 1, 0, fprog_buf, 0, 0, 0)
  return res_seccomp
@end

@! ----------------------------------------------------------------------------
@! 5. sandbox_apply — Phase 4.1 required entry point
@!    Implements the spec exactly:
@!      sys_prctl(PR_SET_NO_NEW_PRIVS=38, 1, 0, 0, 0)
@!      serialize BPF filter to memory (fprog struct)
@!      sys_prctl(PR_SET_SECCOMP=22, SECCOMP_MODE_FILTER=2, &fprog, 0, 0)
@! ----------------------------------------------------------------------------

@fn sandbox_apply(filter: SyscallFilter) -> i64
  @! Compile BPF filter instructions from the allow-list
  @if filter.allowed_syscalls.len() == 0
    return 0 - 22 @! EINVAL — cannot apply empty filter
  @end

  bpf_prog = compile_bpf_filter(filter)
  prog_len = bpf_prog.len()

  @! Step 1 — PR_SET_NO_NEW_PRIVS (syscall 157 = sys_prctl, option 38)
  @! Prevents privilege escalation after the filter is installed.
  @! Must succeed before seccomp filter can be applied by unprivileged process.
  ret_no_new_privs = syscall(SYS_PRCTL(), PR_SET_NO_NEW_PRIVS(), 1, 0, 0, 0)
  @if ret_no_new_privs < 0
    return ret_no_new_privs @! Propagate kernel error (e.g. -EPERM)
  @end

  @! Step 2 — Serialize filter as raw binary sock_fprog in memory
  fprog_buf = pack_raw_sock_fprog(bpf_prog)

  @! Step 3 — PR_SET_SECCOMP / SECCOMP_MODE_FILTER
  @! Option 22 (PR_SET_SECCOMP), arg2 = 2 (SECCOMP_MODE_FILTER), arg3 = &fprog
  @! We call sys_prctl (157) rather than sys_seccomp (317) per the phase spec.
  ret_seccomp = syscall(SYS_PRCTL(), 22, 2, fprog_buf, 0, 0)
  return ret_seccomp
@end

@fn sandbox_apply_strict() -> i64
  @! Convenience: apply the predefined strict I/O-only filter
  return sandbox_apply(strict_io_filter())
@end

@fn sandbox_apply_compute_only() -> i64
  @! Convenience: apply compute-only (exit-only) filter
  return sandbox_apply(compute_only_filter())
@end

@fn validate_bpf_program(prog: array) -> i64
  @if prog.len() < 5
    return 0
  @end
  @! Verify arch check instruction is present
  @if prog[0].k != 4 || prog[1].k != 3221225534
    return 0
  @end
  @! Verify terminal instruction is RET ALLOW
  last_insn = prog[prog.len() - 1]
  @if last_insn.code != 6 || last_insn.k != 2147418112
    return 0
  @end
  return 1
@end

@fn main()
  filter = strict_io_filter()
  prog = compile_bpf_filter(filter)
  valid = validate_bpf_program(prog)
  @if valid == 1
    return 0
  @end
  return 1
@end

